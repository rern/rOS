##!/bin/bash

[[ ! -e rAudio-1 ]] && echo rAudio-1 not found. && exit

imgdir=$( dialog "${optbox[@]}" --title 'Image file:' --stdout --dselect $PWD/ 20 40 )
imgfiles=$( ls -1 "$imgdir"/rAudio*.img.xz 2> /dev/null )
[[ -z $imgfiles ]] && echo "No image files found in $imgdir" && exit

optbox=( --colors --no-shadow --no-collapse )

dialog "${optbox[@]}" --yesno "
\Z1Image files list:\Z0

$imgfiles

" 0 0
[[ $? != 0 ]] && exit

col=$( tput cols )
banner() {
	echo
	def='\e[0m'
	bg='\e[44m'
    printf "$bg%*s$def\n" $col
    printf "$bg%-${col}s$def\n" "  $1"
    printf "$bg%*s$def\n" $col
	echo
}

release=i$( echo ${imgfiles[0]/*-} | cut -d. -f1 )

banner "rAudio Image Files: $release"

cd rAudio-1
gh release create $release $imgdir/*.img.xz
