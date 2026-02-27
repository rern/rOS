#!/bin/bash

# default download to: /root
trap 'boot_rootMount unmount' exit

alarm_rpi=ArchLinuxARM-rpi-
ip_base=$( ipBase )
if [[ $part_B ]] ; then
	partition_sh=$1
else
	. <( curl -sL https://github.com/rern/rOS/raw/main/common.sh )
fi
#........................
if [[ $partition_sh ]]; then
	files_alarm=$alarm_rpi*.tar.gz
	[[ ! $( ls $files_alarm ) ]] && dialog $opt_yesno "
No $files_alarm in \Z1$PWD\Zn

Continue in $PWD?

" 0 0 || exit
#----------------------------------------------------------------------------
fi
#........................
dialogSplash 'Write \Z1Arch Linux ARM\Zn'
# required packages
for cmd in bsdtar dialog nmap pv;do
	[[ ! -e /usr/bin/$cmd ]] && packages+="$cmd "
done
if [[ $packages ]]; then
	[[ -e /usr/bin/pacman ]] && pacman -Sy --noconfirm $packages || apt install -y $packages
fi
BOOT=$PWD/BOOT
ROOT=$PWD/ROOT
if [[ $part_B ]]; then
	partitions=( $part_B $part_R )
else
#........................
	dialogSDcard # set var: partitions=( /dev/sdX1 /dev/sdX2 )
	part_B=${partitions[0]}
	part_R=${partitions[1]}
fi
! mount | grep -q '/dev.*BOOT ' && boot_rootMount
src_mp_fsB=( $( mount | awk '/^'${part_B//\//\\/}'/ {print $1" "$3" "$5}' ) ) # source mountpoint fstype
src_mp_fsR=( $( mount | awk '/^'${part_R//\//\\/}'/ {print $1" "$3" "$5}' ) )
# check empty to prevent wrong partitions
[[ $( ls ${src_mp_fsB[1]} ) ]] && error+="${src_mp_fsB[0]} not empty\n"
[[ $( ls ${src_mp_fsR[1]} | grep -v lost+found ) ]] && error+="${Rsrc_mp_fsRT[0]} not empty\n"
# check fstype
[[ ${src_mp_fsB[2]} != vfat ]] && error+="${src_mp_fsB[0]} not fat32\n"
[[ ${src_mp_fsR[2]} != ext4 ]] && error+="${src_mp_fsR[0]} not ext4\n"
[[ $error ]] && errorExit "Parttition:\n$error"
#----------------------------------------------------------------------------
# get build data
getData() { # --menu <message> <lines exclude menu box> <0=autoW dialog> <0=autoH menu>
	latest=$( curl -sL https://github.com/rern/rAudio-addons/raw/main/addonslist.json | jq -r .r1.version )
#........................
	release=$( dialog $opt_input "
 \Z1r\ZnAudio release:
" 0 0 $latest )
	if ! curl -sIfo /dev/null 'https://github.com/rern/rAudio/releases/tag/'$release; then
		errorExit rAudio $release not found
#----------------------------------------------------------------------------
	fi
	echo $release > $BOOT/release
#........................
	rpi=$( dialog $opt_menu "
\Z1Raspberry Pi:\Zn
" 8 0 0 \
1 '64bit  : 5, 4, 3, 2, Zero 2' \
2 '32bit  : 2 (BCM2836)' )
	file=$alarm_rpi
	if [[ $rpi == 1 ]]; then
		file+=aarch64-
		rpiname=64bit
		sboot=45
	else
		file+=armv7-
		rpiname=32bit
		sboot=60
	fi
	file+=latest.tar.gz
#........................
	dialog $opt_yesno "
 RPi with \Z1pre-assigned\Zn IP?

" 0 0
	if [[ $? == 0 ]]; then
#........................
		ip_assigned=$( dialogIP 'Pre-assigned IP' )
		[[ $rpi == 1 ]] && sboot=30 || sboot=40
		ip_confirm="
Assigned IP  : $ip_assigned"
	fi
#........................
	dialog $opt_yesno "
Connect \Z1Wi-Fi\Zn on boot?

" 0 0
	if [[ $? == 0 ]]; then
#........................
		ssid=$( dialog $opt_input "
\Z1Wi-Fi\Zn - SSID:
" 0 0 $ssid )
#........................
		password=$( dialog $opt_input "
\Z1Wi-Fi\Zn - Password:
" 0 0 $password )
#........................
		wpa=$( dialog $opt_menu "
\Z1Wi-Fi\Zn -Security:
" 8 0 0 \
1 WPA \
2 WEP \
3 None )
		case $wpa in
			1 ) wpa=wpa;;
			2 ) wpa=wep;;
		esac
		confirmwifi="
SSID         : \Z1$ssid\Zn
Password     : \Z1$password\Zn
Security     : \Z1${wpa^^}\Zn"
	fi
#........................
	dialog $opt_yesno "
\Z1Confirm data:\Zn

\Z1r\ZnAudio
Release      : $release
Raspberry Pi : \Z1$rpiname\Zn

BOOT path    : \Z1$BOOT\Zn
ROOT path    : \Z1$ROOT\Zn
$confirmwifi
$ip_confirm
" 0 0
	[[ $? == 1 ]] && getData
}
foundIP() {
#........................
	ans=$( dialog $opt_menu "
\Z1Found IP address of Raspberry Pi?\Zn
" 8 30 0 \
1 'Yes' \
2 'Ping IP' \
3 'No' )
	case $ans in
		1 )
#........................
			ip_rpi=$( dialogIP 'Raspberry Pi IP' ) 
			sshRpi $ip_rpi
			;;
		2 )
#........................
			ip_ping=$( dialogIP 'Ping Raspberry Pi at IP' )
			ping=$( ping -4 -c 1 -w 5 $ip_ping | sed "s/\(. received.*loss\)/from \\\Z1\1\\\Zn/" )
			if grep -q '100% packet loss' <<< "$ping"; then
				ping+=$'\n\n'"$ip_ping \Z1NOT\Zn found."
			else
				ping+=$'\n\n'"$ip_ping \Z1found\Zn."
			fi
#........................
			dialog $opt_msg "
$ping
" 15 90
			foundIP
			;;
		3 ) errorExit Try starting over again;;
#----------------------------------------------------------------------------
	esac
}
partUUID() {
	blkid | sed -n '/LABEL="'$1'"/ {s/.* //; s/"//g; p}'
}
scanIP() {
#........................
	dialog $opt_info "
  Scan hosts in network ...
" 5 50
	lines=$( nmap -sn $ip_base* \
				| grep '^Nmap scan\|^MAC' \
				| paste -sd ' \n' \
				| grep 'MAC Address' \
				| sed -e 's/Nmap.*for \|MAC Address//g' -e '/Raspberry Pi/ {s/^/\\Z1/; s/$/\\Zn/}' \
				| tac )
#........................
	dialog $option --output-fd 1 --cancel-label Rescan --inputbox "
\Z1Note IP address of Raspberry Pi:\Zn
(If Raspberri Pi not listed, ping may find it.)
\Z4[arrowdown] = scrolldown\Zn

$lines
" 25 80 && foundIP || scanIP
}
sshRpi() {
	ip=$1
	sed -i "/$ip/ d" ~/.ssh/known_hosts
	for i in 1 2 3; do
		ssh -tt -o StrictHostKeyChecking=no root@$ip /root/create-ros.sh 
		[[ $? != 0 ]] && sleep 3 || exit
#----------------------------------------------------------------------------
	done
	scanIP
}

list_features="\
BlueALSA   - Bluetooth audio^bluealsa bluez bluez-utils python-dbus python-gobject python-requests
CamillaDSP - Digital signal processor^camilladsp python-websocket-client
Firefox    - Browser on RPi screen^firefox matchbox-window-manager plymouth-lite-rbp-git upower xf86-video-fbturbo
iwd        - RPi access point^iwd
Samba      - File sharing^samba
Shairport  - AirPlay renderer^shairport-sync
Snapcast   - Synchronous multiroom player^snapcast
Spotifyd   - Spotify renderer^spotifyd
upmpdcli   - UPnP renderer^upmpdcli python-upnpp"
while read l; do
	list_check+=( "${l/^*}" on )
	list_ini+=( ${l/ *} )
	list_pkg+=( "${l/*^}" )
done <<< $list_features
selectFeatures() { # --checklist <message> <lines exclude checklist box> <0=autoW dialog> <0=autoH checklist>
#........................
	selected=$( dialog $opt_check '
 \Z1Features to install:\Zn
' 8 0 0 "${list_check[@]}" )
iniL=${#list_ini[@]}
for (( i=0; i < iniL; i++ )); do
	grep -q ^${list_ini[$i]} <<< $selected && features+="${list_packages[$i]} "
done
}

getData
selectFeatures
[[ ! $list ]] && list=(none)
#........................
dialog $opt_yesno "
\Z1Confirm features to install:\Zn

$selected

" 0 0
if [[ $? == 0 ]]; then
	echo $features > $BOOT/features
else
	selectFeatures
fi
SECONDS=0
# package mirror server
readarray -t lines <<< $( curl -skL https://github.com/archlinuxarm/PKGBUILDs/raw/master/core/pacman-mirrorlist/mirrorlist \
							| sed -E -n '/^### Mirror/,$ {/^\s*$|^### Mirror/ d; s|.*//(.*)\.mirror.*|\1|; p}' )
clist=( 0 'Auto (By Geo-IP)' )
codelist=( 0 )
i=0
for line in "${lines[@]}"; do
	if [[ ${line:0:4} == '### ' ]];then
		city=
		country=${line:4}
	elif [[ ${line:0:3} == '## ' ]];then
		city=${line:3}
	else
		[[ $city ]] && cc="$country - $city" || cc=$country
		[[ $cc == $ccprev ]] && cc+=' 2'
		ccprev=$cc
		(( i++ ))
		clist+=( $i "$cc" )
		codelist+=( $line )
	fi
done
(( i++ ))
#........................
code=$( dialog $opt_menu "
\Z1Package mirror server:\Zn
" 0 0 $i \
"${clist[@]}" )
mirror=${codelist[$code]}
[[ $mirror == 0 ]] && url=http://os.archlinuxarm.org/os || url=http://$mirror.mirror.archlinuxarm.org/os
# if already downloaded, verify latest
if [[ -e $file ]]; then
#........................
	curl -skLO $url/$file.md5 \
		| dialog $opt_guage "
  Verify already downloaded file ...
" 9 50
	md5sum --quiet -c $file.md5 || rm $file
fi
# download
if [[ -e $file ]]; then
#........................
	dialog $opt_info "
 Existing is the latest:
 \Z1$file\Zn
 
 No download required.
 
" 0 0
	sleep 2
else
#........................
	( wget -O $file $url/$file 2>&1 \
		| stdbuf -o0 awk '/[.] +[0-9][0-9]?[0-9]?%/ { \
			print "XXX\n "substr($0,63,3)
			print "\\n Download ..."
			print "\\n \\Z1'$file'\\Zn"
			print "\\n Time left: "substr($0,74,5)"\nXXX" }' ) \
		| dialog $opt_guage "
 Connecting ...
" 9 50
	# checksum
	curl -skLO $url/$file.md5
	if ! md5sum -c $file.md5; then
		rm $file
		errorExit 'Download incomplete\nRun create-alarm.sh again'
#----------------------------------------------------------------------------
	fi
fi
rm $file.md5
# expand
#........................
( pv -n $file \
	| bsdtar -C $ROOT -xpf - --exclude=boot/initramfs-linux-fallback.img ) 2>&1 \
	| dialog $opt_guage "
  Decompress ...
  \Z1$file\Zn
" 9 50
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
  Write to SD card ...
  \Z1$file\Zn
" 9 50
sync
# fstab
partuuidB=$( partUUID BOOT )
partuuidR=$( partUUID ROOT )
echo "\
$partuuidB  /boot  vfat  defaults,noatime  0  0
$partuuidR  /      ext4  defaults,noatime  0  0" > $ROOT/etc/fstab
# cmdline.txt, config.txt
cmdline="root=$partuuidR rw rootwait plymouth.enable=0 dwc_otg.lpm_enable=0 fsck.repair=yes isolcpus=3 console="
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
if [[ $ssid ]]; then
	profile=$ROOT/etc/netctl/$ssid
	echo 'Interface=wlan0
Connection=wireless
IP=dhcp
ESSID="'$ssid'"
Security='$wpa'
Key="'$password'"' > $profile
	[[ ! $wpa ]] && sed -E -i '/^Security|^Key/ d' "$profile"
	dir="$ROOT/etc/systemd/system/netctl@$ssid.service.d"
	mkdir -p $dir
	echo "\
[Unit]
BindsTo=sys-subsystem-net-devices-wlan0.device
After=sys-subsystem-net-devices-wlan0.device" > "$dir/profile.conf"
	ln -sr $ROOT/usr/lib/systemd/system/netctl@.service "$ROOT/etc/systemd/system/multi-user.target.wants/netctl@$ssid.service"
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
sed -i -e 's/#\(PermitRootLogin \).*/\1yes/
' -e 's/#\(PermitEmptyPasswords \).*/\1yes/
' $ROOT/etc/ssh/sshd_config
# set root password
id=$( awk -F':' '/^root/ {print $3}' $ROOT/etc/shadow )
sed -i "s/^root.*/root::$id::::::/" $ROOT/etc/shadow
# get create-ros.sh
wget -q https://github.com/rern/rOS/raw/main/create-ros.sh -P $ROOT/root
chmod 755 $ROOT/root/create-ros.sh
boot_rootMount unmount
trap -
#........................
dialog $opt_msg "

                   Arch Linux ARM
                         for
                 \Z1Raspberry Pi $rpiname\Zn
                Created successfully.
				
$( date -d@$SECONDS -u +%M:%S )
" 12 58
[[ ${partuuidB:0:-3} != ${partuuidR:0:-3} ]] && usb=' and USB drive'
#........................
dialog $opt_msg "
\Z1Arch Linux ARM\Zn is ready.

\Z1BOOT\Zn and \Z1ROOT\Zn have been unmounted.

- Move SD card$usb to RPi » Power on
- Press \Z1Enter\Zn to start boot timer » IP scan

" 13 55
#........................
( for (( i = 1; i < sboot; i++ )); do
	echo $(( i * 100 / sboot ))
	sleep 1
done ) \
	| dialog $opt_guage "
  Boot ...
  \Z1Arch Linux ARM\Zn
" 9 50

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
		ping -4 -c 1 -w 1 $ip_assigned &> /dev/null && break
		sleep 3
	done ) \
		| dialog $opt_guage '' 9 50
	if ping -4 -c 1 -w 1 $ip_assigned &> /dev/null; then
		dialog $opt_info "
  SSH Arch Linux ARM ...
  @ \Z1$ip_assigned\Zn
" 9 50
		sleep 3
		clear -x
		sshRpi $ip_assigned
	else
		scanIP
	fi
else
	scanIP
fi
