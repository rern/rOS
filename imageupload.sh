##!/bin/bash

[[ $( basename $PWD ) != rAudio-1 ]] && echo Current directory not rAudio-1 repo. && exit

optbox=( --colors --no-shadow --no-collapse )

[[ ! -e /usr/bin/gh ]] && pacman -Sy --noconfirm github-cli
if ! gh auth status &> /dev/null; then
	dialog "${optbox[@]}" --infobox "
\Z1Login required:\Z0
gh auth login -p ssh
> GitHub.com
> Skip SSH key
> Paste token
> Get token: https://github.com/settings/tokens 
> Personal access token:
  - repo, admin:org, admin:public_key
  
" 0 0
	exit
fi

imgdir=$( dialog "${optbox[@]}" --title 'Image file:' --stdout --dselect $PWD/ 20 40 )
imgfiles=( $( cd "$imgdir" && ls -1 rAudio*.img.xz 2> /dev/null ) )
for file in "${imgfiles[@]}"; do
	filelist+=" $file on"
done

selectfiles=$( dialog "${optbox[@]}" --output-fd 1 --nocancel --no-items --checklist "
 \Z1Select files to upload:\Z0
 $imgdir
" $(( ${#imgfiles[@]} + 6 )) 0 0 \
$filelist )

release=$( echo ${selectfiles[0]/*-} | cut -d. -f1 )
notes='
| Raspberry Pi                 | Image  File | Mirror |
|:-----------------------------|:------------|:-------|
| `4` `3` `2 BCM2837` `Zero 2` | [rAudio-1-64bit-'$release'.img.xz](https://github.com/rern/rAudio-1/releases/download/i'$release'/rAudio-1-64bit-'$release'.img.xz)   | [< file](https://cloud.s-t-franz.de/s/kdFZXN9Na28nfD8/download?path=%2F&files=rAudio-1-64bit-'$release'.img.xz)  |
| `2 BCM2836`                  | [rAudio-1-RPi2-'$release'.img.xz](https://github.com/rern/rAudio-1/releases/download/i'$release'/rAudio-1-RPi2-'$release'.img.xz)     | [< file](https://cloud.s-t-franz.de/s/kdFZXN9Na28nfD8/download?path=%2F&files=rAudio-1-RPi2-'$release'.img.xz)   |
| *`1` *`Zero`                 | [rAudio-1-RPi0-1-'$release'.img.xz](https://github.com/rern/rAudio-1/releases/download/i'$release'/rAudio-1-RPi0-1-'$release'.img.xz) | [< file](https://cloud.s-t-franz.de/s/kdFZXN9Na28nfD8/download?path=%2F&files=rAudio-1-RPi0-1-'$release'.img.xz) |
'
echo -e "\nUpload rAudio Image Files: i$release ...\n"

for file in $selectfiles; do
	uploadfiles+="$imgdir/$file "
done

gh release create i$release --title i$release --notes "$notes" $uploadfiles
