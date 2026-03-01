#!/bin/bash

# on rpi - create-ros.sh, image-reset.h: . <( curl -sL https://github.com/rern/rOS/raw/main/common.sh )

banner() {
	local cols
	cols=$( tput cols )
    printf "\n\e[44m%*s" $cols
    printf "\n%-${cols}s" "  $( echo $@ )"
    printf "\n%*s\e[0m\n\n" $cols
}
BOOT_ROOT.checkMount() { # create-alarm.sh, image-create.sh
	banner Check Filesystem ...
	if [[ ! $name ]]; then # not from +R.sh
		[[ $( lsblk -no fstype $part_B ) != vfat ]] && error+="$part_B : BOOT not vfat\n"
		[[ $( lsblk -no fstype $part_R ) != ext4 ]] && error+="$part_R : ROOT not ext4\n"
		[[ $error ]] && errorExit $error
#----------------------------------------------------------------------------
	fi
	fsck.fat -taw $part_B
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
# --keep-tite        clear dialog screen after
# --nocancel         (center <OK>)
# --no-collapse      keep spaces and tabs
# --no-items         no leading N
# --output-fd 1      capture stdout
# --separate-output  multiline stdout
option='--backtitle rAudio --colors --keep-tite --no-collapse --no-shadow --output-fd 1'
opt_check="$option --no-items --separate-output --checklist" # select multiple
opt_guage="$option --guage"                                  # no buttons
opt_input="$option --nocancel --inputbox"
 opt_info="$option --sleep 1 --infobox"                      # no buttons
 opt_menu="$option --nocancel --menu"                        # select single
  opt_msg="$option --msgbox"                                 # <OK> only
opt_yesno="$option --yesno"                                  # <Yes> <No>
