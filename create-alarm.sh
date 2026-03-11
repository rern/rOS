#!/bin/bash

# bash <( curl -sL https://github.com/rern/rOS/raw/UPDATE/create-alarm.sh ) UPDATE

[[ $1 ]] && branch=$1
[[ ! $branch ]] && branch=main

for cmd in bsdtar dialog jq nmap pigz pv; do # required packages
	[[ ! -e /usr/bin/$cmd ]] && packages+="$cmd "
done
if [[ $packages ]]; then
	if [[ -e /usr/bin/pacman ]]; then
		pacman -Sy --noconfirm $packages
	else
		apt install -y $packages
	fi
fi

if [[ ${BASH_SOURCE[0]} == ${0} ]]; then
	bash_run=1
	. <( curl -sL https://github.com/rern/rOS/raw/$branch/common.sh )
fi
#............................
dialog.splash Arch Linux ARM » rAudio
if [[ $bash_run ]]; then
#............................
	i=$( dialog.menu "Target $sd_usb" "
Select already created
Wipe existings and create new
" )
	[[ $i == 1 ]] && select_part_BR=1
fi

trap 'BR.unmount; clear -x' EXIT

. <( curl -sL $https_ros_branch/dialog_sdcard.sh ) # set $DEV $PART_B $PART_R
if [[ ! $select_part_BR ]]; then # from +R.sh
#............................
    banner Partition SD Card ...
    wipefs -a $DEV
    mb_B=300
    mb_R=6400
    size_B=$(( mb_B * 2048 ))
    size_R=$(( mb_R * 2048 ))
    start_R=$(( 2048 + size_B ))
    echo "\
$PART_B : start=     2048, size= $size_B, type=c
$PART_R : start= $start_R, size= $size_R, type=83
" | sfdisk $DEV # existing: fdisk -d /dev/sdX
    mkfs.fat -F 32 $PART_B
    mkfs.ext4 -F $PART_R
    fatlabel $PART_B BOOT
    e2label $PART_R ROOT
fi
BR.mount
if [[ $select_part_BR ]]; then
	read mp fs < <( findmnt -no target,fstype $PART_B )
	[[ $( ls $mp ) ]] && err_B=', Empty'
	[[ $fs != vfat ]] && err_B+=', VFAT'
	read mp fs < <( findmnt -no target,fstype $PART_R )
	[[ $( ls $mp | grep -v lost+found ) ]] && err_R=', Empty'
	[[ $fs != ext4 ]] &&                      err_R+=', Ext4'
	[[ $err_B ]] && error="
\Z1BOOT\Zn $PART_B not: ${err_B:2}" # :2 leading ,
	[[ $err_R ]] && error+="
\Z1ROOT\Zn $PART_R not: ${err_R:2}"
	[[ $error ]] && dialog.error_exit "${error:1}" # :1 leading \n
#------------------------------------------------------------------------------
fi

create_ros() {
	ssh $opt_ssh root@$1 /root/create-ros.sh
	[[ $? == 255 ]] && dialog.scanIP "Unable to SSH connect IP: \Z1$1\Zn"
}
dialog.download() {
#............................
	( 
		wget -O $file $url/$file 2>&1 \
			| stdbuf -o0 awk '/[.] +[0-9][0-9]?[0-9]?%/ {
				print "XXX"
				print substr( $0, 63, 3 )
				print ""
				print "  Download ..."
				print "  \\Z1'$file'\\Zn"
				print "  Time left: "substr( $0, 74, 5 )
				print "XXX"
			}' 
	 ) 2>&1 | dialog $opt_gauge "
 Connecting ...
" 9 $W 0 && md5verify || dialog.retry "Download failed:\n$file"
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
readarray -t list_check < <( awk -F' *:' '{print $1; print "on"}' <<< $list_features )
dialog.feature() {
#............................
	checked=$( dialog $opt_check '
 \Z1Features to install:\Zn
' 8 0 0 "${list_check[@]}" )
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

$checked
" 0 0 && echo $features > BOOT/features || dialog.feature
}
dialog.scanIP() {
	dialog $opt_msg "
$@

Scan all IPs?
" 0 0 && scanIP
}
getData() {
	latest=$( curl -sL $https_rern/rAudio-addons/raw/main/addonslist.json | jq -r .r1.version )
#............................
	release=$( dialog.input '\Z1r\ZnAudio release:' "$latest )
	if ! curl -sIfo /dev/null $https_rern/rAudio/releases/tag/$release; then
		dialog.retry rAudio $release not found.
		getData
		return
#..............................................................................
	fi
	echo $release > BOOT/release
#............................
	i=$( dialog.menu 'Raspberry Pi' "\
64bit  : 5, 4, 3, 2, Zero 2
32bit  : 2 (BCM2836)" )
	file=ArchLinuxARM-rpi-
	case $i in
		1 )
			file+=aarch64-
			bit=64bit
			sec_boot=45
			;;
		2 )
			file+=armv7-
			bit=32bit
			sec_boot=60
			;;
	esac
	file+=latest.tar.gz
#............................
	dialog $opt_yesno "
 RPi with \Z1pre-assigned\Zn IP?

" 0 0
	if [[ $? == 0 ]]; then
		(( sec_boot-=10 ))
#............................
		IP=$( dialog.ip 'Pre-assigned IP' )
		confirm_ip="
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
			tput cup 0 0 && tput ed
#............................
			i=$( dialog.menu 'Wi-Fi \Z1Security\Zn' "\
WPA
WEP
None" )
			security=( '' wpa wep )
			security=${security[i]}
		fi
		confirm_wifi="
SSID         : $essid
Password     : $key
Security     : ${security^^}"
	fi
#............................
	dialog $opt_yesno "
\Z1Confirm data:\Zn

Release      : $release
Raspberry Pi : $bit

$confirm_wifi
$confirm_ip
" 0 0
	tput cup 0 0 && tput ed
	[[ $? == 1 ]] && getData
}
md5verify() {
	clear -x
	bar Verify $file ...
	curl -skLO $url/$file.md5
	[[ $? != 0 ]] && dialog.retry 'Download *.md5 failed.' && md5verify
	md5sum -c $file.md5 && return 0
#..............................................................................
	rm $file
	dialog.download
}
memDirty() {
	awk '/Dirty:/{print $2}' /proc/meminfo
}
pingIP() {
	ping -4 -c 1 -W 1 $1 &> /dev/null
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

getData
dialog.feature
SECONDS=0
# package mirror server
lines=$( curl -skL https://github.com/archlinuxarm/PKGBUILDs/raw/master/core/pacman-mirrorlist/mirrorlist \
			| sed -E -n '/^### Mirror/,$ {/^\s*$|^### Mirror/ d; s|.*//(.*)\.mirror.*|\1|; p}' )
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
[[ $mirror ]] && url=http://$mirror.mirror.archlinuxarm.org/os || url=http://os.archlinuxarm.org/os
if [[ -e $file ]]; then
#............................
	md5verify && dialog $opt_info "
 Existing is the latest:
 \Z1$file\Zn
 

 No download required.
" 9 $W
else
	dialog.download
fi
rm $file.md5
size=$( stat -c %s $file )
#............................
(
	pv -n -s $size $file \
		| pigz -dc \
		| bsdtar xpf - -C ROOT --exclude=*fallback.img
) 2>&1 | dialog $opt_gauge "
  Decompress ...
  \Z1$file\Zn
" 9 $W 0
dirty=$( memDirty )
#........................
( while true; do
	left=$( memDirty )
	(( $left < 1000 )) && break

	echo $(( ( dirty - left ) * 100 / dirty ))
	sleep 2
done ) | dialog $opt_guage "
  Write remaining ...
  \Z1$file\Zn
" 9 $W
mv ROOT/boot/* BOOT
# fstab
partid=( $( blkid -o value -s PARTUUID $PART_B $PART_R | sed 's/^/PARTUUID=/' ) )
partid_B=${partid[0]}
partid_R=${partid[1]}
echo "\
$partid_B  /boot  vfat  defaults,noatime  0  0
$partid_R  /      ext4  defaults,noatime  0  0" > ROOT/etc/fstab
# cmdline.txt, config.txt
cmdline="root=$partid_R rw rootwait plymouth.enable=0 dwc_otg.lpm_enable=0 fsck.repair=yes isolcpus=3 console="
config="\
disable_overscan=1
disable_splash=1
dtparam=audio=on"
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
mv BOOT/{features,release} ROOT/root
for f in {common,create-ros}.sh; do
	curl -sL $https_ros_branch/$f -o ROOT/root/$f
done
chmod 755 ROOT/root/*.sh
sync
BR.unmount
#............................
	dialog.splash "\
Arch Linux ARM

Created successfully
$( runDuration )"
[[ ${partid_B:0:-1} != ${partid_R:0:-1} ]] && usb=' and USB drive'
#............................
dialog $opt_msg "
\Z1Arch Linux ARM\Zn            : Ready
$sd_usb : Unmounted

» Move SD card$usb to RPi
» Power on
» Press \Zr\Zb Enter \Zn:
	• Start boot timer
	• Create $logo rAudio
" 14 $W
#............................
(
	for (( i = 1; i < sec_boot; i++ )); do
		echo $(( i * 100 / sec_boot ))
		sleep 1
	done 
) | dialog $opt_gauge "
  Boot ...
  \Z1Arch Linux ARM\Zn
" 9 $W 0

if [[ $IP ]]; then
#............................
	(
		for i in {1..10}; do
			echo "
XXX
$(( i * 10 ))

  Ping Arch Linux ARM ...
  \Z1$IP\Zn
XXX"
			pingIP $IP && break || sleep 2
		done
	) | dialog $opt_gauge '' 9 $W 0
	if pingIP $IP; then
#............................
		dialog $opt_info "
  SSH Arch Linux ARM ...
  @ \Z1$IP\Zn
" 9 $W
		create_ros $IP
	else
		dialog.scanIP "\Z1Assigned IP\Zn not found: $IP"
	fi
else
	scanIP
fi
