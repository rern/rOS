#!/bin/bash

# . <( curl -sL https://raw.githubusercontent.com/rern/rOS/main/common.sh )

alignCenter() {
	local l line txt w
	while read -r line; do # -r keep \
		[[ $line != *[![:space:]]* ]] && txt+='\n' && continue

		l=$( sed 's/\\Z.//g' <<< $line ) # remove text color \Zn
		w=$(( ( W - ${#l} ) / 2 - 2 )) # -2: l/r border
		txt+="
$( printf '%*s' $w )$line\n"
	done <<< "$@"
	echo "$txt"
}
banner() { # should be used on start stdout to screen
	local cols
	clear -x
	cols=$( tput cols )
	printf "\n\e[44m%*s" $cols
	printf "\n%-${cols}s" "  $( echo -e "$@" )"
	printf "\n%*s\e[0m\n\n" $cols
}
bar() {
	echo -e "\n\e[44m  \e[0m $@\n"
}
BR.mount() { # create-alarm.sh, image-create.sh
	mkdir -p BOOT ROOT
	mount -o rw,noatime,nodiratime $PART_B BOOT
	mount -o rw,noatime,nodiratime $PART_R ROOT
}
BR.unmount() {
	if findmnt BOOT &> /dev/null; then
		rm -f BOOT/{features,release}
		umount -l BOOT ROOT &> /dev/null
		rmdir BOOT ROOT &> /dev/null
	fi
}
dialog.error_exit() {
	dialog $opt_msg "
$warn Error:

$( echo -e "$@" )
" 0 0
	clear -x
	exit
#-------------------------------------------------------------------------------
}
dialog.ip() {
	local ip
	[[ ! $ip_base ]] && ip_base=$( ipBase )
	ip=$( dialog.input "\Z1$1:\Zn" $ip_base )
	[[ ${ip%.*}. == $ip_base ]] && ip_oct4=${ip/$ip_base}
	if [[ $ip_oct4 && $ip_oct4 == [0-9]* ]] && (( $ip_oct4 > 0 && $ip_oct4 < 255 )); then
		echo $ip
	else
		dialog $opt_msg "
Invalid IP: \Z1$ip\Zn

" 0 0 && dialog.ip "$1"
	fi
}
dialog.input() {
	dialog $opt_input "
 $1

" 8 40 "$2"
}
dialog.menu() { # dialog --menu $1=title $2=multiline list
	local -a list
	readarray -t list < <( awk 'NF {print ++i; print}' <<< $2 )
#............................
	dialog $opt_menu "
$1:
" 8 0 0 "${list[@]}"
}
dialog.retry() {
	dialog $opt_msg "
$warn $( echo -e "$@" )

Retry?
" 0 0
}
dialog.sd() {
	local dev dev_gib l p s
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
			dialog.sd
			return
#..............................................................................
		fi
	fi
	if [[ $dev_gib == sd* ]]; then
		dev=/dev/$( awk -F'[][]' '{print $2}' <<< $dev_gib ) # sd 5:0:0:0: [sdX] ... (31.9 GB/29.7 GiB)
	else
		dev=/dev/${dev_gib/:*}                               # mmcblkN: mmcN:0001 SD32G 29.7 GiB
		p=p
	fi
	echo $dev $dev${p}1 $dev${p}2
}
dialog.splash() {
	tput civis # fix: hide cursor at corner
#............................
	dialog $opt_info "$( alignCenter "

$logo

$@" )" $(( 8 + $( wc -l <<< $@ ) )) $W
	tput cnorm # restore cursor
}
ipBase() {
	ip route get 1.1.1.1 | grep -oP '(?<=src ).*\..*\..*\.'
}
kbKey() {
	echo "\Zr\Zb $1 \Zn"
}
killChildProcess() {
	kill -TERM -$$ &> /dev/null
}
runDuration() {
	echo \\Z4$( date -d@$1 -u +%M:%S )\\Zn
}
#         https://raw.githubusercontent.com/rern/REPO/BRANCH/file
https_raw=https://raw.githubusercontent.com
https_rern=$https_raw/rern
https_ros=$https_rern/rOS/$branch
https_io=$https_rern/rern.github.io/main
https_mirrorlist=$https_raw/archlinuxarm/PKGBUILDs/master/core/pacman-mirrorlist/mirrorlist
opt_ssh='-qtt -o ConnectTimeout=3
			  -o StrictHostKeyChecking=no
			  -o UserKnownHostsFile=/dev/null'

logo='\Zr\Z4+R\Zn'
warn='\Zr\Z1 ! \Zn'
sd_usb='\Z1SD card\Zn / \Z4USB drive\Zn'
W=50
# auto fit: 0 0
#    0 0   - h w
#    8 0 0 - hf h w - checklist / menu (hf=8 - frame + button)
                 # keep spaces/tabs
option='--colors --no-collapse --no-shadow --stdout'
opt_gauge="$option --gauge"                                  # no buttons
 opt_info="$option --sleep 2 --infobox"                      # no buttons
  opt_msg="$option --msgbox"                                 # <OK> only
opt_yesno="$option --yesno"                                  # <Yes> <No>
# --nocancel         (center <OK>, [ctrl+c]=cancel)
option+=' --nocancel'
opt_input="$option --inputbox"
 opt_menu="$option --menu"                                   # select single
                   # no number  multiline stdout
opt_check="$option --no-items --separate-output --checklist" # select multiple
