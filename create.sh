#!/bin/bash

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

umount $partboot $partroot 2> /dev/null

wipefs -a $dev
# setup partitions - create partitions with gparted > get parameters: sfdisk -d /dev/sdX | grep ^/dev
echo "\
$partboot : start=        2048, size=      409600, type=b
$partroot : start=      411648, size=    13107200, type=83
" | sfdisk $dev

umount $partboot $partroot 2> /dev/null

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
