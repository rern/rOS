#!/bin/bash

[[ $1 ]] && branch=$1 || branch=main
. <( curl -sL https://raw.githubusercontent.com/rern/rOS/$branch/+R.sh )
#..........................................................
# chmod +x +R.sh
# echo 'export PATH="/root:$PATH"' >> .bashrc
#    restart terminal
# +R.sh
