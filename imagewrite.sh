#!/bin/bash

optbox=( --colors --no-shadow --no-collapse )

dialog "${optbox[@]}" --infobox "

                       \Z1r\Z0Audio

                  \Z1Write\Z0 Image File
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

rpi=$( dialog "${optbox[@]}" --output-fd 1 --menu "
\Z1Target:\Z0
" 8 0 0 \
0 'Raspberry Pi Zero' \
1 'Raspberry Pi 1' \
2 'Raspberry Pi 2' \
3 'Raspberry Pi 3' \
4 'Raspberry Pi 4' \
5 'Select image file' )

case $rpi in
	0 | 1 ) file=rAudio-1-RPi0-1.img.xz ;;
	2 | 3 ) file=rAudio-1-RPi2-3.img.xz ;;
	4 )     file=rAudio-1-RPi4.img.xz ;;
	5 )		file=$( basename $( dialog "${optbox[@]}" --title 'Image file' --stdout --fselect $PWD/ 30 70 ) );;
esac

[[ ! -e $file ]] && echo Image file not found. && exit

clear -x

banner 'Write ...'
echo SD card: $dev
echo File   : $file

xz -dc $file | dd of=$dev bs=4M status=progress conv=fsync

dialog "${optbox[@]}" --infobox "
Image file written:
\Z1$file\Z0

\Z1Micro SD card\Z0 unmounted.
" 9 58
