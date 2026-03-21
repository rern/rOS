#!/bin/bash

trap 'clear -x' EXIT

. <( curl -sL $https_rern/rOS/$branch/common.sh )

#............................
dialog.splash U t i l i t i e s
list="\
Create OS       : create-alarm
Reset for Image :
Create Image    : image-create
Upload Images   : image-upload
Distcc Client   : distcc-client
Docker          : docker
Repo Update     : repoupdate
SSH             :"
list_task=$( awk -F' *:' '{print $1}' <<< $list )
#............................
i=$( dialog.menu Tasks "$list_task" )
file_name=$( sed -n "$i {s/.*: *//; p}" <<< $list )
if [[ $file_name ]]; then
	(( $i < 5 )) && repo=rOS || repo=rern.github.io
	. <( curl -sL "$https_rern/$repo/$branch/$file_name.sh" )
else
#............................
	ip=$( dialog.ip 'rAudio IP' )
	[[ $i == 2 ]] && bash_reset_sh="bash <( curl -sL $https_ros_branch/image-reset.sh )"
	sshpass -p ros \
		ssh $opt_ssh root@$ip $bash_reset_sh
fi

