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
[[ $models != '64bit RPi0-1 RPi2' ]] && echo -e "\nImages missing - selected: $models\n" && exit
#---------------------------------------------------------------
notes='
| Raspberry Pi | Image File | SHA256 | Mirror |
|:-------------|:-----------|:-------|:-------|'
for file in $selectfiles; do # rAudio-MODEL-RELEASE.img.xz
	m_r=${file:7:-7}
	model=${m_r/*-}   # 64bit RPi2 RPi0-1
	release=${m_r/-*} # YYYYMMDD
	date_rel=${release:0:4}-${release:5:2}-${release: -2}
	mib=$( xz -l $file | tail -1 | awk '{print $5}' | tr -d , )
	size_img=$( bc <<< "scale=0; $mib*1048576/1" )
	size_xz=$( stat -L --printf="%s" $file )
 	echo "SHA256 *.xz: sha256sum $file ..."
	sha256_xz=$( sha256sum $file | cut -d' ' -f1 )
	echo "SHA256 *.img: xz -dc $file | sha256sum ..."
	sha256_img=$( xz -dc $file | sha256sum | cut -d' ' -f1 )
	img="[$file](https://github.com/rern/rAudio/releases/download/i$release/$file)"
	mirror="[< file](https://cloud.s-t-franz.de/s/kdFZXN9Na28nfD8/download?path=%2F&files=$file)"
	image_sha256_mirror="$img | $sha256 | $mirror"
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
			notes+='
| `5` `4` `3` `2 (BCM2837)` `Zero2` | '$image_sha256_mirror'  |'
			;;
		RPi2 )
			list+='
		"pi3-32bit",
		"pi2-32bit"
	],
	"name": "rAudio 32bit",
	"description": "For: RPi 3, 2",'
			notes+='
| `3` `2` | '$image_sha256_mirror'  |'
			;;
		* )
			list+='
		"pi1-32bit",
		"pi0-32bit"
	],
	"name": "rAudio Legacy",
	"description": "For: RPi 1, Zero",'
			notes+='
| `1` `Zero` | '$image_sha256_mirror'  |'
			;;
	esac
	list+='
	"url": "https://github.com/rern/rAudio/releases/download/i'$release'/'$file'",
	"release_date": "'$date_rel'",
	"extract_size": '$size_img',
	"extract_sha256": "'$sha256_img'",
	"image_download_size": '$size_xz',
	"image_download_sha256": "'$sha256_xz'",
	"icon": "https://github.com/rern/rAudio/raw/refs/heads/main/srv/http/assets/img/icon.png",
	"website": "https://github.com/rern/rAudio"
}'
done
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
