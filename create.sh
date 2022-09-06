#!/bin/bash

optbox=( --colors --no-shadow --no-collapse )

dialog "${optbox[@]}" --infobox "

               \Z1Partition Micro SD Card\Z0
                          for
                    Arch Linux Arm
" 9 58
sleep 2

mounts=$( mount | awk '/dev\/sd.*\/BOOT/ || /dev\/sd.*\/ROOT/ {print $1" "$2" "$3}' )
if [[ $mounts ]]; then
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

if [[ $devline == *logical* ]]; then
	type=$( echo $devline | sed -E 's|.*\[(.*)\].*|\1|' )
else
	type=$( echo $devline | sed -E 's/.*] (.*): .*/\1/' )
fi
dev=/dev/$type

list=$( lsblk -o name,size,mountpoint | sed "/^$type/ {s/^/\\\Z1/; s/$/\\\Z0/}" )
dialog "${optbox[@]}" --yesno "
Device list:
$list

Warning:
Make sure this is the target SD card.
\Z1All data on this device will be deleted.\Z0

Confirm SD card:
$( echo "$list" | grep '\\Z1' )

" 0 0

[[ $? != 0 ]] && exit

clear -x

# 1. create default partitions: gparted
# 2. dump partitions table for script: sfdisk -d /dev/sdx | grep '^/dev' > alarm.sfdisk
# setup partitions
umount -l ${dev}1 ${dev}2
wipefs -a $dev
echo "\
${dev}1 : start=        2048, size=      204800, type=b
${dev}2 : start=      206848, size=    10240000, type=83
" | sfdisk $dev

devboot=${dev}1
devroot=${dev}2

mkfs.fat -F 32 $devboot
mkfs.ext4 -F $devroot

fsck.fat -a $devboot
e2fsck -p $devroot

fatlabel $devboot BOOT
e2label $devroot ROOT

mkdir -p /mnt/{BOOT,ROOT}
mount $devboot /mnt/BOOT
mount $devroot /mnt/ROOT

bash <( curl -sL https://github.com/rern/rOS/raw/main/create-alarm.sh ) nopathcheck
