#!/bin/bash

. <( curl -sL https://github.com/rern/rOS/raw/main/common.sh )
#........................
dialogSplash 'Image Utilities'
#........................
cmd=$( dialog $opt_menu '
\Z1Tasks:\Zn
' 8 0 0 \
	1 'OS - Create' \
	2 'OS - Reset for image' \
	3 'Image - Create' \
	4 'Images - Upload' \
	5 'Distcc client' \
	6 'Docker' \
	7 'SSH to RPi' )
if [[ $cmd == 7 ]]; then
#........................
	rpiip=$( dialog $opt_input '
 IP:
' 0 0 192.168.1. )
	sed -i "/$rpiip/ d" ~/.ssh/known_hosts
	sshpass -p ros ssh -t -o StrictHostKeyChecking=no root@$rpiip
	exit
#----------------------------------------------------------------------------
fi
names=( '' partition reset image-create image-upload distcc-client docker )
name=${names[$cmd]}
(( $cmd < 5 )) && repo=rOS || repo=rern.github.io
. <( curl -sL "https://github.com/rern/$repo/raw/main/$name.sh" )
