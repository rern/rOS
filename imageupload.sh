##!/bin/bash
[[ ! -e /usr/bin/gh ]] && echo -e "\nPackage gh not yet installed.\n" && exit

[[ $EUID == 0 ]] && echo -e "\nsu x and run again.\n" && exit

[[ ! -d /home/x/rAudio ]] && git clone https://github.com/rern/rAudio/
	
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
version=$release.img.xz
imagefile="[rAudio-64bit-$version](https://github.com/rern/rAudio/releases/download/i$release/rAudio-64bit-$version)"
mirror="[< file](https://cloud.s-t-franz.de/s/kdFZXN9Na28nfD8/download?path=%2F&files=rAudio-64bit-$version)"
notes='
| Raspberry Pi                 | Image  File                  | Mirror                    |
|:-----------------------------|:-----------------------------|:--------------------------|
| `4` `3` `2 BCM2837` `Zero 2` | '$imagefile'                 | '$mirror'                 |
| `2 BCM2836`                  | '${imagefile//64bit/RPi2}'   | '${mirror//64bit/RPi2}'   |
| `1` `Zero`                   | '${imagefile//64bit/RPi0-1}' | '${mirror//64bit/RPi0-1}' |
'
echo -e "\nUpload rAudio Image Files: i$release ...\n"

gh release create i$release --title i$release --notes "$notes" $selectfiles
