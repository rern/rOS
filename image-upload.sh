#!/bin/bash

# *.img.xz - current dir
# repo     - /dev/sd?1 BIG: /RPi/Git/rAudio

trap cleanup EXIT SIGINT

cleanup() {
	kill -TERM -$$ &> /dev/null
	cd $dir_base
	umount -l BIG
	rmdir BIG
	rm rAudio
}

dir_base=$PWD
imager_json=rpi-imager.json

if [[ ! -e /bin/gh ]]; then
	pacman -Sy --noconfirm github-cli
	dialog.error_exit Setup Github CLI: https://github.com/rern/rOS/blob/main/image_github_setup.md
#------------------------------------------------------------------------------
fi
file_img=$( ls rAudio*.img.xz )
[[ ! $file_img ]] && dialog.error_exit "No image files in current: \Z1$dir_base\Zn"
#------------------------------------------------------------------------------
#............................
dialog.splash Upload Image Files
dev=$( lsblk -no path,label | awk '/BIG/ {print $1}' )
[[ ! $dev ]] && dialog.error_exit "\Z1BIG\Zn not found."
#------------------------------------------------------------------------------
umount -l BIG 2> /dev/null
! ntfsinfo -m $dev &> /dev/null && dialog.error_exit "\Z1$dev\Zn is hibernated."
#------------------------------------------------------------------------------
#............................
dialog ${opt_info/--sleep 2} "
  Mount ...
  \Z1rAudio\Zn GitHub directory
" 9 $W
mkdir -p BIG
mount $dev BIG || dialog.error_exit "\Z1BIG\Zn mount failed."
#------------------------------------------------------------------------------
ln -sf {BIG/RPi/Git/,}rAudio
[[ ! -e rAudio/$imager_json ]] && dialog.error_exit "\Z1$imager_json\Zn not found."
#------------------------------------------------------------------------------
#............................
dialog $opt_yesno "
\Z1Images to upload:\Zn
$file_img
" 0 0 || exit
#------------------------------------------------------------------------------
models=$( awk -F'[-.]' '{printf "%s ", $2}' <<< $file_img ) # rAudio-MODEL-YYYYMMDD.img.xz
[[ $models != '32bit 64bit Legacy ' ]] && error="Not all 3 models:\n$models\n"
release=$( awk -F'[-.]' '{print $3}' <<< $file_img | sort -u )
(( $( wc -l <<< $release ) > 1 )) && error+="Releases not the same:\n$release\n"
[[ $error ]] && dialog.error_exit "$error"
#------------------------------------------------------------------------------
cd rAudio
if git show-ref --tags | grep -q -m1 i$release$; then
	dialog $opt_yesno "
 Delete exisiting local tag:
 \Z1i$release\Zn
" 0 0 && git tag -d i$release || exit
#------------------------------------------------------------------------------
fi
if [[ $( git ls-remote --tags origin i$release ) ]]; then
	dialog $opt_yesno "
 Delete exisiting remote tag:
 \Z1i$release\Zn
" 0 0 && git push --delete origin i$release || exit
#------------------------------------------------------------------------------
fi
date_rel=${release:0:4}-${release:4:2}-${release: -2}
json=$( sed -E -e "s|i[0-9]{8}/(rAudio.*-).*(.img.xz)|i$release/\1$release\2|
" -e 's/(release_date": ").*/\1'$date_rel'",/
' $imager_json )
notes='
| Raspberry Pi | Image File | Mirror |
|:-------------|:-----------|:-------|'
declare -A model_rpi=(
	[64bit]='`5` `4` `3` `2 (64bit)` `Zero2`'
	[32bit]='`3` `2`'
	[Legacy]='`1` `Zero`' )
os_name=$( jq '.os_list | map(.name)' <<< $json )
cd ..
#............................
banner S H A - 2 5 6
for file in $file_img; do
 	read size_img size_xz < <( xz -l --robot $file | awk '/^file/ {print $4, $5}' )
	bar $file
	printf 'sha256sum \e[5m...\e[0m'
	sha256=$( sha256sum $file | cut -d' ' -f1 )
	printf "\r$sha256\n"
	model=$( cut -d- -f2 <<< $file )
	i=$( jq 'index("rAudio '$model'")' <<< $os_name )
	os_i=os_list[$i]
	json=$( jq   ".os_i.extract_size = $size_img
				| .os_i.image_download_size = $size_xz
				| .os_i.image_download_sha256 = \"$sha256\"" <<< $json )
	notes+="
| ${model_rpi[$model]} \
| [$file]($https_raudio/releases/download/i$release/$file) \
| [< file](https://cloud.s-t-franz.de/public.php/dav/files/kdFZXN9Na28nfD8/$file) |"
done
#............................
banner U p l o a d
bar "Image files:
$file_img
"
cd rAudio
file_path=$( sed "s|^|$dir_base/|" <<< $file_img )
gh release create i$release --latest=false --title i$release --notes "$notes" $file_path
[[ $? != 0 ]] && dialog.error_exit Upload failed.
#------------------------------------------------------------------------------
br_current=$( git branch --show-current )
[[ $br_current == main ]] && br=1 || br=2
#............................
select=$( dialog --default-item $br $opt_menu "
Branch for $imager_json
" 8 0 0 1 main 2 UPDATE )
if [[ $select != $br ]]; then
	[[ $select == 1 ]] && branch=main || branch=UPDATE
	git diff-index --quiet HEAD && git commit -m U
	git switch $branch
fi
git pull
echo "$json" > $imager_json
git add $imager_json
git commit -m $imager_json
git push
[[ $? != 0 ]] && dialog.error_exit "Push \Z1$imager_json\Zn failed."
#------------------------------------------------------------------------------
text="\
 $logo

 \Z1Image files\Zn     : Uploaded successfully.
 \Z1$imager_json\Zn : Updated and pushed"
[[ $branch != main ]] && text+=" to \Z1$branch\Zn
                   \Z4(Must be merged manually)\Zn"
dialog.info "$text"
