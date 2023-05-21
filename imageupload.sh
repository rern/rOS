##!/bin/bash
[[ ! -e /usr/bin/gh ]] && echo -e "\nPackage gh not yet installed.\n" && exit

[[ $EUID == 0 ]] && echo -e "\nsu x and run again.\n" && exit

[[ ! -d /home/x/rAudio ]] && echo -e "\nDirectory /home/x/rAudio not found.\n" && exit
	
cd /home/x/rAudio

! gh auth status &> /dev/null && gh auth login -p ssh -w

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
| `4` `3` `2 BCM2837` `Zero 2` | [rAudio-64bit-'$release'.img.xz](https://github.com/rern/rAudio/releases/download/i'$release'/rAudio-64bit-'$release'.img.xz)   | [< file](https://cloud.s-t-franz.de/s/kdFZXN9Na28nfD8/download?path=%2F&files=rAudio-64bit-'$release'.img.xz)  |
| `2 BCM2836`                  | [rAudio-RPi2-'$release'.img.xz](https://github.com/rern/rAudio/releases/download/i'$release'/rAudio-RPi2-'$release'.img.xz)     | [< file](https://cloud.s-t-franz.de/s/kdFZXN9Na28nfD8/download?path=%2F&files=rAudio-RPi2-'$release'.img.xz)   |
| `1` `Zero`                   | [rAudio-RPi0-1-'$release'.img.xz](https://github.com/rern/rAudio/releases/download/i'$release'/rAudio-RPi0-1-'$release'.img.xz) | [< file](https://cloud.s-t-franz.de/s/kdFZXN9Na28nfD8/download?path=%2F&files=rAudio-RPi0-1-'$release'.img.xz) |
'
echo -e "\nUpload rAudio Image Files: i$release ...\n"

gh release create i$release --title i$release --notes "$notes" $selectfiles
