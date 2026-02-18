#!/bin/bash

errorExit() {
	echo -e "\n\e[41m ! \e[0m $error"
	exit
}

[[ ! -e /usr/bin/gh ]] && error='Package github-cli not yet installed.\n'
[[ $EUID == 0 ]] && error='su x and run again.\n'
[[ $error ]] && errorExit "$error"
#---------------------------------------------------------------
[[ ! -d /home/x/rAudio ]] && git clone https://github.com/rern/rAudio/

cd /home/x/rAudio

! gh auth status &> /dev/null && gh auth login -p ssh -w

rm -f rAudio*.xz
ln -s ../BIG/rAudio*.xz .

optbox=( --colors --no-shadow --no-collapse )
imgfiles=( $( ls rAudio*.img.xz 2> /dev/null ) )
for file in "${imgfiles[@]}"; do
	filelist+=" $file on"
done

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
echo Checksum:
for model in 64bit 32bit Legacy; do
	file=rAudio-$model-$release.img.xz
 	size_xz_img=$( xz -l --robot $file | awk '/^file/ {print $4" "$5}' )
	echo $file ...
	md5=$( md5sum $file | cut -d' ' -f1 )
	sha256=$( sha256sum $file | cut -d' ' -f1 )
	image="[$file](https://github.com/rern/rAudio/releases/download/i$release/$file)"
	mirror="[< file](https://cloud.s-t-franz.de/s/kdFZXN9Na28nfD8/download?path=%2F&files=$file)"
	os_list+=',
{
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
echo -e "\nUpload rAudio Image Files: i$release ...\n"
gh release create i$release --title i$release --notes "$notes" $selectfiles
[[ $? != 0 ]] && exitError "Upload to GitHub FAILED!\n"
#---------------------------------------------------------------
rm rAudio*.xz
git pull
echo '{
  "os_list" : [ '${os_list:1}' ]
, "imager"  : '$( jq .imager < rpi-imager.json )'
}' | jq > rpi-imager.json
git add rpi-imager.json
git commit -m "Update rpi-imager.json i$release"
git push

