#!/bin/bash

#........................
    dialogSplash 'Partition SD Card'
#........................
    https_ros_main='https://github.com/rern/rOS/raw/main'
    . <( curl -sL $https_ros_main/dialog_sdcard.sh ) # set $dev $part_B $part_R
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
    . <( curl -sL $https_ros_main/create-alarm.sh )
