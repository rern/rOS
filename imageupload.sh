#!/bin/bash

. common.sh

dir_img=/root/BIG
dir_raudio=$dir_img/RPi/Git/rAudio
file_json=$dir_raudio/rpi-imager.json

uploadImage() {
#........................
	banner U p l o a d
	echo -e "$bar *.img.xz"
	cd $dir_raudio
	gh release create i$release --latest=false --title i$release --notes "$notes" $files_path
	if [[ $? != 0 ]]; then
		dialog $opt_yesno "
Upload \Z1failed\Z0.

Retry?

" 0 0 && uploadImage
	else
		echo -e "
rAudio images uploaded successfully
\e[44m rpi-imager.json \e[0m must be pushed to main branch"
	fi
}

cd $dir_img
files_list=$( ls rAudio*.img.xz  | sed 's/$/ on/' )
#........................
files_img=$( dialog $opt_outfd --no-items --checklist "
 \Z1Select files to upload:\Z0
" 9 0 0 \
$files_list ) # rAudio-MODEL-YYYYMMDD.img.xz
mdl_rel=$( sed -E 's/rAudio-|.img.xz//g' <<< $files_img | tr ' ' '\n' )
mdl=$( cut -d- -f1 <<< $mdl_rel )
[[ $( echo $mdl ) != '32bit 64bit Legacy' ]] && error="Not all models:\n$mdl\n"
release=$( cut -d- -f2 <<< $mdl_rel | sort -u )
(( $( wc -l <<< $release ) > 1 )) && error+="Releases not the same:\n$release\n"
[[ $error ]] && errorExit "$error"
#---------------------------------------------------------------
date_rel=${release:0:4}-${release:4:2}-${release: -2}
json=$( sed -E -e "s|i[0-9]*/(rAudio.*-).*(.img.xz)|i$release/\1$release\2|
" -e 's/(release_date": ").*/\1'$date_rel'",/
' $file_json )
models=$( jq -r .os_list[].name <<< $json | cut -d' ' -f2 )
i=0
notes='
| Raspberry Pi | Image File | Mirror |
|:-------------|:-----------|:-------|'
declare -A mdl_rpi=(
	[64bit]='`5` `4` `3` `2 (64bit)` `Zero2`'
	[32bit]='`3` `2`'
	[Legacy]='`1` `Zero`' )
clear -x
#........................
banner C h e c k s u m
for model in $models; do
	file=rAudio-$model-$release.img.xz
 	size_xz_img=$( xz -l --robot $file | awk '/^file/ {print $4" "$5}' )
	echo -e "$bar $file"
	printf 'sha256sum \e[5m...\e[0m'
	sha256=$( sha256sum $file | cut -d' ' -f1 )
	printf "\rSHA-256 : $sha256\n"
	osi=os_list[$i]
	json=$( jq ".$osi.extract_size = ${size_xz_img/* }
				| .$osi.image_download_size = ${size_xz_img/ *}
				| .$osi.image_download_sha256 = \"$sha256\"" <<< $json )
	(( i++ ))
	notes+="
| ${mdl_rpi[$model]} \
| [$file](https://github.com/rern/rAudio/releases/download/i$release/$file) \
| [< file](https://cloud.s-t-franz.de/s/kdFZXN9Na28nfD8/download?path=%2F&files=$file) |"
done
echo "$json" > $file_json
files_path=$( tr ' ' '\n' <<< $files_img | sed "s|^|$dir_img|" )
uploadImage
