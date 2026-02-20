#!/bin/bash

. common.sh

#........................
dialog "${optbox[@]}" --infobox "

                       \Z1r\Z0Audio

                 \Z1Reset\Z0 for Image File
" 9 58
sleep 2
routerip=$( ip r get 1 | head -1 | cut -d' ' -f3 )
subip=${routerip%.*}.
#........................
rpiip=$( dialog "${optbox[@]}" --output-fd 1 --inputbox "
 \Z1Raspberry Pi IP:\Z0
" 0 0 $subip )
sed -i "/$rpiip/ d" ~/.ssh/known_hosts
sshpass -p ros ssh -t -o StrictHostKeyChecking=no root@$rpiip 'bash <( curl -sL https://github.com/rern/rOS/raw/main/imagereset.sh )'
