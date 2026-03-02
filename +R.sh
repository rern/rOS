#!/bin/bash

. <( curl -sL https://github.com/rern/rOS/raw/main/common.sh )

https_rern='https://github.com/rern'
#........................
dialogSplash Image Utilities
list="\
Create OS^create-alarm
Reset for Image
Create image^image-create
Upload images^image-upload
Distcc client^distcc-client
Docker^docker
SSH"
#........................
task=$( dialogMenu 'Tasks' "$( sed 's/\^.*//' <<< $list )" )
name=$( sed -n "$task {s/.*^//; p}" <<< $list )
if [[ $task == 2 || $task == 7 ]]; then
#........................
	dialogSplash $name
	[[ $task == 2 ]] && image_reset_sh="bash <( curl -sL $https_rern/rOS/raw/main/image-reset.sh )"
	rpiip=$( dialogIP 'rAudio IP' )
	sed -i "/$rpiip/ d" ~/.ssh/known_hosts
	sshpass -p ros ssh -t -o StrictHostKeyChecking=no root@$rpiip $image_reset_sh
else
	(( $task < 5 )) && repo=rOS || repo=rern.github.io
	. <( curl -sL "$https_rern/$repo/raw/main/$name.sh" )
fi
