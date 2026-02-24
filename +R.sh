#!/bin/bash

file_common=/usr/local/bin/common.sh
[[ ! -e $file_common ]] && curl -sL https://github.com/rern/rOS/raw/refs/heads/main/common.sh -o $file_common

. common.sh

#........................
dialog $opt_info "


                        \Z1r\ZnAudio
" 9 58
sleep 1
#........................
cmd=$( dialog $opt_menu '
\Z1Tasks:\Zn
' 8 0 0 \
	1 'OS - Create' \
	2 'OS - Reset to default' \
	3 'Image - Create' \
	4 'Images - Upload' \
	5 'Repository - Update packages' \
	6 'Distcc client' \
	7 'Docker' \
	8 'SSH to RPi' )
names=( '' create reset image-create image-upload repoupdate distcc-client docker )
name=${names[$cmd]}
if [[ $name ]]; then
	(( $cmd < 5 )) && repo=rOS || repo=rern.github.io
	bash <( curl -sL "https://github.com/rern/$repo/raw/main/$name.sh" )
else # 8
#........................
	rpiip=$( dialog $opt_input "
 IP:
" 0 0 192.168.1. )
	sed -i "/$rpiip/ d" ~/.ssh/known_hosts
	sshpass -p ros ssh -t -o StrictHostKeyChecking=no root@$rpiip
fi
