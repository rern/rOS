#!/bin/bash

trap exit INT

. common.sh

# required packages
if [[ -e /usr/bin/pacman ]]; then
	[[ ! -e /usr/bin/bsdtar ]] && packages+='bsdtar '
	[[ ! -e /usr/bin/dialog ]] && packages+='dialog '
	[[ ! -e /usr/bin/nmap ]] && packages+='nmap '
	[[ ! -e /usr/bin/pv ]] && packages+='pv '
	[[ $packages ]] && pacman -Sy --noconfirm $packages
else
	[[ ! -e /usr/bin/bsdtar ]] && packages+='bsdtar libarchive-tools '
	[[ ! -e /usr/bin/dialog ]] && packages+='dialog '
	[[ ! -e /usr/bin/nmap ]] && packages+='nmap '
	[[ ! -e /usr/bin/pv ]] && packages+='pv '
	[[ $packages ]] && apt install -y $packages
fi
#----------------------------------------------------------------------------
dialog $opt_info "

                    \Z1Arch Linux Arm\Z0
                          for
                     Raspberry Pi
" 9 58
sleep 2
nopathcheck=$1
if [[ $nopathcheck ]]; then
	BOOT=/mnt/BOOT
	ROOT=/mnt/ROOT
else
	BOOT=( $( mount | awk '/dev.*BOOT / {print $1" "$3" "$5}' ) ) # source mountpoint fstype
	ROOT=( $( mount | awk '/dev.*ROOT / {print $1" "$3" "$5}' ) )
	boot='\e[36BOOT\e[0m'
	root='\e[36ROOT\e[0m'
	# check mounts
	[[ ! $BOOT ]] && warnings+="$boot not mounted or found\n"
	[[ ! $ROOT ]] && warnings+="$root not mounted or found\n"
	if [[ ! $warnings  ]]; then
		# check empty to prevent wrong partitions
		[[ $( ls ${BOOT[1]} ) ]] && warnings+="$boot not empty\n"
		[[ $( ls ${ROOT[1]} ) ]] && warnings+="$root not empty\n"
		# check fstype
		[[ ${BOOT[2]} != vfat ]] && warnings+="$boot not fat32\n"
		[[ ${ROOT[2]} != ext4 ]] && warnings+="$root not ext4\n"
	fi
	[[ $warnings ]] && errorExit "Parttition:\n$warnings"
#----------------------------------------------------------------------------
fi
# get build data
getData() { # --menu <message> <lines exclude menu box> <0=autoW dialog> <0=autoH menu>
	if [[ ! $nopathcheck ]]; then # not from create.sh
#----------------------------------------------------------------------------
		dialog $opt_yesno "
Confirm \Z1SD card\Z0 path:

BOOT: \Z1$BOOT\Z0
ROOT: \Z1$ROOT\Z0

" 0 0
		[[ $? == 1 ]] && exit
#----------------------------------------------------------------------------
	fi
	latest=$( curl -sL https://github.com/rern/rAudio-addons/raw/main/addonslist.json | sed -E -n '/"rAudio"/ {n;s/.*: *"(.*)"/\1/; p}' )
#........................
	release=$( dialog $opt_input "
 \Z1r\Z0Audio release:
" 0 0 $latest )
	if ! curl -sIfo /dev/null 'https://github.com/rern/rAudio/releases/tag/'$release; then
		errorExit rAudio $release not found
#----------------------------------------------------------------------------
	fi
	echo $release > $BOOT/release
#........................
	rpi=$( dialog $opt_menu "
\Z1Raspberry Pi:\Z0
" 8 0 0 \
1 '64bit  : 4, 3, 2, Zero 2' \
2 '32bit  : 2 (BCM2836)' )
	file=ArchLinuxARM-rpi-
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
	routerip=$( ip r get 1 | head -1 | cut -d' ' -f3 )
	subip=${routerip%.*}.
#........................
	dialog $opt_yesno "
 RPi with \Z1pre-assigned\Z0 IP?

" 0 0
	if [[ $? == 0 ]]; then
#........................
		assignedip=$( dialog $opt_input "
 \Z1Pre-assigned\Z0 IP:
" 0 0 $subip )
		[[ $rpi == 1 ]] && sboot=30 || sboot=40
		confirmassignedip="
Assigned IP  : $assignedip"
	fi
#........................
	dialog $opt_yesno --defaultno "
Connect \Z1Wi-Fi\Z0 on boot?

" 0 0
	if [[ $? == 0 ]]; then
#........................
		ssid=$( dialog $opt_input "
\Z1Wi-Fi\Z0 - SSID:
" 0 0 $ssid )
#........................
		password=$( dialog $opt_input "
\Z1Wi-Fi\Z0 - Password:
" 0 0 $password )
#........................
		wpa=$( dialog $opt_menu "
\Z1Wi-Fi\Z0 -Security:
" 8 0 0 \
1 WPA \
2 WEP \
3 None )
		case $wpa in
			1 ) wpa=wpa;;
			2 ) wpa=wep;;
		esac
		confirmwifi="
SSID         : \Z1$ssid\Z0
Password     : \Z1$password\Z0
Security     : \Z1${wpa^^}\Z0"
	fi
#........................
	dialog $opt_yesno "
\Z1Confirm data:\Z0

\Z1r\Z0Audio
Release      : $release
Raspberry Pi : \Z1$rpiname\Z0

BOOT path    : \Z1$BOOT\Z0
ROOT path    : \Z1$ROOT\Z0
$confirmwifi
$confirmassignedip
" 0 0
	[[ $? == 1 ]] && getData
}
getData
foundIP() {
#........................
	ans=$( dialog $opt_menu "
\Z1Found IP address of RPi?\Z0
" 8 30 0 \
1 'Yes' \
2 'Rescan' \
3 'Ping assigned IP' \
4 'No' )
	case $ans in
		1 )
#........................
			rpiip=$( dialog $opt_input "
 RPi IP:
" 0 0 $subip )
			sshRpi $rpiip
#----------------------------------------------------------------------------
			;;
		2 ) scanIP;;
		3 )
#........................
			ipping=$( dialog $opt_input "
 Ping RPi at IP:
" 0 0 $subip )
			pingIP 5 $ipping
#........................
			dialog $opt_msg "
$ping
" 15 90
			foundIP
			;;
		4 ) errorExit 'RPi IP cannot be found.\nTry starting over again.';;
#----------------------------------------------------------------------------
	esac
}
partUUID() {
	blkid | sed -n '/LABEL="'$1'"/ {s/.* //; s/"//g; p}'
}
pingIP() {
	wait=$1
	ip=$2
	ping=$( ping -4 -c 1 -w $wait $ip | sed "s/\(. received.*loss\)/from \\\Z1\1\\\Z0/" )
	if grep -q '100% packet loss' <<< "$ping"; then
		ping+=$'\n\n'"$ip \Z1NOT\Z0 found."
	else
		ping+=$'\n\n'"$ip \Z1found\Z0."
	fi
}
scanIP() {
#........................
	dialog $opt_info "
  Scan hosts in network ...
  
" 5 50
	lines=$( nmap -sn $subip* \
				| grep '^Nmap scan\|^MAC' \
				| paste -sd ' \n' \
				| grep 'MAC Address' \
				| sed -e 's/Nmap.*for \|MAC Address//g' -e '/Raspberry Pi/ {s/^/\\Z1/; s/$/\\Z0/}' \
				| tac )
#........................
	dialog $opt_msg "
\Z1Note IP address of Raspberry Pi:\Z0
(If Raspberri Pi not listed, ping may find it.)
\Z4[arrowdown] = scrolldown\Z0

$lines

" 25 80
	foundIP
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
# features
 bluealsa='\Z1BlueALSA\Z0   - Bluetooth audio'
  camilla='\Z1CamillaDSP\Z0 - Digital signal processor'
  browser='\Z1Firefox\Z0    - Browser on RPi screen'
      iwd='\Z1iwd\Z0        - RPi access point'
    samba='\Z1Samba\Z0      - File sharing'
shairport='\Z1Shairport\Z0  - AirPlay renderer'
 snapcast='\Z1Snapcast\Z0   - Synchronous multiroom player'
  spotify='\Z1Spotifyd\Z0   - Spotify renderer'
 upmpdcli='\Z1upmpdcli\Z0   - UPnP renderer'

selectFeatures() { # --checklist <message> <lines exclude checklist box> <0=autoW dialog> <0=autoH checklist>
#........................
	select=$( dialog $opt_check "
\Z1Select features to install:
\Z4[space] = Select / Deselect\Z0
" 9 0 0 \
1 "$bluealsa"  on \
2 "$camilla"   on \
3 "$browser"   on \
4 "$iwd"       on \
5 "$samba"     on \
6 "$shairport" on \
7 "$snapcast"  on \
8 "$spotify"   on \
9 "$upmpdcli"  on )
	select=" $select "
	[[ $select == *' 1 '* ]] && list+="$bluealsa"$'\n'  && features+='bluealsa bluez bluez-utils python-dbus python-gobject python-requests '
	[[ $select == *' 2 '* ]] && list+="$camilla"$'\n'   && features+='camilladsp python-websocket-client '
	[[ $select == *' 3 '* ]] && list+="$browser"$'\n'   && features+='firefox matchbox-window-manager plymouth-lite-rbp-git upower xf86-video-fbturbo '
	[[ $select == *' 4 '* ]] && list+="$iwd"$'\n'       && features+='iwd '
	[[ $select == *' 5 '* ]] && list+="$samba"$'\n'     && features+='samba '
	[[ $select == *' 6 '* ]] && list+="$shairport"$'\n' && features+='shairport-sync '
	[[ $select == *' 7 '* ]] && list+="$snapcast"$'\n'  && features+='snapcast '
	[[ $select == *' 8 '* ]] && list+="$spotify"$'\n'   && features+='spotifyd '
	[[ $select == *' 9 '* ]] && list+="$upmpdcli"$'\n'  && features+='upmpdcli python-upnpp '
}

selectFeatures
[[ ! $list ]] && list=(none)
#........................
dialog $opt_yesno "
Confirm features to install:

$list

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
\Z1Package mirror server:\Z0
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
 \Z1$file\Z0
 
 No download required.
 
" 0 0
	sleep 2
else
#........................
	( wget -O $file $url/$file 2>&1 \
		| stdbuf -o0 awk '/[.] +[0-9][0-9]?[0-9]?%/ { \
			print "XXX\n "substr($0,63,3)
			print "\\n Download"
			print "\\n \\Z1'$file'\\Z0"
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
  \Z1$file\Z0
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
  \Z1$file\Z0
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
createrosfile=$ROOT/root/create-ros.sh
curl -skL https://github.com/rern/rOS/raw/main/create-ros.sh -o $createrosfile
chmod 755 $createrosfile
#........................
dialog $opt_msg "

                   Arch Linux Arm
                         for
                 \Z1Raspberry Pi $rpiname\Z0
                Created successfully.
				
$( date -d@$SECONDS -u +%M:%S )
" 12 58
umount -l $BOOT
umount -l $ROOT
[[ ${partuuidB:0:-3} != ${partuuidR:0:-3} ]] && usb=' and USB drive'
#........................
dialog $opt_msg "
\Z1Arch Linux Arm\Z0 is ready.

\Z1BOOT\Z0 and \Z1ROOT\Z0 have been unmounted.

- Move micro SD card$usb to RPi > Power on
- Press \Z1Enter\Z0 to start boot timer > IP scan

" 13 55
#........................
( for (( i = 1; i < sboot; i++ )); do
	echo $(( i * 100 / sboot ))
	sleep 1
done ) \
	| dialog $opt_guage "
  Boot ...
  \Z1Arch Linux Arm\Z0
" 9 50

if [[ $assignedip ]]; then
#........................
	( for i in {1..10}; do
		cat <<EOF
XXX
$(( i * 10 ))
\n  Ping \Z1$assignedip\Z0 ...
\n  #$i
XXX
EOF
		ping -4 -c 1 -w 1 $assignedip &> /dev/null && break
		sleep 3
	done ) \
		| dialog $opt_guage '' 9 50
	if ping -4 -c 1 -w 1 $assignedip &> /dev/null; then
		dialog $opt_info "
  SSH Arch Linux Arm ...
  @ \Z1$assignedip\Z0
" 9 50
		sleep 3
		sshRpi $assignedip
	else
		scanIP
	fi
else
	scanIP
fi
# connect RPi
#........................
rpiip=$( dialog $opt_input --cancel-label Rescan "
\Z1Raspberry Pi IP:\Z0

" 0 0 $subip )
[[ $? == 1 ]] && scanIP
sshRpi $rpiip
