#!/bin/bash

optbox=( --colors --no-shadow --no-collapse )

dialog "${optbox[@]}" --infobox "


                        \Z1r\Z0Audio
" 9 58
sleep 1

cmd=$( dialog "${optbox[@]}" --output-fd 1 --menu "
 \Z1r\Z0Audio:
" 8 0 0 \
1 'Create rAudio' \
2 'Reset to default' \
3 'Compress to image file' \
4 'Upload image files' \
5 'Distcc client' \
6 'Docker' \
7 'SSH to RPi' )

url=https://github.com/rern/rOS/raw/main

case $cmd in
	1 ) bash <( curl -sL $url/create.sh );;
	2 ) bash <( curl -sL $url/reset.sh );;
	3 ) bash <( curl -sL $url/imagecreate.sh );;
	4 ) bash <( curl -sL $url/imageupload.sh );;
	5 ) bash <( curl -sL https://github.com/rern/rern.github.io/raw/main/distcc-client.sh );;
	6 ) bash <( curl -sL https://github.com/rern/rern.github.io/raw/main/docker.sh );;
	7 ) rpiip=$( dialog "${opt[@]}" --output-fd 1 --inputbox "
 IP:
" 0 0 192.168.1. )
	sed -i "/$rpiip/ d" ~/.ssh/known_hosts
	sshpass -p ros ssh -t -o StrictHostKeyChecking=no root@$rpiip
	;;
esac
