##!/bin/bash

optbox=( --colors --no-shadow --no-collapse )

user=rern
repo=rAudio-1
tag=$( dialog "${optbox[@]}" --output-fd 1 --inputbox "
Tag:
" 0 0 )
Token=$( dialog "${optbox[@]}" --output-fd 1 --inputbox "
Token:
" 10 50 )
id=$( curl -sH "Authorization: token $token" \
		https://api.github.com/repos/$user/$repo/releases/tags/$tag \
		| jq .id )
		
imageUpload() {
	file=$1
	curl \
		-H "Authorization: token $token" \
		-H "Content-Type: $( file -b --mime-type $file )" \
		--data-binary @"$file" \
		"https://uploads.github.com/repos/$user/$repo/releases/$id/assets?name=$( basename $file )" \
		| jq
}

for rpi in 64bit RPi2 RPi0-1; do
	imageUpload rAudio-1-$rpi-$tag.img.xz
done
