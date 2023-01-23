##!/bin/bash

[[ ! -e /usr/bin/gh ]] && echo -e "\nPackage gh not yet installed.\n" && exit

su x
cd
[[ ! -d rAudio-1 ]] && echo -e "\nDirectory rAudio-1 not found.\n" && exit
	
cd rAudio-1

if ! gh auth status &> /dev/null; then
	echo '
? What account do you want to log into? 
   > GitHub.com
? Upload your SSH public key to your GitHub account?
   > Skip
? How would you like to authenticate GitHub CLI?
   > Paste an authentication token
'
	gh auth login -p ssh
fi

rm -f rAudio*img.xz
ln -s ../BIG/*.xz .

optbox=( --colors --no-shadow --no-collapse )
imgfiles=( $( ls -1 rAudio*.img.xz 2> /dev/null ) )
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
| `1` `Zero`                   | [rAudio-1-RPi0-1-'$release'.img.xz](https://github.com/rern/rAudio-1/releases/download/i'$release'/rAudio-1-RPi0-1-'$release'.img.xz) | [< file](https://cloud.s-t-franz.de/s/kdFZXN9Na28nfD8/download?path=%2F&files=rAudio-1-RPi0-1-'$release'.img.xz) |
'
echo -e "\nUpload rAudio Image Files: i$release ...\n"

gh release create i$release --title i$release --notes "$notes" $selectfiles
