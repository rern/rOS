#!/bin/bash

# on rpi - create-ros.sh, image-reset.h: . <( curl -sL https://github.com/rern/rOS/raw/main/common.sh )

banner() { # should be used on start stdout to screen
	local cols
	clear -x
	cols=$( tput cols )
    printf "\n\e[44m%*s" $cols
    printf "\n%-${cols}s" "  $( echo $@ )"
    printf "\n%*s\e[0m\n\n" $cols
}
BOOT_ROOT.checkMount() { # create-alarm.sh, image-create.sh
	banner Check Partitions ...
	lbl_partB="BOOT: $part_B"
	lbl_partR="ROOT: $part_R"
	if [[ ! $name ]]; then # not from +R.sh
		[[ $( lsblk -no fstype $part_B ) != vfat ]] && error+="$lbl_partB not vfat\n"
		[[ $( lsblk -no fstype $part_R ) != ext4 ]] && error+="$lbl_partR not ext4\n"
		[[ $error ]] && errorExit $error
#----------------------------------------------------------------------------
	fi
	echo -e "$bar $lbl_partB ..."
	fsck.fat -taw $part_B
	echo -e "$bar $lbl_partR ..."
	e2fsck -p $part_R
	BOOT_ROOT.mount
}
BOOT_ROOT.unmount() {
	umount -l $BOOT $ROOT &> /dev/null
	rmdir $BOOT $ROOT &> /dev/null
}
BOOT_ROOT.mount() {
	BOOT=$PWD/BOOT
	ROOT=$PWD/ROOT
	mkdir -p BOOT ROOT
	mount $part_B $BOOT
	mount $part_R $ROOT
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
dialogSplash() {
	local H h i l line pad txt w
	H=9
	h=$( wc -l <<< $1 )
	pad=$(( ( H - h ) / 2 ))
	for (( i=2; i < $pad; i++ )); do # i=2: after top border
		txt+='\n'
	done
	while read -r line; do
		[[ $line != *[![:space:]]* ]] && txt+='\n' && continue
		
		l=$( sed 's/\\Z.//g' <<< $line ) # remove text color \Zn
		w=$(( ( w_dialog - ${#l} ) / 2 - 2 )) # -2: l/r border
		txt+="$( printf '%*s' $w )$line\n"
	done <<< "\
\Z1r\ZnAudio

$@"
#........................
	dialog $opt_info "$txt" $H $w_dialog
}
errorExit() {
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

# --no-collapse      keep spaces and tabs
# --output-fd 1      capture stdout
option='--backtitle rAudio --colors --no-collapse --no-shadow --output-fd 1'
opt_guage="$option --guage"                                  # no buttons
 opt_info="$option --sleep 2 --infobox"                      # no buttons
  opt_msg="$option --msgbox"                                 # <OK> only
opt_yesno="$option --yesno"                                  # <Yes> <No>
# --nocancel         (center <OK>, [ctrl+c]=cancel)
option+=' --nocancel'
opt_input="$option --inputbox"
 opt_menu="$option --menu"                                   # select single
# --no-items         no leading N
# --separate-output  multiline stdout
opt_check="$option --no-items --separate-output --checklist" # select multiple
w_dialog=55
# auto fit: 0
#    0 0   - h w
#    8 0 0 - h hl w - checklist / menu (h=8 - frame + button)
