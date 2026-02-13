#!/bin/bash

if mount | grep -q '/dev.*BOOT\|/dev.*ROOT'; then
	dialog --colors --infobox "
Partition label exist: \Z1BOOT\Z0 or \Z1ROOT\Z0

Unable to continue.

" 0 0
	exit
#-------------------------------------------------------------
fi

trap exit INT

optbox=( --colors --no-shadow --no-collapse )

dialog "${optbox[@]}" --infobox "

               \Z1Partition Micro SD Card\Z0
                          for
                    Arch Linux Arm
" 9 58
sleep 2

dialog "${optbox[@]}" --msgbox "
\Z1Insert micro SD card\Z0

If already inserted:
For proper detection, remove and reinsert again.

" 0 0

deviceLine() {
	devline=$( dmesg \
				| tail -15 \
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
#-------------------------------------------------------------
fi

if [[ $devline == *\[sd?\]* ]]; then
	name=$( echo $devline | sed -E 's|.*\[(.*)\].*|\1|' )
	dev=/dev/$name
	partB=${dev}1
	partR=${dev}2
else
	name=$( echo $devline | sed -E 's/.*] (.*): .*/\1/' )
	dev=/dev/$name
	partB=${dev}p1
	partR=${dev}p2
fi

list=$( lsblk -o name,size,mountpoint | sed "/^$name/ {s/^/\\\Z1/; s/$/\\\Z0/}" )
dialog "${optbox[@]}" --yesno "
Device list:
$list

Warning:
Make sure this is the target SD card.
\Z1All data on this device will be deleted.\Z0

Continue formatting:
$( echo "$list" | grep '\\Z1' )

" 0 0

[[ $? != 0 ]] && exit
#-------------------------------------------------------------
clear -x

umount $partB $partR 2> /dev/null

wipefs -a $dev
mbB=300
mbR=6400
sizeB=$(( mbB * 2048 ))
sizeR=$(( mbR * 2048 ))
startR=$(( 2048 + sizeB ))
echo "\
$partB : start=    2048, size= $sizeB, type=c
$partR : start= $startR, size= $sizeR, type=83
" | sfdisk $dev # list: fdisk -d /dev/sdX

umount $partB $partR 2> /dev/null

mkfs.fat -F 32 $partB
mkfs.ext4 -F $partR

fsck.fat -a $partB
e2fsck -p $partR

fatlabel $partB BOOT
e2label $partR ROOT

mkdir -p /mnt/{BOOT,ROOT}
mount $partB /mnt/BOOT
mount $partR /mnt/ROOT

bash <( curl -sL https://github.com/rern/rOS/raw/main/create-alarm.sh ) nopathcheck
