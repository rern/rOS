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
	1 ) bash <( curl -L $url/create.sh );;
	2 ) bash <( curl -L $url/reset.sh );;
	3 ) bash <( curl -L $url/imagecreate.sh );;
	4 ) bash <( curl -L $url/imagewrite.sh );;
	5 ) rpiip=$( dialog "${opt[@]}" --output-fd 1 --inputbox "
 IP:
" 0 0 192.168.1. )
		pw=$( dialog "${opt[@]}" --output-fd 1 --inputbox "
 Password:
" 0 0 ros )
		sed -i "/$rpiip/ d" ~/.ssh/known_hosts
		sshpass -p "$pw" ssh -t -o StrictHostKeyChecking=no root@$rpiip
esac
