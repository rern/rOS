#!/bin/bash

cleanup() {
	umount -l $partboot $partroot 2> /dev/null
	rmdir /home/$USER/{BOOT,ROOT} 2> /dev/null
	exit
#---------------------------------------------------------------
}
trap cleanup INT

# required packages
if [[ -e /usr/bin/pacman ]]; then
	[[ ! -e /usr/bin/bsdtar ]] && packages+='bsdtar '
	[[ ! -e /usr/bin/dialog ]] && packages+='dialog '
	[[ $packages ]] && pacman -Sy --noconfirm $packages
else
	[[ ! -e /usr/bin/bsdtar ]] && packages+='bsdtar libarchive-tools '
	[[ ! -e /usr/bin/dialog ]] && packages+='dialog '
	[[ $packages ]] && apt install -y $packages
fi

optbox=( --colors --no-shadow --no-collapse --nocancel )

dialog "${optbox[@]}" --infobox "

                       \Z1r\Z0Audio

                  \Z1Create\Z0 Image File
" 9 58
sleep 2

banner() {
	echo
	def='\e[0m'
	bg='\e[44m'
    printf "$bg%*s$def\n" $COLUMNS
    printf "$bg%-${COLUMNS}s$def\n" "  $1"
    printf "$bg%*s$def\n" $COLUMNS
}

dialog "${optbox[@]}" --msgbox "
\Z1Insert micro SD card\Z0
If already inserted:
For proper detection, remove and reinsert again.

" 0 0

deviceLine() {
	devline=$( dmesg \
				| tail \
				| grep ' sd.* GiB\|mmcblk.* GiB' \
				| tail -1 )
}
deviceLine
[[ ! $devline ]] && sleep 2 && deviceLine

if [[ ! $devline ]]; then
	dialog "${optbox[@]}" --infobox "
\Z1No SD card found.\Z0
" 0 0
	exit
#---------------------------------------------------------------
fi
if [[ $devline == *\[sd?\]* ]]; then
	name=$( sed -E 's|.*\[(.*)\].*|\1|' <<< $devline )
	dev=/dev/$name
	partboot=${dev}1
	partroot=${dev}2
else
	name=$( sed -E 's/.*] (.*): .*/\1/' <<< $devline )
	dev=/dev/$name
	partboot=${dev}p1
	partroot=${dev}p2
fi

list=$( lsblk -o name,size,mountpoint | grep -v ^loop | sed "/^$name/ {s/^/\\\Z1/; s/$/\\\Z0/}" )
dialog "${optbox[@]}" --yesno "
Device list:
$list

Confirm SD card:
$( echo "$list" | grep '\\Z1' )
" 0 0
[[ $? != 0 ]] && exit
#---------------------------------------------------------------
umount -l $partboot $partroot 2> /dev/null

BOOT=/mnt/BOOT
ROOT=/mnt/ROOT
[[ $( ls -A $BOOT 2> /dev/null ) ]] && warnings="
$BOOT not empty."
[[ $( ls -A $ROOT 2> /dev/null ) ]] && warnings+="
$ROOT not empty."
[[ $warnings ]] && dialog "${optbox[@]}" --infobox "$warnings" 0 0 && exit
#---------------------------------------------------------------
mkdir -p /mnt/{BOOT,ROOT}
mount $partboot $BOOT
mount $partroot $ROOT

if [[ ! -e $BOOT/config.txt ]]; then
	dialog "${optbox[@]}" --infobox "
\Z1$dev\Z0 is not \Z1r\Z0Audio.
" 0 0
	exit
#---------------------------------------------------------------
fi
release=$( cat $ROOT/srv/http/data/addons/r1 )
if [[ -e $BOOT/kernel8.img ]]; then
	model=64bit
elif [[ -e $BOOT/kernel7.img ]]; then
	model=32bit
else # $BOOT/kernel.img
	model=Legacy
fi

imagefile=$( dialog "${optbox[@]}" --output-fd 1 --inputbox "
Image filename:
" 0 0 rAudio-$model-$release.img.xz )

selectdir=$PWD/
[[ -e $PWD/BIG ]] && selectdir+=BIG
imagedir=$( dialog "${optbox[@]}" --title 'Save to: ([space]=select)' --stdout --dselect $selectdir 20 40 )
imagepath="${imagedir%/}/$imagefile" # %/ - remove trailing /

clear -x
touch $BOOT/expand # auto expand root partition
umount -l -v $partboot $partroot
rmdir /home/$USER/{BOOT,ROOT} 2> /dev/null

banner 'Check filesystems ...'
fsck.fat -taw $partboot
e2fsck -p $partroot

banner "Image: $imagefile"

banner 'Shrink ROOT partition ...'
echo

bar='\e[44m  \e[0m'
partsize=$( fdisk -l $partroot | awk '/^Disk/ {print $2" "$3}' )
used=$( df -k 2> /dev/null | grep $partroot | awk '{print $3}' )

shrink() {
	echo -e "$bar Shrink Pass #$1 ...\n"
	partinfo=$( tune2fs -l $partroot )
	blockcount=$( awk '/Block count/ {print $NF}' <<< "$partinfo" )
	freeblocks=$( awk '/Free blocks/ {print $NF}' <<< "$partinfo" )
	blocksize=$( awk '/Block size/ {print $NF}' <<< "$partinfo" )

	sectorsize=$( sfdisk -l $dev | awk '/Units/ {print $8}' )
	startsector=$( fdisk -l $dev | grep $partroot | awk '{print $2}' )

	usedblocks=$(( blockcount - freeblocks ))
	targetblocks=$(( usedblocks * 105 / 100 ))
	Kblock=$(( blocksize / 1024 ))
	newsize=$(( ( targetblocks + Kblock - 1 ) / Kblock * Kblock ))
	sectorsperblock=$(( blocksize / sectorsize  ))
	endsector=$(( startsector + newsize * sectorsperblock ))

	if (( $(( newsize - target )) < 10 )); then
		echo Already reached minimum size.
	else
		# shrink filesystem to minimum
		resize2fs -fp $partroot $(( newsize * Kblock ))K
		parted $dev ---pretend-input-tty <<EOF
unit
s
resizepart
2
$endsector
Yes
quit
EOF
	fi
}

echo
shrink 1

shrink 2

banner 'Compressed to image file ...'
echo
echo -e "$bar $imagepath"
echo
threads=$(( $( nproc ) - 2 ))
dd if=$dev bs=512 iflag=fullblock count=$endsector | nice -n 10 xz -v -T $threads > "$imagepath"

size=$( xz -l --robot $imagepath | awk '/^file/ {printf "%.2f MB <<< %.2f GB", $4/10^6, $5/10^9}' )
dialog "${optbox[@]}" --infobox "
Image file created:
\Z1$imagepath\Z0
$size

" 9 58
