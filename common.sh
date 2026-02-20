#!/bin/bash

banner() {
	local cols
	cols=$( tput cols )
    printf "\n\e[44m%*s" $cols
    printf "\n%-${cols}s" "  $( echo $@ )"
    printf "\n%*s\e[0m\n\n" $cols
}
errorExit() {
	banner E r r o r
	echo -e "\n\e[41m ! \e[0m $@"
	exit
}

bar='\e[44m  \e[0m'
option='--colors --no-shadow --no-collapse --backtitle "r  A  u  d  i  o"'
opt_guage="$option --guage"
 opt_info="$option --infobox"
opt_outfd="$option --output-fd 1 --nocancel"
opt_check="$opt_outfd --checklist"
opt_input="$opt_outfd --inputbox"
 opt_menu="$opt_outfd --menu"
  opt_msg="$option --msgbox"
opt_yesno="$option --yesno"
