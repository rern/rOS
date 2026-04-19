#!/bin/bash

BRANCH="${BRANCH:-main}"

. <( curl -sL https://github.com/rern/rOS/raw/$BRANCH/common.sh )

trap trapExit EXIT

package.required bsdtar dialog

shrink() {
	bar "Shrink Pass #$1 ..."
	partinfo=$( tune2fs -l $PART_R )
	blk_count=$( awk '/Block count/ {print $NF}' <<< "$partinfo" )
	blk_free=$( awk '/Free blocks/ {print $NF}' <<< "$partinfo" )
	blk_size=$( awk '/Block size/ {print $NF}' <<< "$partinfo" )

	blk_target=$(( (  ( blk_count - blk_free ) * 105 ) / 100 ))
	if (( $(( blk_count - blk_target )) < 1024 )); then
		bar Almost at minimum size already.
	else
		blk_kb=$(( blk_size / 1024 ))
		blk_new=$(( ( targetblocks + blk_kb - 1 ) / blk_kb * blk_kb )) # round kb
		sect_size=$( blockdev --getss $DEV )
		sect_new=$(( blk_new * ( blk_size / sect_size ) ))
		sect_start=$( cat /sys/class/block/${PART_R/*\/}/start )
		sect_end=$(( sect_start + sect_new ))
		resize2fs -fp $PART_R $(( blk_new * blk_kb ))K
		sfdisk "$DEV" -N ${PART_R: -1} --force <<< "$sect_start, $sect_end"
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
case $( basename $( ls BOOT/kernel*.img ) .img ) in
	kernel8 ) model=64bit;;
	kernel7 ) model=32bit;;
	* )       model=Legacy;;
esac
release=$( < $file_r1 )
#............................
file_img=$( dialog.input 'Image filename:' rAudio-$model-$release.img.xz )
touch BOOT/expand # for expand root partition and set root pasword
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
blk_size=512
blk_end=$(( byte_target / blk_size ))
threads=$(( $( nproc ) - 2 ))
dd if=$DEV iflag=fullblock bs=$blk_size count=$blk_end | nice -n 10 xz -v -T $threads > "$file_img"
bar "Image file created:
$file_img"
xz -l --robot $file_img | awk '/^file/ {printf "%.2f MB <<< %.2f GB", $4/10^6, $5/10^9}'
