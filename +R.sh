#!/bin/bash


. <( curl -sL https://raw.githubusercontent.com/rern/rOS/$BRANCH/common.sh )

#............................
dialog.splash U t i l i t i e s
list="\
Create OS       : create
Reset for Image :
Create Image    : image-create
Upload Images   : image-upload
Distcc Client   : distcc-client
Docker          : docker
Repo Update     : repoupdate
Get Content     :
SSH             :"
list_task=$( awk -F' *:' '{print $1}' <<< $list )
#............................
i=$( dialog.menu Tasks "$list_task" )
file_name=$( sed -n "$i {s/.*: *//; p}" <<< $list )
if [[ $file_name ]]; then
	(( $i < 5 )) && repo=rOS || repo=rern.github.io
	[[ $BRANCH != main ]] && arg_branch=$BRANCH
	bash <( curl -sL "$https_rern/$repo/$BRANCH/$file_name.sh" ) $arg_branch
else
	title=$( sed -n "$i {s/ .*//; p}" <<< $list )
	if [[ $title == Get ]]; then
		url=$( dialog.input 'URL:' rOS/$BRANCH/create.sh )
		line=$( dialog.input 'Line 0 to:' )
		line=${line:-1000}
		banner $https_rern/$url
		cmd="curl -sL $https_rern/$url | head -$line | cat -n"
		eval $cmd
		echo "
$cmd"
	else
#............................
		ip=$( dialog.ip 'rAudio IP' )
		[[ $title == Reset ]] && bash_reset_sh="bash <( curl -sL $https_ros_branch/image-reset.sh )"
		sshpass -p ros \
			ssh $opt_ssh root@$ip $bash_reset_sh
	fi
fi
