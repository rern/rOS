#!/bin/bash

optbox=( --colors --no-shadow --no-collapse )

dialog "${optbox[@]}" --infobox "


                        \Z1r\Z0Audio
" 9 58
sleep 1

cmd=$( dialog "${optbox[@]}" --output-fd 1 --menu "
 \Z1r\Z0Audio:
" 8 0 0 \
1 'Create' \
2 'Reset' \
3 'Image' \
4 'Write' \
5 'SSH' )

url=https://github.com/rern/rOS/raw/main

case $cmd in
	1 ) curl -sL $url/create.sh | sh;;
	2 ) curl -sL $url/reset.sh | sh;;
	3 ) curl -sL $url/imagecreate.sh | sh;;
	4 ) curl -sL $url/imagewrite.sh | sh;;
	5 ) rpiip=$( dialog "${opt[@]}" --output-fd 1 --inputbox "
 IP:
" 0 0 192.168.1. )
		pw=$( dialog "${opt[@]}" --output-fd 1 --inputbox "
 Password:
" 0 0 ros )
		sed -i "/$rpiip/ d" ~/.ssh/known_hosts
		sshpass -p "$pw" ssh -t -o StrictHostKeyChecking=no root@$rpiip
esac
