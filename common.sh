#!/bin/bash

# on rpi - create-ros.sh, image-reset.h: . <( curl -sL https://github.com/rern/rOS/raw/main/common.sh )

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
BOOT_ROOT.check() { # create-alarm.sh, image-create.sh
	BOOT_ROOT.unmount
	banner Check Partitions ...
	bar BOOT: $part_B ...
	fsck.fat -taw $part_B
	bar ROOT: $part_R ...
	e2fsck -p $part_R
}
BOOT_ROOT.unmount() {
	! findmnt $BOOT &> /dev/null && return

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
dialogErrorExit() {
	dialog $opt_msg "
\Zr\Z1 ! \Zn Error:

$( echo -e "$@" )
" 0 0
	clear -x
	exit
#----------------------------------------------------------------------------
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
dialogRetry() {
	dialog $opt_msg "
\Zr\Z1 ! \Zn $( echo -e "$@" )

Retry?
" 0 0
}
dialogSplash() {
	tput civis # fix: hide cursor at corner
#........................
	dialog $opt_info "$( textAlignCenter "

\Zr\Z4+R\Zn

$@" )" 9 $w_dialog
	tput cnorm # restore cursor
}
ipBase() {
	local ip_router
	ip_router=$( ip r get 1 | head -1 | cut -d' ' -f3 )
	echo ${ip_router%.*}.
}
textAlignCenter() {
	local l line txt w
	while read -r line; do
		[[ $line != *[![:space:]]* ]] && txt+='\n' && continue
		
		l=$( sed 's/\\Z.//g' <<< $line ) # remove text color \Zn
		w=$(( ( w_dialog - ${#l} ) / 2 - 2 )) # -2: l/r border
		txt+="
$( printf '%*s' $w )$line\n"
	done <<< "$@"
	echo "$txt"
}

                 # keep spaces/tabs          capture stdout
option='--colors --no-collapse --no-shadow --output-fd 1'
opt_guage="$option --guage"                                  # no buttons
 opt_info="$option --sleep 2 --infobox"                      # no buttons
  opt_msg="$option --msgbox"                                 # <OK> only
opt_yesno="$option --yesno"                                  # <Yes> <No>
# --nocancel         (center <OK>, [ctrl+c]=cancel)
option+=' --nocancel'
opt_input="$option --inputbox"
 opt_menu="$option --menu"                                   # select single
                   # no number  multiline stdout
opt_check="$option --no-items --separate-output --checklist" # select multiple
w_dialog=55
# auto fit: 0
#    0 0   - h w
#    8 0 0 - h hl w - checklist / menu (h=8 - frame + button)
