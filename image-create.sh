#!/bin/bash

trap 'BR.unmount; clear -x' EXIT

shrink() {
	bar "Shrink Pass #$1 ..."
	partinfo=$( tune2fs -l $PART_R )
	blockcount=$( awk '/Block count/ {print $NF}' <<< "$partinfo" )
	freeblocks=$( awk '/Free blocks/ {print $NF}' <<< "$partinfo" )
	blocksize=$( awk '/Block size/ {print $NF}' <<< "$partinfo" )

	sectorsize=$( sfdisk -l $DEV | awk '/Units/ {print $8}' )
	startsector=$( fdisk -l $DEV | grep $PART_R | awk '{print $2}' )

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
		resize2fs -fp $PART_R $(( newsize * Kblock ))K
		parted $DEV ---pretend-input-tty <<EOF
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
#............................
dialog.splash Image File
image_create=1
. <( curl -sL $https_ros_raw/$branch/dialog_sdcard.sh ) # set $DEV $PART_B $PART_R
banner Check Partitions ...
bar BOOT: $PART_B ...
fsck.fat -taw $PART_B
bar ROOT: $PART_R ...
e2fsck -p $PART_R
BR.mount
file_r1=ROOT/srv/http/data/addons/r1
if [[ ! -e $file_r1 ]]; then
#............................
	dialog $opt_msg "
SD card is not rAudio: \Z1$DEVZn
" 0 0
	dialog.sdCard
fi
release=$( < $file_r1 )
if [[ -e BOOT/kernel8.img ]]; then
	model=64bit
elif [[ -e BOOT/kernel7.img ]]; then
	model=32bit
else # BOOT/kernel.img
	model=Legacy
fi
#............................
file_img=$( dialog $opt_input "
Image filename:
" 0 0 rAudio-$model-$release.img.xz )
touch BOOT/expand # auto expand root partition
BR.unmount
partsize=$( fdisk -l $PART_R | awk '/^Disk/ {print $2" "$3}' )
used=$( df -k 2> /dev/null | grep $PART_R | awk '{print $3}' )
#............................
banner Shrink ROOT
shrink 1
shrink 2
#............................
banner Compressed to image file ...
bar $file_img
threads=$(( $( nproc ) - 2 ))
dd if=$DEV bs=512 iflag=fullblock count=$endsector | nice -n 10 xz -v -T $threads > "$file_img"
size=$( xz -l --robot $file_img | awk '/^file/ {printf "%.2f MB <<< %.2f GB", $4/10^6, $5/10^9}' )
bar "Image file created:
$file_img
$size"
