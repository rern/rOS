#!/bin/bash

. <( curl -sL https://github.com/rern/rOS/raw/main/common.sh )

#........................
dialogSplash 'Image Utilities'
list="\
rAudio - Create^create-alarm
rAudio - Reset for image
Image  - Create^image-create
Images - Upload^image-upload
Distcc Client^distcc-client
Docker^docker
SSH to rAudio"
#........................
task=$( dialogMenu 'Tasks' "$( sed 's/\^.*//' <<< $list )" )
if [[ $task == 2 || $task == 7 ]]; then
	if [[ $task == 2 ]]; then
#........................
		dialogSplash 'Reset for Image'
		image_reset_sh='bash <( curl -sL https://github.com/rern/rOS/raw/main/image-reset.sh )'
	fi
#........................
	rpiip=$( dialogIP 'rAudio IP' )
	sed -i "/$rpiip/ d" ~/.ssh/known_hosts
	sshpass -p ros ssh -t -o StrictHostKeyChecking=no root@$rpiip $image_reset_sh
else
	name=$( sed -n "$task {s/.*^//; p}" <<< $list )
	(( $task < 5 )) && repo=rOS || repo=rern.github.io
	. <( curl -sL "https://github.com/rern/$repo/raw/main/$name.sh" )
fi
