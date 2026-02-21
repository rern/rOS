#!/bin/bash

[[ ! -e common.sh ]] && wget -q https://github.com/rern/rOS/raw/refs/heads/main/common.sh

. common.sh

runScript() {
	[[ $1 = [dr]* ]] && repo=rOS || repo=rern.github.io
	bash <( curl -sL https://github.com/rern/$repo/raw/main/$1 )
}

dialog $opt_info "


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
case $cmd in
	1 ) runScript create;;
	2 ) runScript reset;;
	3 ) runScript imagecreate;;
	4 ) runScript imageupload;;
	5 ) runScript repoupdate;;
	6 ) runScript distcc-client;;
	7 ) runScript docker;;
	8 ) rpiip=$( dialog "${opt[@]}" --output-fd 1 --inputbox "
 IP:
" 0 0 192.168.1. )
		sed -i "/$rpiip/ d" ~/.ssh/known_hosts
		sshpass -p ros ssh -t -o StrictHostKeyChecking=no root@$rpiip
		;;
esac
