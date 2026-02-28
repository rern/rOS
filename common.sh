#!/bin/bash

# on rpi - create-ros.sh, image-reset.h: . <( curl -sL https://github.com/rern/rOS/raw/main/common.sh )

banner() {
	local cols
	cols=$( tput cols )
    printf "\n\e[44m%*s" $cols
    printf "\n%-${cols}s" "  $( echo $@ )"
    printf "\n%*s\e[0m\n\n" $cols
}
BOOT_ROOT.unmount() {
	umount -l $BOOT $ROOT
	rmdir $BOOT $ROOT
}
BOOT_ROOT.mount() {
	mkdir -p BOOT ROOT
	mount ${partitions[0]} $BOOT
	mount ${partitions[1]} $ROOT
}
dialogIP() {
	local ip
	[[ ! $ip_base ]] && ip_base=$( ipBase )
	ip=$( dialog $opt_input "
\Z1$1:\Zn

" 0 0 $ip_base )
	[[ ${ip%.*}. == $ip_base ]] && ip_oct4=${ip/$ip_base}
	if [[ $ip_oct4 && $ip_oct4 == [0-9]* ]] && (( $ip_oct4 > 0 && $ip_oct4 < 255 )); then
		echo $ip
	else
		dialog $opt_msg "
Invalid IP: \Z1$ip\Zn

" 0 0 && dialogIP "$1"
	fi
}
dialogMenu() { # dialog --menu $1=title $2=multiline list
	local i l list_menu
	i=0
	while read l; do
		(( i++ ))
		list_menu+=( $i "$l" )
	done <<< $2
#........................
	dialog $opt_menu "
$1:
" 8 0 0 "${list_menu[@]}" # h=8: exclude list box
}
dialogSDcard() { # [[ $1 ]] && echo /dev/sdX || echo /dev/sdX1 /dev/sdX2
	local dev devline error H l list list_BR list_check list_colored sd_part sL text
#........................
	dialog $opt_msg "
\Z1Insert USB reader + SD card / SD card\Zn

If already inserted:
Remove and reinsert for proper detection.

Press Enter to continue
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
	if [[ $1 ]]; then
		text='SD card'
		list_check+=( "$( grep ^/dev/$dev <<< $list )" off )
	else
		text='BOOT\Zn and \Z1ROOT'
		list_BR=$( grep -E ' BOOT | ROOT ' <<< $list | sed -n '/^..\// {s/^..//; s/\s*$//; p}' )
		while read l; do
			list_check+=( "$l" off )
		done <<< $list_BR
	fi
	H=$(( $( wc -l <<< $list ) + 9 ))
#........................
	sd_part=$( dialog $opt_check "
$list_colored

Select/Click \Z1$text\Zn to comfirm:
" $H 0 0 "${list_check[@]}" | sed 's/ .*//' ) # h=8: exclude list box
	sL=$( awk NF <<< $sd_part | wc -l )
	if (( $sL == 0 )); then
		error=None
	else
		if [[ $1 ]]; then
			(( $sL > 1 )) && error='More than 1'
		else
			case $sL in
				1 ) error='Only 1';;
				2 ) ;;
				* ) error='More than 2';;
			esac
		fi
	fi
	if [[ $error ]]; then
#........................
		dialog $opt_msg "
\Z1Select $text error\Zn

$error selected: $sd_part
" 0 0 && dialogSDcard $1
	else
		echo $sd_part
	fi
}
dialogSplash() { # dialog --infobox
	local H h i l line pad txt W w
	H=9
	W=58
	h=$( wc -l <<< $1 )
	pad=$(( ( H - h ) / 2 ))
	for (( i=1; i < $pad; i++ )); do # i=1: after top border
		txt+='\n'
	done
	while read -r line; do
		[[ $line != *[![:space:]]* ]] && txt+='\n' && continue
		
		l=$( sed 's/\\Z.//g' <<< $line ) # remove text color \Zn
		w=$(( ( W - ${#l} ) / 2 - 2 )) # -2: l/r border
		txt+="$( printf '%*s' $w )$line\n"
	done <<< $1
#........................
	dialog $opt_info "
$txt
" $H $W
	sleep 1
	clear -x
}
errorExit() {
	clear -x
	banner E r r o r
	echo -e "\e[41m ! \e[0m $@\n"
	exit
}
ipBase() {
	local ip_router
	ip_router=$( ip r get 1 | head -1 | cut -d' ' -f3 )
	echo ${ip_router%.*}.
}

bar='\e[44m  \e[0m'
option='--backtitle rAudio --colors --nocancel --no-collapse --no-shadow --output-fd 1' # --output-fd 1: stdout
opt_check="$option --no-items --separate-output --checklist" # select multiple            --no-items   : no leading N, multiline output
opt_guage="$option --guage"               # no buttons
opt_input="$option --inputbox"            # input with button (--nocancel=hide)
 opt_menu="$option --menu"                # select single
 opt_info="$option --infobox"             # no buttons, use 'sleep N' to delay continue
  opt_msg="$option --msgbox"              # ok button only
opt_yesno="${option/ --nocancel} --yesno" # Yes and No buttons
