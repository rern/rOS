#!/bin/bash

trap 'clear -x' EXIT

. <( curl -sL https://github.com/rern/rOS/raw/main/common.sh )

https_rern='https://github.com/rern'
#........................
dialog.splash U t i l i t i e s
list="\
Create OS       : create-alarm
Reset for Image :
Create Image    : image-create
Upload Images   : image-upload
Distcc Client   : distcc-client
Docker          : docker
SSH             :"
list_task=$( awk -F' *:' '{print $1}' <<< $list )
#........................
i=$( dialog.menu Tasks "$list_task" )
file_name=$( awk 'NR=='$i' {print $NF}' <<< $list )
if [[ $file_name ]]; then
	(( $i < 5 )) && repo=rOS || repo=rern.github.io
	. <( curl -sL "$https_rern/$repo/raw/main/$file_name.sh" )
else
#........................
	ip=$( dialog.ip 'rAudio IP' )
	sed -i "/$ip/ d" ~/.ssh/known_hosts
	(( $i == 2 )) && bash_reset_sh="bash <( curl -sL $https_rern/rOS/raw/main/image-reset.sh )"
	sshpass -p ros ssh -t -o StrictHostKeyChecking=no root@$ip $bash_reset_sh
fi
