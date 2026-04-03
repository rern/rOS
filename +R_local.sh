#!/bin/bash

BRANCH=${1:-main}
. <( curl -sL https://raw.githubusercontent.com/rern/rOS/$BRANCH/+R.sh )
#..........................................................
# chmod +x +R.sh
# echo 'export PATH="/root:$PATH"' >> .bashrc
#    restart terminal
# +R.sh
