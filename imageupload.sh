#!/bin/bash
[[ ! -e /usr/bin/gh ]] && echo -e "\nPackage github-cli not yet installed.\n" && exit
#---------------------------------------------------------------
[[ $EUID == 0 ]] && echo -e "\nsu x and run again.\n" && exit
#---------------------------------------------------------------
[[ ! -d /home/x/rAudio ]] && git clone https://github.com/rern/rAudio/

cd /home/x/rAudio

! gh auth status &> /dev/null && gh auth login -p ssh -w

rm /home/x/rAudio/rAudio*.xz
ln -s ../BIG/rAudio*.xz .

optbox=( --colors --no-shadow --no-collapse )
imgfiles=( $( ls rAudio*.img.xz 2> /dev/null ) )
for file in "${imgfiles[@]}"; do
	filelist+=" $file on"
done

selectfiles=$( dialog "${optbox[@]}" --output-fd 1 --nocancel --no-items --checklist "
 \Z1Select files to upload:\Z0
" $(( ${#imgfiles[@]} + 3 )) 0 0 \
$filelist )
models=$( tr ' ' '\n' <<< $selectfiles | cut -d- -f2 )
[[ $models != '64bit RPi0 RPi2' ]] && echo -e "\nImages missing - selected: $models\n" && exit
#---------------------------------------------------------------
for file in $selectfiles; do # rAudio-MODEL-RELEASE.img.xz
	m_r=${file:7:-7}
	model=${m_r/*-}   # 64bit RPi2 RPi0-1
	release=${m_r/-*} # YYYYMMDD
 	echo "SHA256 *.xz: sha256sum $file ..."
	sha256_xz=$( sha256sum $file | cut -d' ' -f1 )
	echo "SHA256 *.img: xz -dc $file | sha256sum ..."
	sha256_img=$( xz -dc $file | sha256sum | cut -d' ' -f1 )
 	image_sha256_mirror+=( "[$file](https://github.com/rern/rAudio/releases/download/i$release/$file) \
  					  			| $sha256 \
		                    	| [< file](https://cloud.s-t-franz.de/s/kdFZXN9Na28nfD8/download?path=%2F&files=$file)" )
	list+=',
{
	"devices": ['
	case $model in
		64bit )
			list=$( sed '/-32bit/ d' <<< $common_list )
			list+='
		"pi5-64bit",
		"pi4-64bit",
		"pi3-64bit",
		"pi2-64bit"
	],
	"name": "rAudio 64bit",
	"description": "For: RPi 5, 4, 3, 2 (BCM2837), Zero 2",'
			;;
		RPi2 )
			list+='
		"pi3-32bit",
		"pi2-32bit"
	],
	"name": "rAudio 32bit",
	"description": "For: RPi 3, 2",'
			;;
		* )
			list+='
		"pi1-32bit",
		"pi0-32bit"
	],
	"name": "rAudio Legacy",
	"description": "For: RPi 1, Zero",'
			;;
	esac
	list+='
	"url": "https://github.com/rern/rAudio/releases/download/i'$release'/'$file'",
	"release_date": "'${release:0:4}-${release:5:2}-${release: -2}'",
	"extract_size": '$( stat --printf="%s" ${file:0:-3} )',
	"extract_sha256": "'$sha256_img'",
	"image_download_size": '$( stat --printf="%s" $file )',
	"image_download_sha256": "'$sha256_xz',"
	"icon": "https://github.com/rern/rAudio/raw/refs/heads/main/srv/http/assets/img/icon.png",
	"website": "https://github.com/rern/rAudio"
}'
done
notes='
| Raspberry Pi                      | Image File | SHA256 | Mirror |
|:----------------------------------|:-----------|:-------|:-------|
| `5` `4` `3` `2 (BCM2837)` `Zero2` | '${image_sha256_mirror[0]}'  |
| `3` `2`                           | '${image_sha256_mirror[1]}'  |
| `1` `Zero`                        | '${image_sha256_mirror[2]}'  |
'
echo -e "\nUpload rAudio Image Files: i$release ...\n"

gh release create i$release --title i$release --notes "$notes" $selectfiles
if [[ $? != 0 ]]; then
	echo -e "\nUpload FAILED!\n"
	exit
#---------------------------------------------------------------
fi
echo '{ "os_list": [ '${list:1}' ] }' | jq > rpi-imager.json
git add rpi-imager.json
git commit -m 'Update rpi-imager.json'
git push
