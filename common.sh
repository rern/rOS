banner() {
	local cols col_s
	cols=$( tput cols )
	col_s=%${cols}s
	text=$( printf "  $( echo $@ )$col_s" )
    printf "\n\e[44m$col_s\n${text:0:$cols}\n$col_s\e[0m\n"
}
errorExit() {
	banner E r r o r
	echo -e "\n\e[41m ! \e[0m $@"
	exit
}
