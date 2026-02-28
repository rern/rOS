#!/bin/bash

trap BOOT_ROOT.unmount SIGINT EXIT

label=$( mount | grep -E '/dev.*BOOT |/dev.*ROOT ' )
[[ $label ]] && errorExit "Partition label exist:\n$label"
#-------------------------------------------------------------
#........................
dialogSplash 'Partition SD Card'
#........................
dev=$( dialogSDcard dev )
part_B=${dev}1
part_R=${dev}2
clear -x
umount $part_B $part_R 2> /dev/null
wipefs -a $dev
mbB=300
mbR=6400
sizeB=$(( mbB * 2048 ))
sizeR=$(( mbR * 2048 ))
startR=$(( 2048 + sizeB ))
echo "\
$part_B : start=    2048, size= $sizeB, type=c
$part_R : start= $startR, size= $sizeR, type=83
" | sfdisk $dev # list: fdisk -d /dev/sdX
umount $part_B $part_R 2> /dev/null
mkfs.fat -F 32 $part_B
mkfs.ext4 -F $part_R
fsck.fat -taw $part_B
e2fsck -p $part_R
fatlabel $part_B BOOT
e2label $part_R ROOT
. <( curl -sL https://github.com/rern/rOS/raw/main/create-alarm.sh )
