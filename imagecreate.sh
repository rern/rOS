#!/bin/bash

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

optbox=( --colors --no-shadow --no-collapse )

[[ $( ls -A BOOT ) ]] && notempty+='BOOT '
[[ $( ls -A ROOT ) ]] && notempty+='ROOT'
if [[ $notempty ]]; then
		dialog "${optbox[@]}" --infobox "
\Z1$notempty\Z0 directory not empty.
" 0 0
	exit	
fi

dialog "${optbox[@]}" --infobox "

                       \Z1r\Z0Audio

                  \Z1Create\Z0 Image File
" 9 58
sleep 2

col=$( tput cols )
banner() {
	echo
	def='\e[0m'
	bg='\e[44m'
    printf "$bg%*s$def\n" $col
    printf "$bg%-${col}s$def\n" "  $1"
    printf "$bg%*s$def\n" $col
}

dialog "${optbox[@]}" --msgbox "
\Z1Insert micro SD card\Z0
If already inserted:
For proper detection, remove and reinsert again.

" 0 0

deviceLine() {
	devline=$( dmesg \
				| tail \
				| egrep ' sd.* GiB|mmcblk.* GiB' \
				| tail -1 )
}
deviceLine
[[ ! $devline ]] && sleep 2 && deviceLine

if [[ ! $devline ]]; then
	dialog "${optbox[@]}" --infobox "
\Z1No SD card found.\Z0
" 0 0
	exit
fi

dev=/dev/$( echo "$sd" | awk -F'[][]' '{print $4}' )
#devname=$( dmesg | grep Direct-Access | tail -1 | tr -s ' ' | awk '{NF-=5;print substr($0,index($0,$6))}' )
if [[ $devline == *\[sd?\]* ]]; then
	name=$( echo $devline | sed -E 's|.*\[(.*)\].*|\1|' )
	dev=/dev/$name
	partboot=${dev}1
	partroot=${dev}2
else
	name=$( echo $devline | sed -E 's/.*] (.*): .*/\1/' )
	dev=/dev/$name
	partboot=${dev}p1
	partroot=${dev}p2
fi

list=$( lsblk -o name,size,mountpoint | sed "/^$name/ {s/^/\\\Z1/; s/$/\\\Z0/}" )
dialog "${optbox[@]}" --yesno "
Device list:
$list

Confirm SD card:
$( echo "$list" | grep '\\Z1' )
" 0 0
[[ $? != 0 ]] && exit

umount $partboot 2> /dev/null
umount $partroot 2> /dev/null

BOOT=/home/$USER/BOOT
ROOT=/home/$USER/ROOT
mkdir -p /home/$USER/{BOOT,ROOT}
mount $partboot $BOOT
mount $partroot $ROOT

if [[ ! -e $BOOT/config.txt ]]; then
	dialog "${optbox[@]}" --infobox "
\Z1$dev\Z0 is not \Z1r\Z0Audio.
" 0 0
	exit
fi

version=$( cat $ROOT/srv/http/data/system/version )
revision=$( cat $ROOT/srv/http/data/addons/r$version )
if [[ -e $BOOT/kernel8.img ]]; then
	model=64bit
elif [[ -e $BOOT/kernel7.img ]]; then
	model=RPi2
else # $BOOT/kernel.img
	model=RPi0-1
fi

imagefile=$( dialog "${opt[@]}" --output-fd 1 --inputbox "
Image filename:
" 0 0 rAudio-$version-$model-$revision.img.xz )

imagedir=$( dialog "${optbox[@]}" --title 'Save to: ([space]=select)' --stdout --dselect $PWD/ 20 40 )
imagepath="${imagedir%/}/$imagefile" # %/ - remove trailing /

# auto expand root partition
touch $BOOT/expand

clear -x

umount -l -v $partboot $partroot
rmdir /home/$USER/{BOOT,ROOT}
e2fsck -fy $partroot

banner "Image: $imagefile"

banner 'Shrink ROOT partition ...'
echo

bar='\e[44m  \e[0m'
partsize=$( fdisk -l $partroot | awk '/^Disk/ {print $2" "$3}' )
used=$( df -k 2> /dev/null | grep $partroot | awk '{print $3}' )

shrink() {
	echo -e "$bar Shrink #$1 ...\n"
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
echo $imagepath
echo
dd if=$dev bs=512 iflag=fullblock count=$endsector | nice -n 10 xz -9 --verbose --threads=0 > "$imagepath"

byte=$( stat --printf="%s" "$imagepath" )
mb=$( awk "BEGIN { printf \"%.1f\n\", $byte / 1024 / 1024 }" )

dialog "${optbox[@]}" --infobox "
Image file created:
\Z1$imagepath\Z0
$mb MiB

\Z1BOOT\Z0 and \Z1ROOT\Z0 have been unmounted.
" 10 58
