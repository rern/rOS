#!/bin/bash

#............................
dialog.splash Upload Image Files
if [[ ! -e /bin/git || ! -e /bin/gh ]]; then
	[[ ! -e /bin/gh ]] && gh=github-cli
	pacman -Sy --noconfirm git $gh
fi
if [[ $gh ]] || ! gh auth status &> /dev/null; then
	. <( curl -sL https://github.com/rern/rOS/raw/main/github-cli_setup.sh )
fi

file_img=$( ls rAudio*.img.xz ) # rAudio-MODEL-YYYYMMDD.img.xz
if [[ $file_img ]]; then
	(( $( wc -l <<< $file_img ) != 3 )) && error+="Files not 3:\n$file_img\n"
	models=$( cut -d- -f2 <<< $file_img | sort -u | wc -l )
	(( $models != 3 )) && error="Models not 3:\n$models\n"
	release=$( awk -F'[-.]' '{print $3}' <<< $file_img | sort -u )
	(( $( wc -l <<< $release ) > 1 )) && error+="Release not the same:\n$release\n"
else
	error+='No \Z1*.img.xz\Zn found.'
fi
[[ $error ]] && dialog.error_exit "$error"
#------------------------------------------------------------------------------
if [[ ! -d rAudio/.git ]]; then
	git clone https://github.com/rern/rAudio
##########
	cd rAudio
	git checkout UPDATE
else
##########
	cd rAudio
fi
#............................
no_upload=$( dialog $opt_check "
  \Z1Images to upload:\Zn
${file_img//r/  r}

" 10 0 0 "NO upload - rpi-imager.json only" on )
if [[ ! $no_upload ]]; then
	git show-ref --tags | grep -q -m1 i$release$ && existing=Local
	[[ $( git ls-remote --tags origin i$release ) ]] && existing+=Remote
	if [[ $existing ]]; then
		dialog $opt_yesno "
	Tag \Z1i$release\Zn exists: ${existing/R/, R}

	\Z1Delete?\Zn
	" 0 0 || exit
#------------------------------------------------------------------------------
		[[ $existing == *Local* ]]  && git tag -d i$release
		[[ $existing == *Remote* ]] && git push --delete origin i$release
	fi
fi
y_m_d=${release:0:4}-${release:4:2}-${release: -2}
json=$( sed -E -e "s|i[0-9]{8}/(rAudio.*-).*(.img.xz)|i$release/\1$release\2|
			 " -e 's/(release_date": ").*/\1'$y_m_d'",/
			 ' rpi-imager.json )
notes='
| Raspberry Pi | Image File | Mirror |
|:-------------|:-----------|:-------|'
declare -A model_rpi=(
	[64bit]='`5` `4` `3` `2 (64bit)` `Zero2`'
	[32bit]='`3` `2`'
	[Legacy]='`1` `Zero`' )
models=( $( jq -r .os_list[].name <<< $json | cut -d' ' -f2 ) )
##########
cd ..
#............................
banner S H A - 2 5 6
for (( i=0; i < 3; i++ )); do
	model=${models[i]}
	file=$( grep $model <<< $file_img )
 	read size_xz size_img < <( xz -l --robot $file | awk '/^file/ {print $4, $5}' )
	bar $file
	printf 'sha256sum \e[5m...\e[0m'
	sha256=$( sha256sum $file | cut -d' ' -f1 )
	printf "\r$sha256\n"
	json=$( jq '.os_list['$i'] |= (
                      .extract_size          = '$size_img'
                    | .image_download_size   = '$size_xz'
                    | .image_download_sha256 = "'$sha256'"
                )' <<< $json )
	notes+="
| ${model_rpi[$model]} \
| [$file]($https_raudio/releases/download/i$release/$file) \
| [< file](https://cloud.s-t-franz.de/public.php/dav/files/kdFZXN9Na28nfD8/$file) |"
done
if [[ $no_upload ]]; then
	bar '$notes'
	echo "$notes"
	bar 'jq .os_list <<< $json'
	echo ...
	jq .os_list <<< $json
	echo ...
	bar Done - No upload.
	exit
#------------------------------------------------------------------------------
fi
#............................
banner U p l o a d
bar "Image files:
$file_img
"
file_path=$( sed "s|^|$PWD/|" <<< $file_img )
##########
cd rAudio
gh release create i$release --latest=false --title i$release --notes "$notes" $file_path
[[ $? != 0 ]] && dialog.error_exit Upload failed.
#------------------------------------------------------------------------------
br_all=$( git branch --list | sort | awk '{print NR, $NF}' )
br_current=$( git branch --show-current )
br_line=$( awk '/'$br_current$'/ {print $1}' <<< $br_all )
h=$(( 6 + $( wc -l <<< $br_all ) ))
#............................
select=$( dialog --default-item $br_line $opt_menu "
Branch for rpi-imager.json
" $h 0 0 $br_all )
clear -x
if [[ $select != $br_line ]]; then
	[[ $select == 1 ]] && branch=main || branch=UPDATE
	branch=$( awk 'NR=='$select' {print $2}' <<< $br_all )
#	git diff-index --quiet HEAD && git commit -m U
	git switch $branch
fi
git pull
echo "$json" > rpi-imager.json
git add rpi-imager.json
git commit -m rpi-imager.json
git push
[[ $? != 0 ]] && dialog.error_exit "Push \Z1rpi-imager.json\Zn failed."
#------------------------------------------------------------------------------
text="\
 $logo

 \Z1Image files\Zn     : Uploaded successfully.
 \Z1rpi-imager.json\Zn : Updated and pushed"
[[ $branch != main ]] && text+=" to \Z1$branch\Zn
                   \Z4(Must be merged manually)\Zn"
dialog.info "$text"
