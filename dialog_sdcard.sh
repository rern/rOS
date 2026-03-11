#!/bin/bash

# set global $DEV PART_B PART_R for create-alarm.sh, image-create.sh

dev_partBR() {
	DEV=$1
	[[ $DEV == /dev/mmc* ]] && DEV+=p
	PART_B=${DEV}1
	PART_R=${DEV}2
}
dialog.retrySD() {
	dialog.retry "$@" && dialog.sdCard
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
	[[ ! $dev_gib ]] && dialog.retrySD "No devices inserted in ${s}s." && return
#..............................................................................
	if [[ $dev_gib == sd* ]]; then
		sd_mmc=$( awk -F'[][]' '{print $2}' <<< $dev_gib ) # sd 5:0:0:0: [sdX] ... (31.9 GB/29.7 GiB)
	else
		sd_mmc=${dev_gib/:*}                               # mmcblkN: mmcN:0001 SD32G 29.7 GiB
	fi
	[[ $image_create ]] && dev_partBR $sd_mmc && return
#..............................................................................
	sleep 1
	line_lsblk=$( lsblk -po name,label,size,mountpoint )
	if [[ $select_part_BR ]]; then
		list_BR=$( grep -E ' BOOT | ROOT ' <<< $line_lsblk )
		txt_confirm='\Z1BOOT\Zn and \Z1ROOT\Zn'
		[[ ! $list_BR ]] && dialog.retrySD "Partitions $txt_confirm not found." && return
#..............................................................................
		readarray -t list_check < <( sed -E -e 's/^..|\s*$//;' -e 'a\off' <<< $list_BR )
	else # get dev
		list_check=( "$( grep ^/dev/$sd_mmc <<< $line_lsblk )" off )
		txt_confirm='\Z1SD card\Zn \Zb/ USB drive\Zn'
	fi
	list_colored=$( sed -E  -e '1 {s/^/\\\Zr\\\Zb/; s/$/\\\Zn/}
					' -e "/^.dev.$sd_mmc/ {s/^/\\\Z1/; s/$/\\\Zn/}
					" -e 's/(BOOT|ROOT)/\\Z1\1\\Zn/g' <<< $line_lsblk )
	H=$(( $( wc -l <<< $list_colored ) + 9 ))
	dialog.maxH $H
#............................
	dev_part=$( dialog $opt_check "
$list_colored

Select $txt_confirm to comfirm:
" $H 0 0 "${list_check[@]}" | sed 's/ .*//' )
	sL=$( awk NF <<< $dev_part | wc -l )
	if (( $sL == 0 )); then
		error+=None
	else
		if [[ $select_part_BR ]]; then
			case $sL in
				1 ) error='Only 1';;
				2 ) ;;
				* ) error='More than 2';;
			esac
		else
			(( $sL > 1 )) && error+='More than 1'
		fi
	fi
	if [[ $error ]]; then
#............................
		dialog $opt_msg "
\Z1Select $txt_confirm error:\Zn

$error selected:
$dev_part
" 0 0 && dialog.sdCard $1
	else
		if [[ $select_part_BR ]]; then
			part=( $dev_part )
			PART_B=${part[0]}
			PART_R=${part[1]}
            [[ $sd_mmc == /dev/sd* ]] && DEV=${PART_B:0:-1} || DEV=${PART_B:0:-2}
		else
	 		dev_partBR $dev_part
		fi
	fi
}

dialog.sdCard
