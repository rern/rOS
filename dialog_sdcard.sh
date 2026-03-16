#!/bin/bash

# set global $DEV PART_B PART_R for create-alarm.sh, image-create.sh

dev_partBR() {
	[[ $1 == /dev/sd* ]] && dev=$1 || dev=${1}p
	DEV=$1
	PART_B=${dev}1
	PART_R=${dev}2
}
dialog.sdCard() {
	local dev_gib error H l line_lsblk list_BR list_check list_colored part dev_part sd_mmc sL txt_confirm
#............................ (no --sleep 1)
	dialog $option --infobox "
$logo

Insert $sd_usb


\Z4If already inserted, remove and reinsert.\Zn
" 9 $W
	s=15
	while read l; do
		dev_gib=$( grep -m1 -E '^(sd|mmcblk).* GiB' <<< $l )
		[[ $dev_gib ]] && break
	done < <( timeout $s dmesg -tW )
	if [[ ! $dev_gib ]]; then
		if dialog.retry "No devices inserted in ${s}s."; then
			dialog.sdCard
			return
#..............................................................................
		fi
	fi
	if [[ $dev_gib == sd* ]]; then
		sd_mmc=$( awk -F'[][]' '{print $2}' <<< $dev_gib ) # sd 5:0:0:0: [sdX] ... (31.9 GB/29.7 GiB)
	else
		sd_mmc=${dev_gib/:*}                               # mmcblkN: mmcN:0001 SD32G 29.7 GiB
	fi
	[[ $image_create ]] && dev_partBR $sd_mmc && return
#..............................................................................
	sleep 1
	if (( $( blockdev --getsz $sd_mmc ) > 4294967296 )); then # 2TB sector limit
		part_table=gpt
		dialog $opt_msg "
$sd_usb larger than \Z12TB\Zn: /dev/$sd_mmc
Only for Raspberry Pi 5, 4 and 3B+ (GPT)

Continue?
" 0 0 || exit
#------------------------------------------------------------------------------
	fi
	line_lsblk=$( lsblk -po name,label,size,mountpoint )
	list_BR=$( grep -E ' BOOT | ROOT ' <<< $line_lsblk )
	space_select='\Zr space \Zn to select'
	if (( $( wc -l <<< $list_BR ) > 1 )); then
		boot_root=1
		txt_confirm="\Zr ↑ \Zn \Zr ↓ \Zn $space_select \Z1BOOT\Zn and \Z1ROOT\Zn"
		readarray -t list_check < <( sed -E -e 's/^..|\s*$//;' -e 'a\off' <<< $list_BR )
	else
		txt_confirm="$space_select $sd_usb"
		list_check=( "$( grep ^/dev/$sd_mmc <<< $line_lsblk )" off )
	fi
	list_colored=$( sed -E  -e '1 {s/^/\\\Zr\\\Zb/; s/$/\\\Zn/}
					' -e "/^.dev.$sd_mmc/ {s/^/\\\Z1/; s/$/\\\Zn/}
					" -e 's/(BOOT|ROOT)/\\Z1\1\\Zn/g' <<< $line_lsblk )
	H=$(( $( wc -l <<< $list_colored ) + 10 ))
	dialog.maxH $H
#............................
	dev_part=$( dialog $opt_check "
$list_colored

$txt_confirm :
$warn All data in selected will be \Z1deleted\Zn.
" $H 0 0 "${list_check[@]}" | sed 's/ .*//' )
clear -x
	if [[ $boot_root ]]; then
		read PART_B PART_R < <( echo $dev_part )
		[[ $PART_B == /dev/sd* ]] && DEV=${PART_B:0:-1} || DEV=${PART_B:0:-2}
		wipefs -a $PART_B $PART_R
	else
		dev_partBR $dev_part
		banner Create Partitions ...
		wipefs -a $DEV
		[[ ! $part_table ]] && part_table=dos
		sfdisk $DEV <<EOF
label: $part_table

$PART_B : start=2048, size=300M,  type=c
$PART_R :             size=6400M, type=83
EOF
	fi
	bar Format BOOT and ROOT ...
	mkfs.vfat -F 32 -n BOOT $PART_B
	mkfs.ext4 -L ROOT -F $PART_R
}

dialog.sdCard
