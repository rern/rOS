#!/bin/bash

# write to: /root/rAudio-*.img.xz
trap BOOT_ROOT.unmount exit

shrink() {
	echo -e "$bar Shrink Pass #$1 ...\n"
	partinfo=$( tune2fs -l $partroot )
	blockcount=$( awk '/Block count/ {print $NF}' <<< "$partinfo" )
	freeblocks=$( awk '/Free blocks/ {print $NF}' <<< "$partinfo" )
	blocksize=$( awk '/Block size/ {print $NF}' <<< "$partinfo" )

	sectorsize=$( sfdisk -l $dev | awk '/Units/ {print $8}' )
	startsector=$( fdisk -l $dev | grep $partroot | awk '{print $2}' )

	usedblocks=$(( blockcount - freeblocks ))
	targetblocks=$(( usedblocks * 105 / 100 ))
	Kblock=$(( blocksize / 1024 ))
	newsize=$(( ( targetblocks + Kblock - 1 ) / Kblock * Kblock ))
	sectorsperblock=$(( blocksize / sectorsize  ))
	endsector=$(( startsector + newsize * sectorsperblock ))

	if (( $(( newsize - target )) < 10 )); then
		echo Already reached minimum size.
	else
		# shrink filesystem to minimum
		resize2fs -fp $partroot $(( newsize * Kblock ))K
		parted $dev ---pretend-input-tty <<EOF
unit
s
resizepart
2
$endsector
Yes
quit
EOF
	fi
}

# required packages
if [[ -e /usr/bin/pacman ]]; then
	[[ ! -e /usr/bin/bsdtar ]] && packages+='bsdtar '
	[[ ! -e /usr/bin/dialog ]] && packages+='dialog '
	[[ $packages ]] && pacman -Sy --noconfirm $packages
else
	[[ ! -e /usr/bin/bsdtar ]] && packages+='bsdtar libarchive-tools '
	[[ ! -e /usr/bin/dialog ]] && packages+='dialog '
	[[ $packages ]] && apt install -y $packages
fi
#........................
dialogSplash 'Create Image File'
#........................
BOOT=$PWD/BOOT
ROOT=$PWD/ROOT
partitions=$( dialogSDcard )
BOOT_ROOT.mount
dev=${partitions[0]:0:-1}
release=$( cat $ROOT/srv/http/data/addons/r1 2> /dev/null )
[[ ! $release ]] && BOOT_ROOT.unmount && errorExit SD card $dev is not rAudio.
#---------------------------------------------------------------
if [[ -e $BOOT/kernel8.img ]]; then
	model=64bit
elif [[ -e $BOOT/kernel7.img ]]; then
	model=32bit
else # $BOOT/kernel.img
	model=Legacy
fi
#........................
file_img=$( dialog $opt_input "
Image filename:
" 0 0 rAudio-$model-$release.img.xz )
clear -x
touch $BOOT/expand # auto expand root partition
BOOT_ROOT.unmount
partsize=$( fdisk -l $partroot | awk '/^Disk/ {print $2" "$3}' )
used=$( df -k 2> /dev/null | grep $partroot | awk '{print $3}' )
shrink 1
shrink 2
#........................
banner Compressed to image file ...
echo -e "$bar $file_img\n"
threads=$(( $( nproc ) - 2 ))
dd if=$dev bs=512 iflag=fullblock count=$endsector | nice -n 10 xz -v -T $threads > "$file_img"
size=$( xz -l --robot $file_img | awk '/^file/ {printf "%.2f MB <<< %.2f GB", $4/10^6, $5/10^9}' )
echo -e "
$bar Image file created:
$file_img
$size
"
