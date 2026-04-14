#!/bin/bash

BRANCH="${BRANCH:-main}"

. <( curl -sL https://raw.githubusercontent.com/rern/rOS/$BRANCH/common.sh )

trap trapExit EXIT

package.required bsdtar dialog

shrink() {
	bar "Shrink Pass #$1 ..."
	read b_used b_size b_count < <( tune2fs -l $PART_R | awk '
										/^Block count/ { count=$NF }
										/^Free blocks/ { free=$NF }
										/^Block size/  { size=$NF }
											END { print ( count - free ), size, count }' )
	b_target=$(( ( b_used * 105 ) / 100 ))
	s_size=$( blockdev --getss $DEV )
	s_end=$(( ( b_target * b_size ) / s_size ))
	if (( $(( b_count - b_target )) < 1024 )); then
		bar Almost at minimum size already.
	else
		b_new=$(( ( b_target * b_size ) / 1024 ))
		resize2fs -fp $PART_R ${b_new}K
		s_start=$( cat /sys/class/block/${PART_R/*\/}/start )
		sfdisk "$DEV" -N ${PART_R: -1} --force <<< "$s_start, $s_end"
	fi
}

#............................
dialog.splash Image File
read DEV PART_B PART_R < <( dialog.sd )
sleep 1
BR.mount
file_r1=ROOT/srv/http/data/addons/r1
[[ ! -e $file_r1 ]] && dialog.error_exit "SD card is not rAudio: \Z1$DEV\Zn"
#------------------------------------------------------------------------------
if [[ -e BOOT/kernel8.img ]]; then
	model=64bit
elif [[ -e BOOT/kernel7.img ]]; then
	model=32bit
else # BOOT/kernel.img
	model=Legacy
fi
release=$( < $file_r1 )
#............................
file_img=$( dialog.input 'Image filename:' rAudio-$model-$release.img.xz )
touch BOOT/expand # auto expand root partition
BR.unmount
#------------------------------------------------------------------------------
banner Check Partitions ...
bar BOOT: $PART_B ...
fsck.fat -taw $PART_B
bar ROOT: $PART_R ...
e2fsck -p $PART_R
#............................
banner Shrink ROOT
shrink 1
shrink 2
#............................
banner Compressed to image file ...
bar $file_img
threads=$(( $( nproc ) - 2 ))
dd if=$DEV bs=512 iflag=fullblock count=$s_end | nice -n 10 xz -v -T $threads > "$file_img"
size=$( xz -l --robot $file_img | awk '/^file/ {printf "%.2f MB <<< %.2f GB", $4/10^6, $5/10^9}' )
bar "Image file created:
$file_img
$size"
