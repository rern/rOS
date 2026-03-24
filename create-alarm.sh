#!/bin/bash

SECONDS=0
[[ $1 ]] && branch=$1
[[ ! $branch ]] && branch=main

cmdNotExist() {
	! command -v $1 &> /dev/null && return 0
}
for cmd in curl dialog gawk jq nmap pigz pv; do # required packages
	cmdNotExist $cmd && packages+="$cmd "
done
cmdNotExist sfdisk && packages+='fdisk ' # puppy linux: missing
if [[ $packages ]]; then
	if [[ -e /usr/bin/pacman ]]; then
		cmdNotExist nmap && packages+='gcc-libs ' # manjaro: libgcc conflicts
		pacman -Sy --noconfirm $packages
	else
		cmdNotExist bsdtar && packages+='libarchive-tools ' # non-arch linux: tar (default)
		apt update
		apt install -y $packages
	fi
fi

[[ ${BASH_SOURCE[0]} == ${0} ]] && . <( curl -sL https://raw.githubusercontent.com/rern/rOS/$branch/common.sh )

if [[ ! -e /usr/bin/pacman ]]; then # not arch linux
	export PATH+=:/sbin # sfdisk
	alias awk=gawk      # fix: debian - awk<mawk - no sub gsub
fi

create_ros() {
	ssh $opt_ssh root@$1 /root/create-ros.sh
#............................
	[[ $? == 255 ]] && dialog.scanIP "Unable to SSH connect: \Z1$1\Zn"
}
dialog.data() {
	latest=$( curl -sL $https_rern/rAudio-addons/main/addonslist.json | jq -r .r1.version )
#............................
	release=$( dialog.input '\Z1r\ZnAudio release:' $latest )
	if ! curl -sIfo /dev/null https://github.com/rern/rAudio/releases/tag/$release; then
		dialog.retry rAudio $release not found.
		dialog.idata
		return
#..............................................................................
	fi
	echo $release > release
#............................
	i=$( dialog.menu 'Raspberry Pi' "\
64bit  : 5, 4, 3, 2, Zero 2
32bit  : 2 (BCM2836)" )
	file=ArchLinuxARM-rpi-
	case $i in
		1 )
			file+=aarch64-
			bit=64bit
			sec_boot=60
			;;
		2 )
			file+=armv7-
			bit=32bit
			sec_boot=75
			;;
	esac
	file+=latest.tar.gz
	txt_confirm="
\Z1Confirm data:\Zn
Release      : $release
Raspberry Pi : $bit
"
#............................
	dialog $opt_yesno "
 RPi with \Z1pre-assigned\Zn IP?

" 0 0
	if [[ $? == 0 ]]; then
		(( sec_boot-=10 ))
#............................
		IP=$( dialog.ip 'Pre-assigned IP' )
		txt_confirm+="
Assigned IP  : $IP"
	fi
#............................
	dialog $opt_yesno "
Connect \Z1Wi-Fi\Zn on boot?

" 0 0
	if [[ $? == 0 ]]; then
		(( sec_boot+=5 ))
		if [[ -e wifi ]]; then
			. <( sed -E -n '/^Security|^ESSID|^Key/ {s/^.*=/\L&/; p}' wifi )
		else
#............................
			essid=$( dialog.input 'Wi-Fi - \Z1SSID\Zn:' "$essid" )
#............................
			key=$( dialog.input 'Wi-Fi - \Z1Password\Zn:' "$key" )
			tput cup 0 0
			tput ed
#............................
			i=$( dialog.menu 'Wi-Fi \Z1Security\Zn' "\
WPA
WEP
None" )
			security=( '' wpa wep )
			security=${security[i]}
		fi
		txt_confirm+="
SSID         : $essid
Password     : $key
Security     : ${security^^}"
	fi
#............................
	dialog $opt_yesno "$txt_confirm" 0 0 && confirm_data=1
	tput cup 0 0
	tput ed
	[[ ! $confirm_data ]] && dialog.data
}
dialog.download() {
#............................
	(       # stdbuf -oL: std immediately > tr '\r' '\n': convert replace line to each new line
		curl -LO $url/$file 2>&1 \
			| stdbuf -oL tr '\r' '\n' \
			| awk -v file=$file '
				/^ *[1-9]/ {
					if ( $1 == 100 ) next

					eta = $11
					sub( /^[^:]+:/, "", eta )
					s = $7
					unit = substr( s, length( s ) )
					if ( unit == "k" ) {
						num = substr( s, 1, length( s ) - 1 )
						if ( num > 1023 ) s = sprintf( "%.2fM", num / 1024 )
					}
					print "XXX"
					print $1
					print ""
					print "  Download ..."
					print "  \\Z1" file "\\Zn"
					print "  Time left: " eta " (" s "iB/s)"
					print "XXX"

					fflush()
				}'
	 ) 2>&1 | dialog $opt_gauge "
  Connect ...
" 9 $W
	[[ -e $file ]] && md5verify
}
list_features="\
BlueALSA   - Bluetooth audio              : bluealsa bluez bluez-utils python-dbus python-gobject python-requests
CamillaDSP - Digital signal processor     : camilladsp python-websocket-client
Firefox    - Browser on RPi screen        : firefox matchbox-window-manager plymouth-lite-rbp-git upower xf86-video-fbturbo
iwd        - RPi access point             : iwd
Samba      - File sharing                 : samba
Shairport  - AirPlay renderer             : shairport-sync
Snapcast   - Synchronous multiroom player : snapcast
Spotifyd   - Spotify renderer             : spotifyd
upmpdcli   - UPnP renderer                : upmpdcli python-upnpp"
readarray -t list_features_check < <( awk -F' *:' '{print $1; print "on"}' <<< $list_features )
dialog.feature() {
#............................
	checked=$( dialog $opt_check '
 \Z1Features to install:\Zn
' 8 0 0 "${list_features_check[@]}" )
	if [[ $checked ]]; then
		features=
		while read l; do
			features+=$( sed -n "/^$l/ {s/.*://; p}" <<< $list_features )
		done <<< $checked
	else
		checked='(none)'
	fi
#............................
	dialog $opt_yesno "
  \Z1Confirm features to install:\Zn

$( sed 's/^/  /' <<< $checked )
" 0 0 && echo $features > features || dialog.feature
}
dialog.scanIP() {
	dialog $opt_msg "
$@

Scan all IPs?
" 0 0 && scanIP
}
dialog.sdCard() {
	if (( $( blockdev --getsz $DEV ) > 4294967296 )); then # 2TB sector limit
		label_gpt='--label gpt'
		dialog $opt_msg "
$sd_usb larger than \Z12TB\Zn: $DEV
Only for Raspberry Pi 5, 4 and 3B+ (GPT)

Continue?
" 0 0 || exit
#------------------------------------------------------------------------------
	fi
	line_lsblk=$( lsblk -po name,label,size,mountpoint | grep -v ^/dev/loop )
	list_BR=$( grep -E ' BOOT | ROOT ' <<< $line_lsblk )
	space_select="» $( kbKey space ) to select"
	if (( $( wc -l <<< $list_BR ) > 1 )); then
		count=2
		opt_check_sd=${opt_check/--nocancel/--cancel-label Wipe}
		txt_select="$( kbKey ↑ ) $( kbKey ↓ ) $space_select \Z1BOOT\Zn and \Z1ROOT\Zn :"
		txt_retry='Selected not both BOOT and ROOT'
		readarray -t list_target_check < <( sed -E -e 's/^..|\s*$//;' -e 'a\off' <<< $list_BR )
	else
		count=1
		opt_check_sd=$opt_check
		txt_select="$space_select $sd_usb :"
		txt_retry='None selected'
		list_target_check=( "$( grep ^$DEV <<< $line_lsblk )" off )
	fi
	list_colored=$( sed -E -e 's/^/ /
						 ' -e '1 {s/^/\\\Zr\\\Zb/; s/$/ \\\Zn/}
						 ' -e "\|^ *$DEV| {s/^/\\\Z1/; s/$/\\\Zn/}
						 " -e 's/(BOOT|ROOT)/\\Z1\1\\Zn/g' <<< $line_lsblk )
	H=$(( $( wc -l <<< $list_colored ) + 9 ))
	(( $(( H + 4 )) > $( tput lines ) )) && dialog $opt_msg "
» \Z1Maximize\Zn this Terminal window

Then continue
" 0 0
	dialog.sdPartition
}
dialog.sdPartition() {
#............................
	dev_part=$( dialog $opt_check_sd "
$list_colored

 $txt_select :
" $H 0 0 "${list_target_check[@]}" ) || wipe=1
	clear -x
	if [[ ! $wipe && $( wc -l <<< $dev_part ) != $count ]]; then
		dialog.retry $txt_retry && dialog.sdPartition
		return
#..............................................................................
	fi
	if [[ $wipe || $count == 1 ]]; then
		target=$DEV
	else
		target="\
$PART_B BOOT
$PART_R ROOT"
	fi
	dialog --defaultno $opt_yesno "
$warn All data will be \Z1deleted\Zn in:

\Z1$target\Zn

Press $( kbKey Y ) to confirm
" 0 0
	if [[ $? != 0 ]]; then
		dialog.sdPartition
		return
#..............................................................................
	fi
	clear -x
	for p in $PART_B $PART_R; do # some might auto mount
		mp=$( findmnt $p ) && umount -l $mp
	done
	if [[ $wipe || $count == 1 ]]; then
		bar Wipe disk ...
		wipefs -a $DEV
		banner Create partitions
		sfdisk $label_gpt $DEV <<< "\
size=300M, type=b
size=6G,   type=83"
	else
		bar Wipe BOOT and ROOT ...
		wipefs -a $PART_B $PART_R
	fi
	bar Format BOOT and ROOT ...
	mkfs.vfat -F 32 -n BOOT $PART_B
	mkfs.ext4 -L ROOT -F $PART_R
}
md5verify() {
	clear -x
	bar Verify $file ...
	curl -sLO $url/$file.md5
	[[ $? != 0 ]] && dialog.retry 'Download *.md5 failed.' && md5verify
	if md5sum --quiet -c $file.md5; then
#............................
		[[ $1 ]] && dialog $opt_info "
 Existing is the latest:
 \Z1$file\Zn


 No download required.
" 9 $W
	else
		rm $file
		dialog.retry "Verify failed:\n$file" && dialog.download
	fi
}
memDirty() {
	awk '/Dirty:/{print $2}' /proc/meminfo
}
scanIP() {
#............................
	dialog $opt_info "
  Scan hosts in network ...
" 5 $W
	ip_base=$( ipBase )
	lines=$( nmap -sn "$ip_base*" \
				| awk '
					/^Nmap/ { ip=$NF }
					/^MAC/ {
						mac=$3
						vendor=substr( $0, index( $0, $4 ) )
						gsub( /[()]/, "", vendor )
						printf "%-13s %-18s %s\n", ip, mac, vendor
					}
				' \
				| tac )
#............................
	i=$( dialog.menu 'Select Raspberry Pi' "$lines" )
	[[ $? != 0 ]] && dialog.error_exit Arch Linux ARM not found.
#------------------------------------------------------------------------------
	create_ros $( awk 'NR=='$i' {print $1}' <<< $lines )
}

trap 'BR.unmount; clear -x' EXIT

#............................
dialog.splash 'Arch Linux ARM \Z1»\Zn rAudio'
read DEV PART_B PART_R < <( dialog.sd )
sleep 1 # fix: label ready for read
dialog.sdCard
BR.mount
dialog.data
dialog.feature
# package mirror server
lines=$( curl -sL $https_mirrorlist | sed -E -n '/^### Mirror/,$ {/^\s*$|^### Mirror/ d; s|.*//(.*)\.mirror.*|\1|; p}' )
list_menu="\
Auto (By Geo-IP)"
list_code=( '' '' )
while read line; do
	if [[ $line == '###'* ]];then
		city=
		country=${line:4}
	elif [[ $line == '## '* ]];then
		city=${line:3}
	else
		[[ $city ]] && cc="$country - $city" || cc=$country
		[[ $cc == $ccprev ]] && cc+=' 2'
		ccprev=$cc
		list_menu+="
$cc"
		list_code+=( $line )
	fi
done <<< $lines
#............................
i=$( dialog.menu 'Package mirror server' "$list_menu" )
mirror=${list_code[i]}
url=http://os.archlinuxarm.org/os
[[ $mirror ]] && url=${url/os./$mirror.mirror.}
if [[ -e $file ]]; then
	md5verify existing
else
	dialog.download
fi
rm $file.md5
size=$( stat -c %s $file )
#............................
( # -n: force stdout in each new line -Y: std immediately (26 ETA 0:00:02 261569003.1868)
	pv -nY -s $size $file -F '%{progress-amount-only} %e %r' \
		| pigz -dc \
		| bsdtar xpf - -C ROOT --exclude=*fallback.img
) 2>&1 | awk -v file=$file '
			{
				if ( $1 < 100 ) {
					eta = $3
					sub( /^[^:]+:/, "", eta )
					eta_speed = eta " " sprintf( "(%.2fMiB/s)", $NF / 1048576 )
				} else {
					eta_speed = "..."
				}

				print "XXX"
				print $1
				print ""
				print "  Decompress ..."
				print "  \\Z1" file "\\Zn"
  				print "  Time left: " eta_speed
				print "XXX"

				fflush()
			}' \
	| dialog $opt_gauge "
  Decompress ...
  \Z1$file\Zn
" 9 $W
sync
mv ROOT/boot/* BOOT
# fstab
partid=$( blkid -o value -s PARTUUID $PART_B $PART_R | sed 's/^/PARTUUID=/' )
read partid_B partid_R < <( echo $partid )
echo "\
$partid_B  /boot  vfat  defaults,noatime  0  0
$partid_R  /      ext4  defaults,noatime  0  0" > ROOT/etc/fstab
# cmdline.txt, config.txt
cmdline="root=$partid_R rw rootwait plymouth.enable=0 dwc_otg.lpm_enable=0 fsck.repair=yes isolcpus=3 console="
config="\
disable_overscan=1
disable_splash=1
dtparam=audio=on
max_usb_current=1
usb_max_current_enable=1"
if [[ $features != *firefox* ]]; then
	cmdline+='tty1'
else
	cmdline+='tty3 quiet loglevel=0 logo.nologo vt.global_cursor_default=0'
	config+='
hdmi_force_hotplug=1'
fi
echo $cmdline > BOOT/cmdline.txt0
echo "$config" > BOOT/config.txt0
# wifi
if [[ $essid ]]; then
	profile=ROOT/etc/netctl/$essid
	echo 'Interface=wlan0
Connection=wireless
IP=dhcp
ESSID="'$essid'"
Security='$security'
Key="'$key'"' > $profile
	[[ ! $security ]] && sed -E -i '/^Security|^Key/ d' "$profile"
	dir="ROOT/etc/systemd/system/netctl@$essid.service.d"
	mkdir -p $dir
	echo "\
[Unit]
BindsTo=sys-subsystem-net-devices-wlan0.device
After=sys-subsystem-net-devices-wlan0.device" > "$dir/profile.conf"
	ln -sr ROOT/usr/lib/systemd/system/netctl@.service "ROOT/etc/systemd/system/multi-user.target.wants/netctl@$essid.service"
fi
# dhcpd - disable arp
echo noarp >> ROOT/etc/dhcpcd.conf
# mirror server
[[ $mirror != 0 ]] && sed -i '/^Server/ s|//.*mirror|//'$mirror'.mirror|' ROOT/etc/pacman.d/mirrorlist
# fix dns errors
echo DNSSEC=no >> ROOT/etc/systemd/resolved.conf
# fix: time not sync on wlan
files=$( ls ROOT/etc/systemd/network/* )
for file in $files; do
	! grep -q RequiredForOnline=no $file && echo '
[Link]
RequiredForOnline=no' >> $file
done
# disable wait-online
rm -r ROOT/etc/systemd/system/network-online.target.wants
# fix: slow login
sed -i '/^-.*pam_systemd/ s/^/#/' ROOT/etc/pam.d/system-login
# ssh create-ros.sh without password
sed -i 's/#*\(PermitRootLogin \).*/\1yes/
		s/#*\(PermitEmptyPasswords \).*/\1yes/
' ROOT/etc/ssh/sshd_config
id=$( awk -F':' '/^root/ {print $3}' ROOT/etc/shadow )
sed -i "s/^root.*/root::$id::::::/" ROOT/etc/shadow
# scripts
for f in common create-ros; do
	curl -sLO $https_ros/$f.sh
done
chmod +x create-ros.sh
mv common.sh create-ros.sh features release ROOT/root
sync
BR.unmount
#............................
	dialog.splash "\
Arch Linux ARM

Created successfully
$( runDuration $SECONDS )"
#............................
dialog $opt_msg "
\Z1Arch Linux ARM\Zn      : Ready
$sd_usb : Unmounted

» Move $sd_usb to Raspberry Pi
» Power on
» Press $( kbKey Enter ):
	• Start boot timer
	• Create $logo rAudio
" 14 $W
#............................
(
	for (( i = 1; i < sec_boot; i++ )); do
		ping -4 -c 1 -W 1 $IP &> /dev/null && touch ip_found && break
#..............................................................................
		echo $(( i * 100 / sec_boot ))
		sleep 1
	done
) | dialog $opt_gauge "
  Boot ...
  \Z1Arch Linux ARM\Zn
" 9 $W
if [[ -e ip_found ]]; then
	rm ip_found
	dialog $opt_info "
  SSH Arch Linux ARM ...
  @ \Z1$IP\Zn
" 9 $W
	create_ros $IP
elif [[ $IP ]]; then
#............................
	dialog.scanIP "\Z1Assigned IP\Zn not found: $IP"
else
	scanIP
fi
