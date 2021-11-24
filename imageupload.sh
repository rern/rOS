##!/bin/bash

optbox=( --colors --no-shadow --no-collapse )

user=$( dialog "${optbox[@]}" --output-fd 1 --inputbox "
User:
" 0 0 )
repo=$( dialog "${optbox[@]}" --output-fd 1 --inputbox "
Repo:
" 0 0 )
tag=$( dialog "${optbox[@]}" --output-fd 1 --inputbox "
Tag:
" 0 0 )
Token=$( dialog "${optbox[@]}" --output-fd 1 --inputbox "
Token:
" 0 0 )
file=$( dialog "${optbox[@]}" --output-fd 1 --inputbox "
Image:
" 0 0 )

id=$( curl -sH "Authorization: token $token" \
		https://api.github.com/repos/$user/$repo/releases/tags/$tag \
		| jq .id )
curl \
	-H "Authorization: token $token" \
	-H "Content-Type: $( file -b --mime-type $file )" \
	--data-binary @"$file" \
	"https://uploads.github.com/repos/$user/$repo/releases/$id/assets?name=$( basename $file )" \
	| jq
