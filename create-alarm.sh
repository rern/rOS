#!/bin/bash

dialog.download() {
#........................
	( wget -O $file $url/$file 2>&1 \
		| stdbuf -o0 awk '/[.] +[0-9][0-9]?[0-9]?%/ { \
			print "XXX\n "substr($0,63,3)
			print "\\n Download ..."
			print "\\n \\Z1'$file'\\Zn"
			print "\\n Time left: "substr($0,74,5)"\nXXX" }' ) \
		| dialog $opt_guage "
 Connecting ...
" 9 $W
	verifyMD5
}
list_features="\
BlueALSA   - Bluetooth audio              | bluealsa bluez bluez-utils python-dbus python-gobject python-requests
CamillaDSP - Digital signal processor     | camilladsp python-websocket-client
Firefox    - Browser on RPi screen        | firefox matchbox-window-manager plymouth-lite-rbp-git upower xf86-video-fbturbo
iwd        - RPi access point             | iwd
Samba      - File sharing                 | samba
Shairport  - AirPlay renderer             | shairport-sync
Snapcast   - Synchronous multiroom player | snapcast
Spotifyd   - Spotify renderer             | spotifyd
upmpdcli   - UPnP renderer                | upmpdcli python-upnpp"
readarray -t list_check < <( sed -e 's/ *|.*//' -e 'a\on' <<< $list_features )
dialog.feature() {
#........................
	checked=$( dialog $opt_check '
 \Z1Features to install:\Zn
' 8 0 0 "${list_check[@]}" )
	features=
	while read l; do
		features+=$( sed -n "/^$l/ {s/.*|//; p}" <<< $list_features )
	done <<< $checked
#........................
	dialog $opt_yesno "
\Z1Confirm features to install:\Zn

$checked
" 0 0
	if [[ $? == 0 ]]; then
		echo $features > $BOOT/features
	else
		dialog.feature
	fi
}
dialog.scanIP() {
	dialog $opt_msg "
$@

Scan all IPs?
" 0 0 && scanIP
}
verifyMD5() {
	clear -x
	bar Verify $file ...
	curl -skLO $url/$file.md5
	[[ $? != 0 ]] && dialog.retry 'Download *.md5 failed.' && verifyMD5
	md5sum -c $file.md5 && return 0
#----------------------------------------------------------------------------
	rm $file
	dialog.download
}

for cmd in bsdtar dialog nmap pv; do # required packages
	[[ ! -e /usr/bin/$cmd ]] && packages+="$cmd "
done
if [[ $packages ]]; then
	[[ -e /usr/bin/pacman ]] && pacman -Sy --noconfirm $packages || apt install -y $packages
fi

alarm_rpi=ArchLinuxARM-rpi-
https_rern='https://github.com/rern'
https_ros_main="$https_rern/rOS/raw/main"
if [[ ${BASH_SOURCE[0]} == ${0} ]]; then # not . <( ... from +R.sh
	create_alarm=1 # for dialog.sdCard
	. <( curl -sL https://github.com/rern/rOS/raw/main/common.sh )
fi
trap 'BRunmount; clear -x' EXIT
#........................
dialog.splash Arch Linux ARM
. <( curl -sL $https_ros_main/dialog_sdcard.sh ) # set $dev $part_B $part_R
if [[ ! $create_alarm ]]; then # from +R.sh
#........................
    banner Partition SD Card ...
    wipefs -a $dev
    mb_B=300
    mb_R=6400
    size_B=$(( mb_B * 2048 ))
    size_R=$(( mb_R * 2048 ))
    start_R=$(( 2048 + size_B ))
    echo "\
$part_B : start=     2048, size= $size_B, type=c
$part_R : start= $start_R, size= $size_R, type=83
" | sfdisk $dev # existing: fdisk -d /dev/sdX
    mkfs.fat -F 32 $part_B
    mkfs.ext4 -F $part_R
    fatlabel $part_B BOOT
    e2label $part_R ROOT
fi
BRfsck_mount
if [[ $create_alarm ]]; then
	read -r mp fs < <( findmnt -no target,fstype $part_B )
	[[ $( ls $mp ) ]] && err_B+=', Not empty\n'
	[[ $fs != vfat ]] && err_B+=', Not fat32\n'
	read -r mp fs < <( findmnt -no target,fstype $part_R )
	[[ $( ls $mp | grep -v lost+found ) ]] && err_R+=', Not empty\n'
	[[ $fs != ext4 ]] &&                      err_R+=', Not ext4\n'
	[[ $err_B ]] && error+="\Z1BOOT\Zn $part_B: ${err_B:2}"
	[[ $err_R ]] && error+="\Z1ROOT\Zn $part_R: ${err_R:2}"
	[[ $error ]] && dialog.error_exit "$error"
#----------------------------------------------------------------------------
fi
getData() {
	latest=$( curl -sL $https_rern/rAudio-addons/raw/main/addonslist.json | jq -r .r1.version )
#........................
	release=$( dialog $opt_input "
 \Z1r\ZnAudio release:
" 0 0 $latest )
	if ! curl -sIfo /dev/null $https_rern/rAudio/releases/tag/$release; then
		dialog.retry rAudio $release not found. && getData
		return
#----------------------------------------------------------------------------
	fi
	echo $release > $BOOT/release
#........................
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
#........................
	dialog $opt_yesno "
 RPi with \Z1pre-assigned\Zn IP?

" 0 0
	if [[ $? == 0 ]]; then
		(( sec_boot-=10 ))
#........................
		ip_assigned=$( dialog.ip 'Pre-assigned IP' )
		confirm_ip="
Assigned IP  : $ip_assigned"
	fi
#........................
	dialog $opt_yesno "
Connect \Z1Wi-Fi\Zn on boot?

" 0 0
	if [[ $? == 0 ]]; then
		(( sec_boot+=5 ))
		if [[ -e wifi ]]; then
			. <( sed -E -n '/^Security|^ESSID|^Key/ {s/^.*=/\L&/; p}' wifi )
		else
#........................
			essid=$( dialog $opt_input "
Wi-Fi - \Z1SSID\Zn:
" 0 0 $essid )
#........................
			key=$( dialog $opt_input "
Wi-Fi - \Z1Password\Zn:
" 0 0 $key )
			tput cup 0 0 && tput ed
#........................
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
#........................
	dialog $opt_yesno "
\Z1Confirm data:\Zn

Release      : $release
Raspberry Pi : $bit

BOOT path    : $BOOT
ROOT path    : $ROOT
$confirm_wifi
$confirm_ip
" 0 0
	tput cup 0 0 && tput ed
	[[ $? == 1 ]] && getData
}
scanIP() {
#........................
	dialog $opt_info "
  Scan hosts in network ...
" 5 $W
	ip_base=$( ipBase )
	lines=$( nmap -sn $ip_base* \
				| paste -sd ' \n' \
				| grep 'MAC Address:' \
				| column -t -H 1-4,6,7 \
				| sed -E -e ':a; s/\(([^)]*[^ ])  +/\(\1 /; ta' -e 's/[()]//g' \
				| tac )
#........................
	i=$( dialog.menu 'Select Raspberry Pi' "$lines" )
	[[ $? != 0 ]] && dialog.error_exit Arch Linux ARM not found.
#----------------------------------------------------------------------------
	sshRpi $( awk '/'$i'/ {print $1}' <<< $lines )
}
sshRpi() {
	ip=$1
	sed -i "/$ip/ d" ~/.ssh/known_hosts
	for i in 1 2 3; do
		ssh -tt -o StrictHostKeyChecking=no root@$ip /root/create-ros.sh && exit
#----------------------------------------------------------------------------
		sleep 3
	done
}
dialog.scanIP "Unable to SSH connect IP: \Z1$ip\Zn"

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
#........................
i=$( dialog.menu 'Package mirror server' "$list_menu" )
mirror=${list_code[i]}
[[ $mirror ]] && url=http://$mirror.mirror.archlinuxarm.org/os || url=http://os.archlinuxarm.org/os
if [[ -e $file ]]; then
#........................
	verifyMD5 && dialog $opt_info "
 Existing is the latest:
 \Z1$file\Zn
 
 No download required.
 
" 0 0
else
	dialog.download
fi
rm $file.md5
# expand
#........................
( pv -n $file \
	| bsdtar -C $ROOT -xpf - --exclude=boot/initramfs-linux-fallback.img ) 2>&1 \
	| dialog $opt_guage "
  Decompress to SD card ...
  \Z1$file\Zn
" 9 $W
sync &
Sstart=$( date +%s )
dirty=$( awk '/Dirty:/{print $2}' /proc/meminfo )
#........................
( while (( $( awk '/Dirty:/{print $2}' /proc/meminfo ) > 1000 )); do
	left=$( awk '/Dirty:/{print $2}' /proc/meminfo )
	echo $(( $(( dirty - left )) * 100 / dirty ))
	sleep 2
done ) \
	| dialog $opt_guage "
  Write remaining to SD card ...
  \Z1$file\Zn
" 9 $W
sync
# fstab
partid=( $( blkid -o value -s PARTUUID $part_B $part_R | sed 's/^/PARTUUID=/' ) )
partid_B=${partid[0]}
partid_R=${partid[1]}
echo "\
$partid_B  /boot  vfat  defaults,noatime  0  0
$partid_R  /      ext4  defaults,noatime  0  0" > $ROOT/etc/fstab
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
mv $ROOT/boot/* $BOOT
echo $cmdline > $BOOT/cmdline.txt0
echo "$config" > $BOOT/config.txt0
# wifi
if [[ $essid ]]; then
	profile=$ROOT/etc/netctl/$essid
	echo 'Interface=wlan0
Connection=wireless
IP=dhcp
ESSID="'$essid'"
Security='$security'
Key="'$key'"' > $profile
	[[ ! $security ]] && sed -E -i '/^Security|^Key/ d' "$profile"
	dir="$ROOT/etc/systemd/system/netctl@$essid.service.d"
	mkdir -p $dir
	echo "\
[Unit]
BindsTo=sys-subsystem-net-devices-wlan0.device
After=sys-subsystem-net-devices-wlan0.device" > "$dir/profile.conf"
	ln -sr $ROOT/usr/lib/systemd/system/netctl@.service "$ROOT/etc/systemd/system/multi-user.target.wants/netctl@$essid.service"
fi
# dhcpd - disable arp
echo noarp >> $ROOT/etc/dhcpcd.conf
# mirror server
[[ $mirror != 0 ]] && sed -i '/^Server/ s|//.*mirror|//'$mirror'.mirror|' $ROOT/etc/pacman.d/mirrorlist
# fix dns errors
echo DNSSEC=no >> $ROOT/etc/systemd/resolved.conf
# fix: time not sync on wlan
files=$( ls $ROOT/etc/systemd/network/* )
for file in $files; do
	! grep -q RequiredForOnline=no $file && echo '
[Link]
RequiredForOnline=no' >> $file
done
# disable wait-online
rm -r $ROOT/etc/systemd/system/network-online.target.wants
# fix: long wait login
sed -i '/^-.*pam_systemd/ s/^/#/' $ROOT/etc/pam.d/system-login
# ssh - root login, blank password
sed -i -e 's/#*\(PermitRootLogin \).*/\1yes/
' -e 's/#*\(PermitEmptyPasswords \).*/\1yes/
' $ROOT/etc/ssh/sshd_config
# set root password
id=$( awk -F':' '/^root/ {print $3}' $ROOT/etc/shadow )
sed -i "s/^root.*/root::$id::::::/" $ROOT/etc/shadow
# scripts
for f in {common,create-ros}.sh; do
	curl -sL $https_ros_main/$f -o $ROOT/root/$f
done
chmod 755 $ROOT/root/*.sh
sync && BRunmount
dialog.success Arch Linux ARM
[[ ${partid_B:0:-1} != ${partid_R:0:-1} ]] && usb=' + USB drive'
#........................
dialog $opt_msg "
	\Z1Arch Linux ARM\Zn : Ready
	\Z1SD card\Zn        : Unmounted

	  » Move SD card$usb to RPi
	  » Power on
	  » Press $btn_enter to:
		• Start boot timer
		• Create $logo rAudio
" 14 $W
#........................
( for (( i = 1; i < sec_boot; i++ )); do
	echo $(( i * 100 / sec_boot ))
	sleep 1
done ) \
	| dialog $opt_guage "
  Boot ...
  \Z1Arch Linux ARM\Zn
" 9 $W

if [[ $ip_assigned ]]; then
#........................
	( for i in {1..10}; do
		cat <<EOF
XXX
$(( i * 10 ))
\n  Ping \Z1$ip_assigned\Zn ...
\n  #$i
XXX
EOF
		ping -4 -c 1 -w 1 $ip_assigned &> /dev/null && pong=1 && break

		sleep 3
	done ) \
		| dialog $opt_guage '' 9 $W
	if [[ $pong ]]; then
		dialog $opt_info "
  SSH Arch Linux ARM ...
  @ \Z1$ip_assigned\Zn
" 9 $W
		sshRpi $ip_assigned
	else
		dialog.scanIP "\Z1Assigned IP\Zn not found: $ip_assigned"
	fi
else
	scanIP
fi
