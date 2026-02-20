#!/bin/bash

. common.sh

# required packages
if [[ -e /usr/bin/pacman ]]; then
	[[ ! -e /usr/bin/dialog ]] && packages+='dialog '
	[[ ! -e /usr/bin/pv ]] && packages+='pv '
	[[ ! -e /usr/bin/xz ]] && packages+='xz '
	[[ $packages ]] && pacman -Sy --noconfirm $packages
else
	[[ ! -e /usr/bin/dialog ]] && packages+='dialog '
	[[ ! -e /usr/bin/pv ]] && packages+='pv '
	[[ ! -e /usr/bin/xz ]] && packages+='xz-utils '
	[[ $packages ]] && apt install -y $packages
fi

#........................
dialog "${optbox[@]}" --infobox "

                       \Z1r\Z0Audio

                  \Z1Write\Z0 Image File
" 9 58
sleep 2
#........................
dialog "${optbox[@]}" --msgbox "
\Z1Insert micro SD card\Z0
If already inserted:
For proper detection, remove and reinsert again.

" 0 0

sd=$( dmesg -T | tail | grep ' sd .*GB' )
[[ -z $sd ]] && sleep 2 && sd=$( dmesg -T | tail | grep ' sd .* logical blocks' )

if [[ -z $sd ]]; then
#........................
	dialog "${optbox[@]}" --infobox "
\Z1No SD card found.\Z0
" 0 0
	exit
#---------------------------------------------------------------
fi

dev=/dev/$( echo $sd | awk -F'[][]' '{print $4}' )
detail=$( echo $sd | sed 's/ sd /\nsd /; s/\(\[sd.\]\) /\1\n/; s/\(blocks\): (\(.*\))/\1\n\\Z1\2\\Z0/' )
#........................
dialog "${optbox[@]}" --yesno "
Confirm micro SD card: \Z1$dev\Z0
Detail:
$detail

" 0 0
[[ $? != 0 ]] && exit
#---------------------------------------------------------------
rpi=$( dialog "${optbox[@]}" --output-fd 1 --menu "
\Z1Target:\Z0
" 8 0 0 \
0 'Raspberry Pi Zero' \
1 'Raspberry Pi 1' \
2 'Raspberry Pi 2' \
3 'Raspberry Pi 3' \
4 'Raspberry Pi 4' \
5 'Raspberry Pi 64bit' \
6 'Select image file' )

case $rpi in
	0 | 1 ) file=rAudio-1-RPi0-1.img.xz ;;
	2 | 3 ) file=rAudio-1-RPi2-3.img.xz ;;
	4 )     file=rAudio-1-RPi4.img.xz ;;
	5 )     file=rAudio-1-RPi64.img.xz ;;
#........................
	6 )		file=$( basename $( dialog "${optbox[@]}" --title 'Image file' --stdout --fselect $PWD/ 30 70 ) );;
esac

[[ ! -e $file ]] && echo Image file not found. && exit
#---------------------------------------------------------------
clear -x
#........................
banner Write ...
echo SD card: $dev
echo File   : $file
#........................
( pv -n $file \
	| xz -dc - \
	| dd of=$dev bs=4M conv=fsync ) 2>&1 \
	| dialog "${optbox[@]}" --gauge "
  Write to SD card
  \Z1$file\Z0 ...
" 9 58

sync
#........................
dialog "${optbox[@]}" --infobox "
 \Z1$file\Z0
 
 Image file written successfully.
 
 \Z1Micro SD card\Z0 unmounted.
" 9 58
