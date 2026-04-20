#!/bin/bash

BRANCH="${BRANCH:-main}"

. <( curl -sL https://github.com/rern/rOS/raw/$BRANCH/common.sh )

trap trapExit EXIT

package.required bsdtar dialog

shrink() {
	[[ $noshrink ]] && return

	bar "Shrink Pass #$1 ..."
	sect_size=$( blockdev --getss $DEV )
	sect_min=$( tune2fs -l $PART_R \
					| awk  -v sect_size=$sect_size '
						/^Block count/ { count = $NF }
						/^Free blocks/ { free  = $NF }
						/^Block size/  { size  = $NF }
							END {
								target = sprintf( "%.0f", ( count - free ) * 1.05 )
								if ( count - target > 1024 ) printf "%.0f", target * size / sect_size
							}
					' )
	sect_start=$( cat /sys/class/block/${PART_R/*\/}/start )
	sect_end=$(( sect_start + sect_min ))
	if [[ ! $sect_min ]]; then
		noshrink=1
		bar $PART_R already at minimum size.
	else
		resize2fs -fp $PART_R $(( sect_min * sect_size / 1024 ))K
		parted -s $DEV ---pretend-input-tty << EOF
unit
s
resizepart
2
$sect_end
Yes
quit
EOF
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
file_img=$( dialog.input '\Z1Image filename:\Zn' rAudio-$model-$release.img.xz )
touch BOOT/{expand,password}
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

exit



#............................
banner Compressed to image file ...
bar $file_img
threads=$(( $( nproc ) - 2 ))
dd if=$DEV iflag=fullblock bs=$sect_size count=$sect_end | nice -n 10 xz -v -T $threads > "$file_img"
bar "Image file created:
$file_img
$( xz -l --robot $file_img | awk '/^file/ {printf "%.2f MB <<< %.2f GB\n", $4/10^6, $5/10^9}' )"
