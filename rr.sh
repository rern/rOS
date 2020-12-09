#!/bin/bash

optbox=( --colors --no-shadow --no-collapse )

dialog "${optbox[@]}" --infobox "


                         \Z1rOS\Z0
" 9 58
sleep 1

cmd=$( dialog "${optbox[@]}" --output-fd 1 --menu "
\Z1rOS:\Z0
" 8 0 0 \
1 'Create' \
2 'Reset' \
3 'Image' )

case $cmd in

1 )
	bash <( wget -qO - https://github.com/rern/rOS/raw/master/create.sh )
	;;
2 )
	bash <( wget -qO - https://github.com/rern/rOS/raw/master/reset.sh )
	;;
3 )
	bash <( wget -qO - https://github.com/rern/rOS/raw/master/imagecreate.sh )
	;;

esac
