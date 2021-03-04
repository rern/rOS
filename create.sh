#!/bin/bash

optbox=( --colors --no-shadow --no-collapse )

dialog "${optbox[@]}" --infobox "

               \Z1Partition Micro SD Card\Z0
                          for
                    Arch Linux Arm
" 9 58
sleep 3

mounts=$( mount | awk '/dev\/sd.*\/BOOT/ || /dev\/sd.*\/ROOT/ {print $1" "$2" "$3}' )
if [[ -n $mounts ]]; then
	dialog "${optbox[@]}" --yesno "
\Z1Unmount partitions?\Z0

$mounts

" 0 0
	[[ $? != 0 ]] && exit
	
	mounts=( $( echo "$mounts" | cut -d' ' -f1 ) )
	for mnt in "${mounts[@]}"; do
		umount -l $mnt
	done
fi

dialog "${optbox[@]}" --msgbox "
\Z1Insert micro SD card\Z0

If already inserted:
For proper detection, remove and reinsert again.

" 0 0

sd=$( dmesg -T | tail | grep ' sd .* logical blocks' )
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

Caution:
Make sure this is the target SD card.
\Z1All data on this device will be deleted.\Z0

" 0 0

[[ $? != 0 ]] && exit

arch=$( dialog "${optbox[@]}" --output-fd 1 --menu "
 \Z1Arch\Z0:
" 8 0 0 \
1 '32bit - 100MB BOOT' \
2 '64bit - 200MB BOOT' )

if [[ $arch == 1 ]]; then # boot - 100MB
	part="\
/dev/mmcblk0p1 : start=        2048, size=      204800, type=b
/dev/mmcblk0p2 : start=      206848, size=     8192000, type=83
"
else # boot - 200MB
	part="\
/dev/mmcblk0p1 : start=        2048, size=      409600, type=b
/dev/mmcblk0p2 : start=      411648, size=    12288000, type=83
"
fi

clear -x

# 1. create default partitions: gparted
# 2. dump partitions table for script: sfdisk -d /dev/sdx | grep '^/dev' > alarm.sfdisk
# setup partitions
umount -l ${dev}1 ${dev}2
wipefs -a $dev
echo "$part" | sfdisk $dev

devboot=${dev}1
devroot=${dev}2

mkfs.fat -F 32 $devboot
mkfs.ext4 -F $devroot
fatlabel $devboot BOOT
e2label $devroot ROOT

mkdir -p /mnt/{BOOT,ROOT}
mount $devboot /mnt/BOOT
mount $devroot /mnt/ROOT

curl -sL https://github.com/rern/rOS/raw/main/create-alarm.sh | sh
