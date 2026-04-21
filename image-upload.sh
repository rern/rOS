#!/bin/bash

# *.img.xz - current dir
# repo     - /dev/sd?1 BIG: /RPi/Git/rAudio
disk_label=BIG
dir_base=$PWD
imager_json=rpi-imager.json

trap cleanup EXIT SIGINT

cleanup() {
	kill -TERM -$$ &> /dev/null
	cd $dir_base
	umount -l $disk_label
	rmdir $disk_label
	rm rAudio
}

#............................
dialog.splash Upload Image Files
if [[ ! -e /bin/gh ]]; then
	pacman -Sy --noconfirm github-cli
	error+='Setup Github CLI: https://github.com/rern/rOS/blob/main/image_github_setup.md'
fi
file_img=$( ls rAudio*.img.xz )
[[ ! $file_img ]] && error+=$'\n'"No image files in current: $dir_base"
dev=$( lsblk -no path,label | awk '/'$disk_label'/ {print $1}' )
if [[ $dev ]]; then
	! ntfs-3g.probe --readonly $dev && error+="$disk_label is hibernated."
else
	error+=$'\n'"$disk_label not found."
fi
if [[ $error ]]; then
	if (( $( grep -c hibernate <<< $error ) == 1 )); then
		dialog $opt_yesno "
 $disk_label is \Z1hibernated\Zn.
 Remove?
" 0 0 || exit
#------------------------------------------------------------------------------
		opt_mount='-t ntfs-3g -o remove_hiberfile'
	else
		echo -e "\
\e[41m i \e[0m Errors:
$error"
		exit
#------------------------------------------------------------------------------
	fi
fi
#............................
dialog ${opt_info/--sleep 2} "
  Mount ...
  \Z1rAudio\Zn GitHub directory
" 9 $W
umount -l $disk_label 2> /dev/null
mkdir -p $disk_label
mount $opt_mount $dev $disk_label || dialog.error_exit "\Z1$disk_label\Zn mount failed."
#------------------------------------------------------------------------------
ln -sf {$disk_label/RPi/Git/,}rAudio
models=$( awk -F'[-.]' '{printf "%s ", $2}' <<< $file_img ) # rAudio-MODEL-YYYYMMDD.img.xz
[[ $models != '32bit 64bit Legacy ' ]] && error="Not all 3 models:\n$models\n"
release=$( awk -F'[-.]' '{print $3}' <<< $file_img | sort -u )
(( $( wc -l <<< $release ) > 1 )) && error+="Releases not the same:\n$release\n"
[[ $error ]] && dialog.error_exit "$error"
#------------------------------------------------------------------------------
#............................
no_upload=$( dialog $opt_check "
  \Z1Images to upload:\Zn
${file_img//r/  r}

" 10 0 0 "$imager_json only, no upload" off )
cd rAudio
git show-ref --tags | grep -q -m1 i$release$ && existing=Local
[[ $( git ls-remote --tags origin i$release ) ]] && existing+=Remote
if [[ $existing ]]; then
	dialog $opt_yesno "
 Tag \Z1i$release\Zn exists: ${existing/R/, R}

 Delete?
" 0 0 || exit
#------------------------------------------------------------------------------
	[[ $existing == *Local* ]]  && git tag -d i$release
	[[ $existing == *Remote* ]] && git push --delete origin i$release
fi
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
if [[ $no_upload ]]; then
	bar '$notes'
	echo "$notes"
	bar 'jq .os_list <<< $json'
	jq .os_list <<< $json
	bar Done - No upload.
	exit
#------------------------------------------------------------------------------
fi
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
clear -x
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
