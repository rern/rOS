#!/bin/bash

optbox=( --colors --no-shadow --no-collapse )

dialog "${optbox[@]}" --infobox "

               \Z1Partition Micro SD Card\Z0
                          for
                    Arch Linux Arm
" 9 58
sleep 2

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

sd_size=$( dmesg -T | tail | grep ' sd .* logical blocks' | sed 's|.*\[\(.*\)\].*(\(.*\))|\1 \2|' )
[[ -z $sd_size ]] && sleep 2 && sd_size=$( dmesg -T | tail | grep ' sd .* logical blocks' | sed 's|.*\[\(.*\)\].*(\(.*\))|/\1 \2|' )
sd=${sd_size/ *}
size=$( echo $sd_size | cut -d' ' -f2- )
dev=/dev/$sd

if [[ -z $sd_size ]]; then
	dialog "${optbox[@]}" --infobox "
\Z1No SD card found.\Z0

" 0 0
	exit
fi

dialog "${optbox[@]}" --yesno "
$( lsblk -o name,size,mountpoint | sed -e '1 s/.*/Device list:/' -e "/^$sd/ s/^/\\\Z1/; s/$/\\\Z0/" )

Caution:
Make sure this is the target SD card.
\Z1All data on this device will be deleted.\Z0

Confirm:
SD card is \Z1$dev\Z0 - $size

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

curl -sLO https://github.com/rern/rOS/raw/main/create-alarm.sh
chmod +x create-alarm.sh
./create-alarm.sh nopathcheck
