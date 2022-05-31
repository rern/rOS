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

release=$( echo ${imgfiles[0]/*-} | cut -d. -f1 )
notes='
| Raspberry Pi                 | Image  File | Mirror |
|:-----------------------------|:------------|:-------|
| `4` `3` `2 BCM2837` `Zero 2` | [rAudio-1-64bit-'$release'.img.xz](https://github.com/rern/rAudio-1/releases/download/i'$release'/rAudio-1-64bit-'$release'.img.xz)   | [< file](https://cloud.s-t-franz.de/s/kdFZXN9Na28nfD8/download?path=%2F&files=rAudio-1-64bit-'$release'.img.xz)  |
| `2 BCM2836`                  | [rAudio-1-RPi2-'$releas'e.img.xz](https://github.com/rern/rAudio-1/releases/download/i'$release'/rAudio-1-RPi2-'$release'.img.xz)     | [< file](https://cloud.s-t-franz.de/s/kdFZXN9Na28nfD8/download?path=%2F&files=rAudio-1-RPi2-'$release'.img.xz)   |
| *`1` *`Zero`                 | [rAudio-1-RPi0-1-'$release'.img.xz](https://github.com/rern/rAudio-1/releases/download/i'$release'/rAudio-1-RPi0-1-'$release'.img.xz) | [< file](https://cloud.s-t-franz.de/s/kdFZXN9Na28nfD8/download?path=%2F&files=rAudio-1-RPi0-1-'$release'.img.xz) |
'
banner "rAudio Image Files: i$release"

cd rAudio-1
gh release create i$release --title i$release --notes "$notes" $imgdir/*.img.xz
