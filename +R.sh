#!/bin/bash

[[ ! -e common.sh ]] && echo '
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
' > common.sh

optbox=( --colors --no-shadow --no-collapse )

dialog "${optbox[@]}" --infobox "


                        \Z1r\Z0Audio
" 9 58
sleep 1

cmd=$( dialog "${optbox[@]}" --output-fd 1 --menu "
 \Z1r\Z0Audio:
" 8 0 0 \
1 'Create rAudio' \
2 'Reset to default' \
3 'Compress to image file' \
4 'Upload image files' \
5 'Update package repository' \
6 'Distcc client' \
7 'Docker' \
8 'SSH to RPi' )

url=https://github.com/rern/rOS/raw/main
urlio=https://github.com/rern/rern.github.io/raw/main

case $cmd in
	1 ) bash <( curl -sL $url/create.sh );;
	2 ) bash <( curl -sL $url/reset.sh );;
	3 ) bash <( curl -sL $url/imagecreate.sh );;
	4 ) bash <( curl -sL $url/imageupload.sh );;
	5 ) bash <( curl -sL $urlio/repoupdate.sh );;
	6 ) bash <( curl -sL $urlio/distcc-client.sh );;
	7 ) bash <( curl -sL $urlio/docker.sh );;
	8 ) rpiip=$( dialog "${opt[@]}" --output-fd 1 --inputbox "
 IP:
" 0 0 192.168.1. )
		sed -i "/$rpiip/ d" ~/.ssh/known_hosts
		sshpass -p ros ssh -t -o StrictHostKeyChecking=no root@$rpiip
		;;
esac
