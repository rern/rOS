#!/bin/bash

trap exit INT

. common.sh

label=$( mount | grep -E '/dev.*BOOT |/dev.*ROOT ' )
[[ $label ]] && errorExit "Partition label exist:\n$label"
#-------------------------------------------------------------
deviceLine() {
	devline=$( dmesg \
				| tail -15 \
				| grep ' sd.* GiB\|mmcblk.* GiB' \
				| tail -1 )
}

#........................
dialog $opt_info "

               \Z1Partition Micro SD Card\Z0
                          for
                    Arch Linux Arm
" 9 58
sleep 2
#........................
dialog $opt_msg "
\Z1Insert micro SD card\Z0

If already inserted:
For proper detection, remove and reinsert again.

" 0 0
deviceLine
[[ ! $devline ]] && sleep 2 && deviceLine
[[ ! $devline ]] && errorExit No SD card found.
#-------------------------------------------------------------
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
#........................
dialog $opt_yesno "
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
fsck.fat -taw $partB
e2fsck -p $partR
fatlabel $partB BOOT
e2label $partR ROOT
mkdir -p /mnt/{BOOT,ROOT}
mount $partB /mnt/BOOT
mount $partR /mnt/ROOT
bash <( curl -sL https://github.com/rern/rOS/raw/main/create-alarm.sh ) nopathcheck
