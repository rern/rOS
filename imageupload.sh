##!/bin/bash

imgfiles=$( ls -1 rAudio*.img.xz 2> /dev/null )
[[ -z $imgfiles ]] && echo 'No image files found in current directory.' && exit

optbox=( --colors --no-shadow --no-collapse )

dialog "${optbox[@]}" --yesno "
\Z1Image files list:\Z0

$imgfiles

" 0 0
[[ $? != 0 ]] && exit

user=rern
repo=rAudio-1
tag=$( dialog "${optbox[@]}" --output-fd 1 --inputbox "
Release:
" 0 0 i2021 )
token=$( dialog "${optbox[@]}" --output-fd 1 --inputbox "
Token:
" 9 50 )
id=$( curl -sH "Authorization: token $token" \
		https://api.github.com/repos/$user/$repo/releases/tags/$tag \
		| jq .id )
		
imageUpload() {
	file=$1
	curl \
		-H "Authorization: token $token" \
		-H "Content-Type: application/x-xz" \
		--data-binary @"$file" \
		"https://uploads.github.com/repos/$user/$repo/releases/$id/assets?name=$( basename $file )" \
		| jq
}

for $file in "${imgfiles[@]}"; do
	imageUpload $file
done
