#!/bin/bash

[[ $1 ]] && branch=UPDATE || branch=main
. <( curl -sL https://github.com/rern/rOS/raw/$branch/+R.sh )
#..........................................................
# chmod +x +R.sh
# echo 'export PATH="/root:$PATH"' >> .bashrc
#    restart terminal
# +R.sh
