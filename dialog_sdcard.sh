#!/bin/bash

dialogSDcard() { # for create-alarm.sh, image-create.sh
	local dev devline error H l list list_BR list_check list_colored part sd_part sL text
#........................
	dialog $opt_msg "
Insert \Z1USB reader + SD card\Zn or \Z1SD card\Zn

If already inserted:
Remove and reinsert for proper detection.

Press \Zr Enter \ZR to continue
" 0 0
	for i in {0..3}; do
		devline=$( dmesg | tail | grep -m1 -E '] sd.* GiB|] mmcblk.* GiB' )
		[[ $devline ]] && break || sleep 1
	done
	[[ ! $devline ]] && errorExit No SD card found
#---------------------------------------------------------------
	if [[ $devline == *mmcblk* ]]; then
		dev=$( sed 's/:.*//; s/.* //' <<< $devline )    # ...] mmcblkN: mmcN:0001 SD32G 29.7 GiB
	else
		dev=$( awk -F'[][]' '{print $4}' <<< $devline ) # ...] sd 5:0:0:0: [sdX] ... (31.9 GB/29.7 GiB)
	fi
	list=$( lsblk -po name,label,size,mountpoint )
	list_colored=$( sed -E  -e '1 {s/^/\\\Zr/; s/$/\\\ZR/}
					' -e "/^.dev.$dev/ {s/^/\\\Z1/; s/$/\\\Zn/}
					" -e 's/(BOOT|ROOT)/\\Z1\1\\Zn/g' <<< $list )
	if [[ $get_partition ]]; then
		text='BOOT\Zn and \Z1ROOT'
		list_BR=$( grep -E ' BOOT | ROOT ' <<< $list | sed -n '/^..\// {s/^..//; s/\s*$//; p}' )
		while read l; do
			list_check+=( "$l" off )
		done <<< $list_BR
	else # get dev
		text='SD card'
		list_check+=( "$( grep ^/dev/$dev <<< $list )" off )
	fi
	H=$(( $( wc -l <<< $list ) + 9 ))
#........................
	sd_part=$( dialog $opt_check "
$list_colored

Select/Click \Z1$text\Zn to comfirm:
" $H 0 0 "${list_check[@]}" | sed 's/ .*//' ) # h=8: exclude list box
	sL=$( awk NF <<< $sd_part | wc -l )
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
\Z1Select $text error:\Zn

$error selected:
$sd_part
" 0 0 && dialogSDcard $1
	else
		if [[ $get_partition ]]; then
			part=( $sd_part )
			part_B=${part[0]}
			part_R=${part[1]}
            [[ $part_B == /dev/sd* ]] && dev=${part_B:0:1} || dev=${part_B:0:2}
		else
			[[ $sd_part == /dev/sd* ]] && dev=$sd_part || dev=${sd_part}p
			part_B=${dev}1
			part_R=${dev}2
		fi
        echo $dev $part_B $part_R
	fi

}
