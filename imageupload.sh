#!/bin/bash
[[ ! -e /usr/bin/gh ]] && echo -e "\nPackage github-cli not yet installed.\n" && exit

[[ $EUID == 0 ]] && echo -e "\nsu x and run again.\n" && exit

[[ ! -d /home/x/rAudio ]] && git clone https://github.com/rern/rAudio/

cd /home/x/rAudio

! gh auth status &> /dev/null && gh auth login -p ssh -w

rm -f rAudio*img.xz
ln -s ../BIG/*.xz .

optbox=( --colors --no-shadow --no-collapse )
imgfiles=( $( ls rAudio*.img.xz 2> /dev/null ) )
for file in "${imgfiles[@]}"; do
	filelist+=" $file on"
done

selectfiles=$( dialog "${optbox[@]}" --output-fd 1 --nocancel --no-items --checklist "
 \Z1Select files to upload:\Z0
 $imgdir" $(( ${#imgfiles[@]} + 6 )) 0 0 \
$filelist )
files=( $selectfiles )
(( ${#files[@]} != 3 )) && echo 'Image files count not 3.' && exit

file0=${files[0]}
dir=$( dirname $file0 )
release=$( echo ${file0/*-} | cut -d. -f1 )
for model in 64bit RPi2 RPi0-1; do
	file=rAudio-$model-$release.img.xz
 	echo "MD5 $file ..."
 	image_md5_mirror+=( "[$file](https://github.com/rern/rAudio/releases/download/i$release/$file) \
  					   | $( md5sum $dir/$file | cut -d' ' -f1 ) \
                       | [< file](https://cloud.s-t-franz.de/s/kdFZXN9Na28nfD8/download?path=%2F&files=$file)" )
done
notes='
| Raspberry Pi                      | Image File | MD5 | Mirror |
|:----------------------------------|:-----------|:----|:-------|
| `5` `4` `3` `2 (BCM2837)` `Zero2` | '${image_md5_mirror[0]}'  |
| `3` `2`                           | '${image_md5_mirror[1]}'  |
| `1` `Zero`                        | '${image_md5_mirror[2]}'  |
'
echo -e "\nUpload rAudio Image Files: i$release ...\n"

gh release create i$release --title i$release --notes "$notes" $selectfiles
