#!/bin/bash

[[ ! -e common.sh ]] && wget -q https://github.com/rern/rOS/raw/refs/heads/main/common.sh

. common.sh

dialog $opt_info "


                        \Z1r\Z0Audio
" 9 58
sleep 1
cmd=$( dialog $opt_menu "
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
names=( '' create reset imagecreate imageupload repoupdate distcc-client docker )
name=${names[$cmd]}
if [[ $name ]]; then
	(( $cmd < 5 )) && repo=rOS || repo=rern.github.io
	bash <( curl -sL "https://github.com/rern/$repo/raw/main/$name.sh" )
else # 8
	rpiip=$( dialog $opt_input "
 IP:
" 0 0 192.168.1. )
	sed -i "/$rpiip/ d" ~/.ssh/known_hosts
	sshpass -p ros ssh -t -o StrictHostKeyChecking=no root@$rpiip
fi
