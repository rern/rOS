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

if [[ $devline == *\[sd?\]* ]]; then
	name=$( echo $devline | sed -E 's|.*\[(.*)\].*|\1|' )
	dev=/dev/$name
	partboot=${dev}1
	partroot=${dev}2
else
	name=$( echo $devline | sed -E 's/.*] (.*): .*/\1/' )
	dev=/dev/$name
	partboot=${dev}p1
	partroot=${dev}p2
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

clear -x

# 1. create default partitions: gparted
# 2. dump partitions table for script: sfdisk -d /dev/sdx | grep '^/dev' > alarm.sfdisk
# setup partitions
for p in $dev?*; do
	umount -l $p
done
wipefs -a $dev
echo "\
$partboot : start=        2048, size=      204800, type=b
$partroot : start=      206848, size=    10240000, type=83
" | sfdisk $dev

mkfs.fat -F 32 $partboot
mkfs.ext4 -F $partroot

fsck.fat -a $partboot
e2fsck -p $partroot

fatlabel $partboot BOOT
e2label $partroot ROOT

mkdir -p /mnt/{BOOT,ROOT}
mount $partboot /mnt/BOOT
mount $partroot /mnt/ROOT

bash <( curl -sL https://github.com/rern/rOS/raw/main/create-alarm.sh ) nopathcheck
