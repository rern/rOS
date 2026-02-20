#!/bin/bash

. common.sh

[[ ! -e /usr/bin/gh ]] && error='github-cli : not yet installed\n'
! gh auth status &> /dev/null && error='gh auth : not yet set\n'
[[ $EUID == 0 ]] && error='su x : and run again\n'
[[ $error ]] && errorExit "$error"
#---------------------------------------------------------------
cd /home/x/BIG
imgfiles=( $( ls rAudio*.img.xz 2> /dev/null ) )
for file in "${imgfiles[@]}"; do
	filelist+=" $file on"
done
#........................
selectfiles=$( dialog "${optbox[@]}" --output-fd 1 --nocancel --no-items --checklist "
 \Z1Select files to upload:\Z0
" $(( ${#imgfiles[@]} + 5 )) 0 0 \
$filelist ) # rAudio-MODEL-YYYYMMDD.img.xz
mdl_rel=$( sed -E 's/rAudio-|.img.xz//g' <<< $selectfiles | tr ' ' '\n' )
mdl=$( cut -d- -f1 <<< $mdl_rel )
[[ $( echo $mdl ) != '32bit 64bit Legacy' ]] && error="Models not 3:\n$mdl\n"
release=$( cut -d- -f2 <<< $mdl_rel | sort -u )
(( $( wc -l <<< $release ) > 1 )) && error+="Releases not the same:\n$release\n"
[[ $error ]] && errorExit "$error"
#---------------------------------------------------------------
date_rel=${release:0:4}-${release:4:2}-${release: -2}
notes='
| Raspberry Pi | Image File | MD5 | Mirror |
|:-------------|:-----------|:----|:-------|'
clear -x
#........................
banner C h e c k s u m
for model in 64bit 32bit Legacy; do
	file=rAudio-$model-$release.img.xz
 	size_xz_img=$( xz -l --robot $file | awk '/^file/ {print $4" "$5}' )
	echo -e "$bar $file"
	printf 'md5sum \e[5m...\e[0m'
	md5=$( md5sum $file | cut -d' ' -f1 )
	printf "\rMD5     : $md5\n"
	printf 'sha256sum \e[5m...\e[0m'
	sha256=$( sha256sum $file | cut -d' ' -f1 )
	printf "\rSHA-256 : $sha256\n"
	image="[$file](https://github.com/rern/rAudio/releases/download/i$release/$file)"
	mirror="[< file](https://cloud.s-t-franz.de/s/kdFZXN9Na28nfD8/download?path=%2F&files=$file)"
	os_list+='
, {
  "devices": ['
	case $model in
		64bit )
			os_list+='
	  "pi5-64bit"
	, "pi4-64bit"
	, "pi3-64bit"
	, "pi2-64bit"
]
, "name": "rAudio '$model'"
, "description": "For: RPi 5, 4, 3, 2 (64bit), Zero 2"'
			notes+='
| `5` `4` `3` `2 (64bit)` `Zero2` '
			;;
		32bit )
			os_list+='
	  "pi3-32bit"
	, "pi2-32bit"
]
, "name": "rAudio '$model'"
, "description": "For: RPi 3, 2"'
			notes+='
| `3` `2` '
			;;
		Legacy )
			os_list+='
	  "pi1-32bit"
	, "pi0-32bit"
]
, "name": "rAudio '$model'"
, "description": "For: RPi 1, Zero"'
			notes+='
| `1` `Zero` '
			;;
	esac
	os_list+='
, "url": "https://github.com/rern/rAudio/releases/download/i'$release'/'$file'"
, "release_date": "'$date_rel'"
, "extract_size": '${size_xz_img/* }'
, "image_download_size": '${size_xz_img/ *}'
, "image_download_sha256": "'$sha256'"
, "icon": "https://raw.githubusercontent.com/rern/_assets/refs/heads/master/rpi-imager/icon'$model'.png"
, "website": "https://github.com/rern/rAudio"
}'
	notes+="| $image | $md5 | $mirror |"
done
#........................
banner U p l o a d
gh release create i$release --title i$release --notes "$notes" $selectfiles
[[ $? != 0 ]] && errorExit "Upload to GitHub FAILED!\n"
#---------------------------------------------------------------
cd /home/x/BIG/RPi/Git/rAudio
git switch main
git pull
echo '{
  "os_list" : [ '${os_list/,}' ]
, "imager"  : '$( jq .imager < rpi-imager.json )'
}' | jq > rpi-imager.json
git add rpi-imager.json
git commit -m "Update rpi-imager.json i$release"
git push
cd ..
#........................
dialog "${optbox[@]}" --infobox "

                    \Z1r\Z0Audio images

                Uploaded successfully
" 9 58
