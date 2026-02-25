#!/bin/bash

# on rpi: . <( curl -sL https://github.com/rern/rOS/raw/refs/heads/main/common.sh )

banner() {
	local cols
	cols=$( tput cols )
    printf "\n\e[44m%*s" $cols
    printf "\n%-${cols}s" "  $( echo $@ )"
    printf "\n%*s\e[0m\n\n" $cols
}
errorExit() {
	banner E r r o r
	echo -e "\n\e[41m ! \e[0m $@\n"
	exit
}
dialogDevice() { # $1=sdx; $2=confirm text
	local list
	list=$( lsblk -o name,label,size,mountpoint \
			| sed -E  -e '1 {s/^/\\\Zr/; s/$/\\\ZR/}
					' -e "/^$1/ {s/^/\\\Z1/; s/$/\\\Zn/}
					" -e 's/(BOOT|ROOT)/\\Z1\1\\Zn/g' )
#........................
	dialog $opt_yesno "
$list

\Zr $2 \ZR
$( grep '^\\Z1' <<< $list )

" 0 0 || exit
}
selected() {
	grep -q -m1 "$1" <<< $select && return 0
}
splash() {
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
	sleep 2
	clear -x
}

bar='\e[44m  \e[0m'
option='--colors --no-shadow --no-collapse --backtitle rAudio'
opt_outfd="$option --output-fd 1 --nocancel"
opt_check="$opt_outfd  --no-items --separate-output --checklist" # no leading N, multiline output
opt_guage="$option --guage"
 opt_info="$option --infobox"
opt_input="$opt_outfd --inputbox"
 opt_menu="$opt_outfd --menu"
  opt_msg="$option --msgbox"
opt_yesno="$option --yesno"
