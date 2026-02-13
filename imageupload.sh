#!/bin/bash
[[ ! -e /usr/bin/gh ]] && echo -e "\nPackage github-cli not yet installed.\n" && exit
#---------------------------------------------------------------
[[ $EUID == 0 ]] && echo -e "\nsu x and run again.\n" && exit
#---------------------------------------------------------------
mib2b() {
	bc <<< "scale=0; $1*1048576/1"
}

[[ ! -d /home/x/rAudio ]] && git clone https://github.com/rern/rAudio/

cd /home/x/rAudio

! gh auth status &> /dev/null && gh auth login -p ssh -w

rm -f rAudio*img.xz
ln -s ../BIG/*.xz .

optbox=( --colors --no-shadow --no-collapse )
imgfiles=( $( ls rAudio*.img.xz 2> /dev/null ) )
for file in "${imgfiles[@]}"; do
	filelist+=" $file on"
done

selectfiles=$( dialog "${optbox[@]}" --output-fd 1 --nocancel --no-items --checklist "
 \Z1Select files to upload:\Z0
 $imgdir" $(( ${#imgfiles[@]} + 6 )) 0 0 \
$filelist )
files=( $selectfiles )
(( ${#files[@]} != 3 )) && echo 'Image files count not 3.' && exit
#---------------------------------------------------------------
file0=${files[0]}
dir=$( dirname $file0 )
release=$( echo ${file0/*-} | cut -d. -f1 )
common_list=',
{
	"devices": [
		"pi5-64bit",
		"pi4-64bit",
		"pi3-64bit",
		"pi2-64bit"
		"pi3-32bit",
		"pi2-32bit"
		"pi1-32bit",
		"pi0-32bit"
	],
	"name": "rAudio MODEL",
	"description": "Raspberry Pi audio player",
	"icon": "https://github.com/rern/rAudio/raw/refs/heads/main/srv/http/assets/img/icon.png",
	"website": "https://github.com/rern/rAudio",
	"url": "https://github.com/rern/rAudio/releases/download/iRELEASE/rAudio-MODEL-RELEASE.img.xz",'
for model in 64bit RPi2 RPi0-1; do
	file=rAudio-$model-$release.img.xz
 	echo "SHA256 $file ..."
	sha256=$( sha256sum $file | cut -d' ' -f1 )
	size=( $( xz -l $file | tail -1 | awk '{print $3" "$5}' | tr -d ',' ) )
 	image_md5_mirror+=( "[$file](https://github.com/rern/rAudio/releases/download/i$release/$file) \
  					   | $sha256 \
                       | [< file](https://cloud.s-t-franz.de/s/kdFZXN9Na28nfD8/download?path=%2F&files=$file)" )
	if [[ $model == 64bit ]]; then
		list=$( sed '/-32bit/ d' <<< $common_list )
	elif [[ $model == RPi2 ]]; then
		list=$( sed -E '/-64bit|pi1-|pi0-/ d' <<< $common_list )
	else
		list=$( sed -E '/-64bit|pi3-|pi2-/ d' <<< $common_list )
	fi
	os_list+=$( sed 's|MODEL|'$model'|g; s|RELEASE|'$release'|g' <<< $list )
	os_list+='
	"release_date": "'${release:0:4}-${release:5:2}-${release: -2}'",
	"extract_size": '$( mib2b ${size[1]} )',
	"extract_sha256": "'$sha256'",
	"image_download_size": '$( mib2b ${size[0]} )',
	"image_download_sha256": "'$sha256'"
}'
done
notes='
| Raspberry Pi                      | Image File | SHA256 | Mirror |
|:----------------------------------|:-----------|:-------|:-------|
| `5` `4` `3` `2 (BCM2837)` `Zero2` | '${image_sha256_mirror[0]}'  |
| `3` `2`                           | '${image_sha256_mirror[1]}'  |
| `1` `Zero`                        | '${image_sha256_mirror[2]}'  |
'
echo '{ "os_list": [ '${os_list:1}' ] }' | jq > rpi-imager.json
echo -e "\nUpload rAudio Image Files: i$release ...\n"

gh release create i$release --title i$release --notes "$notes" $selectfiles
