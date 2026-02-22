#!/bin/bash

# repo path: BIG/RPi/Git/rAudio
. common.sh

uploadImage() {
#........................
	banner U p l o a d
	echo -e "$bar *.img.xz"
	gh release create i$release --title i$release --notes "$notes" $img_files
	[[ $? != 0 ]] && echo "$notes" > notes && errorExit Upload to GitHub failed
#---------------------------------------------------------------
	fi
	rm -f notes
	echo -e "
rAudio images uploaded successfully
\e[44m rpi-imager.json \e[0m must be pushed to main branch"
}

cd BIG
if [[ -e notes ]]; then # from failed upload
	echo -e "\n$bar Re-upload\n"
	notes=$( < notes )
	release=$( jq -r .os_list[0].release_date <<< $json | tr -d - )
	img_files=$( ls rAudio-*$release.img.xz )
	uploadImage
	exit
#---------------------------------------------------------------
fi
files=( $( ls rAudio*.img.xz 2> /dev/null ) )
for f in $files; do
	filelist+=" $f on"
done
#........................
img_files=$( dialog $opt_check --no-items "
 \Z1Select files to upload:\Z0
" $(( ${#files[@]} + 5 )) 0 0 \
$filelist ) # rAudio-MODEL-YYYYMMDD.img.xz
mdl_rel=$( sed -E 's/rAudio-|.img.xz//g' <<< $img_files | tr ' ' '\n' )
mdl=$( cut -d- -f1 <<< $mdl_rel )
[[ $( echo $mdl ) != '32bit 64bit Legacy' ]] && error="Not all models:\n$mdl\n"
release=$( cut -d- -f2 <<< $mdl_rel | sort -u )
(( $( wc -l <<< $release ) > 1 )) && error+="Releases not the same:\n$release\n"
[[ $error ]] && errorExit "$error"
#---------------------------------------------------------------
date_rel=${release:0:4}-${release:4:2}-${release: -2}
json=$( sed -E -e "s|i[0-9]*/(rAudio.*-).*(.img.xz)|i$release/\1$release\2|
" -e 's/(release_date": ").*/\1'$date_rel'",/
' rpi-imager.json )
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
echo "$json" > RPi/Git/rAudio/rpi-imager.json
uploadImage
