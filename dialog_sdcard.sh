#!/bin/bash

# set global $dev part_B part_R for create-alarm.sh, image-create.sh

dev_partBR() {
	dev=$1
	[[ $dev == /dev/mmc* ]] && dev+=p
	part_B=${dev}1
	part_R=${dev}2
}
dialogSDcard() {
	local dev dev_gib l
#........................ (no --sleep 1)
	dialog $option --infobox "
Insert \Z1SD card\Zn / USB drive

If already inserted, remove and reinsert.

" 0 0
	while read l; do
		dev_gib=$( grep -m1 -E '^(sd|mmcblk).* GiB' <<< $l )
		[[ $dev_gib ]] && break
	done < <( timeout 30 dmesg -tW )
	[[ ! $dev_gib ]] && errorExit 'No SD card found (30s timeout)'
#---------------------------------------------------------------
	if [[ $dev_gib == sd* ]]; then
		dev=$( awk -F'[][]' '{print $2}' <<< $dev_gib ) # sd 5:0:0:0: [sdX] ... (31.9 GB/29.7 GiB)
	else
		dev=${dev_gib/:*}                               # mmcblkN: mmcN:0001 SD32G 29.7 GiB
	fi
	[[ $image_create ]] && dev_partBR $dev || dialogSDconfirm $dev
}
dialogSDconfirm() { # $1=sdX/mmcblkN
	local error H l line_lsblk list_BR list_check list_colored part dev_part sL txt_confirm
	line_lsblk=$( lsblk -po name,label,size,mountpoint )
	list_colored=$( sed -E  -e '1 {s/^/\\\Zr/; s/$/\\\ZR/}
					' -e "/^.dev.$1/ {s/^/\\\Z1/; s/$/\\\Zn/}
					" -e 's/(BOOT|ROOT)/\\Z1\1\\Zn/g' <<< $line_lsblk )
	if [[ $create_alarm ]]; then
		list_BR=$( grep -E ' BOOT | ROOT ' <<< $line_lsblk | sed -n '/^..\// {s/^..//; s/\s*$//; p}' )
		[[ ! $list_BR ]] && errorExit Partition not found: BOOT and ROOT
#---------------------------------------------------------------
		while read l; do
			list_check+=( "$l" off )
		done <<< $list_BR
		txt_confirm='\Z1BOOT\Zn and \Z1ROOT\Zn'
	else # get dev
		list_check+=( "$( grep ^/dev/$1 <<< $line_lsblk )" off )
		txt_confirm='\Z1SD card\Zn / USB drive'
	fi
	H=$(( $( wc -l <<< $line_lsblk ) + 9 ))
#........................
	dev_part=$( dialog $opt_check "
$list_colored

Select $txt_confirm to comfirm:
" $H 0 0 "${list_check[@]}" | sed 's/ .*//' )
	sL=$( awk NF <<< $dev_part | wc -l )
	if (( $sL == 0 )); then
		error+=None
	else
		if [[ $get_partition ]]; then
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
#........................
		dialog $opt_msg "
\Z1Select $txt_confirm error:\Zn

$error selected:
$dev_part
" 0 0 && dialogSDcard $1
	else
		if [[ $get_partition ]]; then
			part=( $dev_part )
			part_B=${part[0]}
			part_R=${part[1]}
            dev=${part_B:0:-1}
            [[ $dev == /dev/mmc* ]] && dev=${dev:0:-1}
		else
	 		dev_partBR $dev_part
		fi
	fi
}

dialogSDcard
