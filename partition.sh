#!/bin/bash

#........................
dialogSplash 'Partition SD Card'
#........................
dev=$( dialogSDcard dev )
part_B=${dev}1
part_R=${dev}2
umount $part_B $part_R 2> /dev/null
wipefs -a $dev
mb_B=300
mb_R=6400
size_B=$(( mb_B * 2048 ))
size_R=$(( mb_R * 2048 ))
start_R=$(( 2048 + size_B ))
echo "\
$part_B : start=     2048, size= $size_B, type=c
$part_R : start= $start_R, size= $size_R, type=83
" | sfdisk $dev # existing: fdisk -d /dev/sdX
mkfs.fat -F 32 $part_B
mkfs.ext4 -F $part_R
fatlabel $part_B BOOT
e2label $part_R ROOT
partitions="$part_B $part_R"
. <( curl -sL https://github.com/rern/rOS/raw/main/create-alarm.sh )
