#!/bin/bash

trap trapExit EXIT SIGINT

trapExit() {
	umount -l BIG
	rmdir BIG
	rm rAudio
}

if [[ ! -e /bin/gh ]]; then
	pacman -Sy --noconfirm github-cli
	dialog.error_exit Setup Github CLI: https://github.com/rern/rOS/blob/main/image_github_setup.md
#------------------------------------------------------------------------------
fi
# default images path: /root/rAudio-*.img.xz
files_list=$( ls rAudio*.img.xz  | sed 's/$/ on/' )
[[ ! $files_list ]] && dialog.error_exit "No image files in current: \Z1$PWD\Zn"
#------------------------------------------------------------------------------
dialog.splash Upload Image Files
bar Mount rAudio directory ...
dev=$( lsblk -no path,label | awk '/BIG/ {print $1}' )
mkdir -p BIG
mount $dev BIG
[[ $? != 0 ]] && dialog.error_exit "\Z1BIG\Zn mount failed."
#------------------------------------------------------------------------------
ln -s {BIG/RPi/Git/,}rAudio
imager_json=rpi-imager.json
[[ ! -e rAudio/$imager_json ]] && dialog.error_exit "\Z1$imager_json\Zn not found."
#------------------------------------------------------------------------------
#............................
files_img=$( dialog $opt_check '
 \Z1Images to upload:\Zn
' 8 0 0 \
	$files_list ) # rAudio-MODEL-YYYYMMDD.img.xz
mdl_rel=$( sed -E 's/rAudio-|.img.xz//g' <<< $files_img )
mdl=$( cut -d- -f1 <<< $mdl_rel )
[[ $( echo $mdl ) != '32bit 64bit Legacy' ]] && error="Not all 3 models:\n$mdl\n"
release=$( cut -d- -f2 <<< $mdl_rel | sort -u )
(( $( wc -l <<< $release ) > 1 )) && error+="Releases not the same:\n$release\n"
[[ $error ]] && dialog.error_exit "$error"
#------------------------------------------------------------------------------
date_rel=${release:0:4}-${release:4:2}-${release: -2}
json=$( sed -E -e "s|i[0-9]{8}/(rAudio.*-).*(.img.xz)|i$release/\1$release\2|
" -e 's/(release_date": ").*/\1'$date_rel'",/
' rAudio/$imager_json )
models=$( jq -r .os_list[].name <<< $json | cut -d' ' -f2 )
i=0
notes='
| Raspberry Pi | Image File | Mirror |
|:-------------|:-----------|:-------|'
declare -A mdl_rpi=(
	[64bit]='`5` `4` `3` `2 (64bit)` `Zero2`'
	[32bit]='`3` `2`'
	[Legacy]='`1` `Zero`' )
#............................
banner S H A - 2 5 6
for model in $models; do
	file=rAudio-$model-$release.img.xz
 	size_xz_img=$( xz -l --robot $file | awk '/^file/ {print $4" "$5}' )
	bar $file
	printf 'sha256sum \e[5m...\e[0m'
	sha256=$( sha256sum $file | cut -d' ' -f1 )
	printf "\r$sha256\n"
	osi=os_list[$i]
	json=$( jq ".$osi.extract_size = ${size_xz_img/* }
				| .$osi.image_download_size = ${size_xz_img/ *}
				| .$osi.image_download_sha256 = \"$sha256\"" <<< $json )
	(( i++ ))
	notes+="
| ${mdl_rpi[$model]} \
| [$file]($https_raudio/releases/download/i$release/$file) \
| [< file](https://cloud.s-t-franz.de/public.php/dav/files/kdFZXN9Na28nfD8/$file) |"
done
#............................
banner U p l o a d
bar *.img.xz
files_img=$( sed "s|^|$PWD/|" <<< $files_img )
cd rAudio
gh release create i$release --latest=false --title i$release --notes "$notes" $files_img
[[ $? != 0 ]] && dialog.error_exit Upload failed.
#------------------------------------------------------------------------------
branch=$( git branch --show-current )
if [[ $branch != main ]]; then
	git diff-index --quiet HEAD && git commit -m U
	git switch main
fi
echo "$json" > $imager_json
git add $imager_json
git commit -m u
git push
trapExit
bar Image files uploaded successfully.
