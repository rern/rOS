#!/bin/bash

. <( curl -sL https://github.com/rern/rOS/raw/main/common.sh )

https_rern='https://github.com/rern'
#........................
dialogSplash Image Utilities
list="\
Create OS^create-alarm
Reset for Image
Create Image^image-create
Upload Images^image-upload
Distcc Client^distcc-client
Docker^docker
SSH"
#........................
task=$( dialogMenu 'Tasks' "$( sed 's/\^.*//' <<< $list )" )
name=$( sed -n "$task {s/.*^//; p}" <<< $list )
if [[ $name ]]; then
	(( $task < 5 )) && repo=rOS || repo=rern.github.io
	. <( curl -sL "$https_rern/$repo/raw/main/$name.sh" )
else
#........................
	dialogSplash $name
	rpiip=$( dialogIP 'rAudio IP' )
	sed -i "/$rpiip/ d" ~/.ssh/known_hosts
	[[ $task == 2 ]] && bash_reset_sh="bash <( curl -sL $https_rern/rOS/raw/main/image-reset.sh )"
	sshpass -p ros ssh -t -o StrictHostKeyChecking=no root@$rpiip $bash_reset_sh
fi
