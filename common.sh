#!/bin/bash

# on rpi - create-ros.sh, image-reset.h: . <( curl -sL https://github.com/rern/rOS/raw/main/common.sh )

banner() {
	local cols
	cols=$( tput cols )
    printf "\n\e[44m%*s" $cols
    printf "\n%-${cols}s" "  $( echo $@ )"
    printf "\n%*s\e[0m\n\n" $cols
}
boot_rootMount() {
	if [[ $1 == unmount ]]; then
		umount -l $BOOT $ROOT
		rmdir $BOOT $ROOT
	else
		mkdir -p BOOT ROOT
		mount ${1[0]} $BOOT
		mount ${2[1]} $ROOT
	fi
}
dialogSplash() {
	local H h i line pad txt W w
	H=9
	W=58
	h=$( wc -l <<< $1 )
	pad=$(( ( H - h ) / 2 ))
	for (( i=1; i < $pad; i++ )); do # i=1: after top border
		txt+='\n'
	done
	while read -r line; do
		[[ $line != *[![:space:]]* ]] && txt+='\n' && continue
		
		w=$(( ( W - ${#line} ) / 2 - 2 )) # -2: l/r border
		txt+="$( printf '%*s' $w )$line\n"
	done <<< $1
#........................
	dialog $opt_info "
$txt
" $H $W
	sleep 1
	clear -x
}
dialogSDcard() { # $1=confirm text
	local devline error H l list list_BR list_check list_colored selected sL text
#........................
	dialog $opt_msg "
\Z1Insert USB reader and/or SD card\Zn

If already inserted:
Remove and reinsert again for proper detection.

" 0 0
	devline=$( dmesgSDcard )
	[[ ! $devline ]] && sleep 2 && devline=$( dmesgSDcard )
	[[ ! $devline ]] && errorExit No SD card found
#---------------------------------------------------------------
	if [[ $devline == sd* ]]; then
		dev=$( awk -F'[][]' '{print $2}' <<< $devline ) # sdX
	else
		dev=$( cut -d: -f1 <<< $devline )               # mmcbklN
	fi
	list=$( lsblk -po name,label,size,mountpoint )
	list_colored=$( sed -E  -e '1 {s/^/\\\Zr/; s/$/\\\ZR/}
					' -e "/^.dev.$dev/ {s/^/\\\Z1/; s/$/\\\Zn/}
					" -e 's/(BOOT|ROOT)/\\Z1\1\\Zn/g' <<< $list )
	if [[ $1 ]]; then # for $dev
		text='SD card'
		list_check+=( "$( grep ^/dev/$dev <<< $list )" off )
	else
		text='BOOT\Zn and \Z1ROOT'
		list_BR=$( grep -E ' BOOT | ROOT ' <<< $list | sed -n '/^..\// {s/^..//; s/\s*$//; p}' )
		while read l; do
			list_check+=( "$l" off )
		done <<< $list_BR
	fi
	H=$(( $( wc -l <<< $list_colored ) + ${#list_check[@]} + 5 ))
	[[ $1 ]] && (( H++ ))
#........................
	selected=$( dialog $opt_check "
$list_colored

Select/Click \Z1$text\Zn to comfirm:
" $H 0 0 "${list_check[@]}" | sed 's/ .*//' )
	sL=$( awk NF <<< $selected | wc -l )
	if (( $sL == 0 )); then
		error=None
	else
		if [[ $1 ]]; then
			(( $sL > 1 )) && error='More than 1' || dev=$selected
		else
			case $sL in
				1 ) error='Only 1';;
				2 ) partitions=( $selected );;
				* ) error='More than 2';;
			esac
		fi
	fi
#........................
	[[ $error ]] && dialog $opt_msg "
\Z1Select $text error\Zn

$error selected: $selected
" 0 0 && dialogSDcard $1
}
dmesgSDcard() {
	dmesg \
		| tail \
		| grep -m1 -E '] sd.* GiB|] mmcblk.* GiB' \
		| sed -E 's/.* ([sm])/\1/'
		# > sd 5:0:0:0: [sdX] 62333952 512-byte logical blocks: (31.9 GB/29.7 GiB) > sdX
			# OR > mmcblkN: mmcN:0001 SD32G 29.7 GiB > mmcblkN
}
errorExit() {
	banner E r r o r
	echo -e "\e[41m ! \e[0m $@\n"
	exit
}

bar='\e[44m  \e[0m'
option='--colors --no-shadow --no-collapse --backtitle rAudio'
opt_outfd="$option --output-fd 1 --nocancel"
opt_check="$opt_outfd --no-items --separate-output --checklist" # no leading N, multiline output
opt_guage="$option --guage"
 opt_info="$option --infobox"
opt_input="$opt_outfd --inputbox"
 opt_menu="$opt_outfd --menu"
  opt_msg="$option --msgbox"
opt_yesno="$option --yesno"
