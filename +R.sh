#!/bin/bash

. <( curl -sL https://github.com/rern/rOS/raw/main/common.sh )
#........................
dialogSplash 'Image Utilities'
list_task="\
rAudio - Create
rAudio - Reset for image
Image  - Create
Images - Upload
Distcc client
Docker
SSH to rAudio"
i=0
while read l; do
	(( i++ ))
	list_menu+=( $i "$l" )
done <<< $list_task
#........................
cmd=$( dialog $opt_menu '
\Z1Tasks:\Zn
' 8 0 0 "${list_menu[@]}" )
if [[ $cmd == 2 || $cmd == 7 ]]; then
	if [[ $cmd == 2 ]]; then
#........................
		dialogSplash 'Reset for Image'
		image_reset_sh='bash <( curl -sL https://github.com/rern/rOS/raw/main/image-reset.sh )'
	fi
	rpiip=$( dialogIP 'rAudio IP' )
	sed -i "/$rpiip/ d" ~/.ssh/known_hosts
	sshpass -p ros ssh -t -o StrictHostKeyChecking=no root@$rpiip $image_reset_sh
else
	names=( '' partition reset image-create image-upload distcc-client docker )
	name=${names[$cmd]}
	(( $cmd < 5 )) && repo=rOS || repo=rern.github.io
	. <( curl -sL "https://github.com/rern/$repo/raw/main/$name.sh" )
fi
