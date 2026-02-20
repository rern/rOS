#!/bin/bash

banner() {
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
optbox=( --colors --no-shadow --no-collapse )
opt=( --backtitle 'r  A  u  d  i  o' ${optbox[@]} )
