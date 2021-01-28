#!/bin/bash

optbox=( --colors --no-shadow --no-collapse )

dialog "${optbox[@]}" --infobox "

                       \Z1r\Z0Audio

                  \Z1Create\Z0 Image File
" 9 58
sleep 3

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

sd=$( dmesg -T | tail | grep ' sd .*GB' )
[[ -z $sd ]] && sleep 2 && sd=$( dmesg -T | tail | grep ' sd .* logical blocks' )

if [[ -z $sd ]]; then
	dialog "${optbox[@]}" --infobox "
\Z1No SD card found.\Z0
" 0 0
	exit
fi

dev=/dev/$( echo $sd | awk -F'[][]' '{print $4}' )
detail=$( echo $sd | sed 's/ sd /\nsd /; s/\(\[sd.\]\) /\1\n/; s/\(blocks\): (\(.*\))/\1\n\\Z1\2\\Z0/' )

dialog "${optbox[@]}" --yesno "
Confirm micro SD card: \Z1$dev\Z0

Detail:
$detail

" 0 0

[[ $? != 0 ]] && exit

part=${dev}2
dirboot=/mnt/BOOT
dirroot=/mnt/ROOT

mount ${dev}1 $dirboot
mount $part $dirroot

if [[ ! -e $dirboot/config.txt ]]; then
	dialog "${optbox[@]}" --infobox "
\Z1$dev\Z0 is not \Z1r\Z0Audio.

" 0 0
	umount -l ${dev}1 ${dev}2
	exit
fi

if [[ -e $dirboot/kernel8.img ]]; then
	model=64
elif [[ -e $dirboot/kernel7l.img ]]; then
	model=4
elif [[ -e $dirboot/kernel7.img ]]; then
	model=2-3
else
	model=0-1
fi
version=$( cat $dirroot/srv/http/data/system/version )
imagefile=rAudio-$version-RPi$model.img.xz

# auto expand root partition
touch $dirboot/expand

clear

banner 'Shrink ROOT partition ...'

partsize=$( fdisk -l $part | awk '/^Disk/ {print $2" "$3}' )
used=$( df -k 2> /dev/null | grep $part | awk '{print $3}' )

umount -l -v ${dev}1 ${dev}2
e2fsck -fy $part

shrink() {
	partinfo=$( tune2fs -l $part )
	blockcount=$( awk '/Block count/ {print $NF}' <<< "$partinfo" )
	freeblocks=$( awk '/Free blocks/ {print $NF}' <<< "$partinfo" )
	blocksize=$( awk '/Block size/ {print $NF}' <<< "$partinfo" )

	sectorsize=$( sfdisk -l $dev | awk '/Units/ {print $8}' )
	startsector=$( fdisk -l $dev | grep $part | awk '{print $2}' )

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
		resize2fs -fp $part $(( newsize * Kblock ))K
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
banner 'Shrink #1 ...'
shrink

banner 'Shrink #2 ...'
shrink

banner 'Create compressed image file ...'

echo $imagefile
dd if=$dev bs=512 iflag=fullblock count=$endsector | nice -n 10 xz -9 --verbose --threads=0 > $imagefile

byte=$( stat --printf="%s" $imagefile )
mb=$( awk "BEGIN { printf \"%.1f\n\", $byte / 1024 / 1024 }" )

dialog "${optbox[@]}" --infobox "
Image file created:

\Z1$imagefile\Z0
$mb MiB

\Z1BOOT\Z0 and \Z1ROOT\Z0 unmounted.
" 10 58
