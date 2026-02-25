#!/bin/bash

. common.sh

#........................
splash 'Reset for Image'
routerip=$( ip r get 1 | head -1 | cut -d' ' -f3 )
subip=${routerip%.*}.
#........................
rpiip=$( dialog $opt_input "
 \Z1Raspberry Pi IP:\Zn
" 0 0 $subip )
[[ ! $rpiip ]] && exit
#----------------------------------------------------------------------------
sed -i "/$rpiip/ d" ~/.ssh/known_hosts
sshpass -p ros ssh -t -o StrictHostKeyChecking=no root@$rpiip 'bash <( curl -sL https://github.com/rern/rOS/raw/main/image-reset.sh )'
