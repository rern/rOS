#!/bin/bash

optbox=( --colors --no-shadow --no-collapse )

dialog "${optbox[@]}" --infobox "


                        \Z1r\Z0Audio
" 9 58
sleep 1

cmd=$( dialog "${optbox[@]}" --output-fd 1 --menu "
 \Z1r\Z0Audio image:
" 8 0 0 \
1 'Create' \
2 'Reset' \
3 'Image' \
4 'Write' )

url=https://github.com/rern/rOS/raw/main

case $cmd in
	1 ) bash <( wget -qO - $url/create.sh ) ;;
	2 ) bash <( wget -qO - $url/reset.sh ) ;;
	3 ) bash <( wget -qO - $url/imagecreate.sh ) ;;
	4 ) bash <( wget -qO - $url/imagewrite.sh ) ;;
esac
