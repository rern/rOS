#!/bin/bash

version=1
	
trap exit INT

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

title='rAudio'
optbox=( --colors --no-shadow --no-collapse )
opt=( --backtitle "$title" ${optbox[@]} )
#----------------------------------------------------------------------------
dialog "${optbox[@]}" --infobox "

                    \Z1Arch Linux Arm\Z0
                          for
                     Raspberry Pi
" 9 58
sleep 2

if [[ $1 == nopathcheck ]]; then
	BOOT=/mnt/BOOT
	ROOT=/mnt/ROOT
	nopathcheck=1
else
	BOOT=$( mount | grep /dev.*BOOT | cut -d' ' -f3 )
	ROOT=$( mount | grep /dev.*ROOT | cut -d' ' -f3 )
	# check mounts
	[[ -z $BOOT ]] && warnings+="
BOOT not mounted"
	[[ -z $ROOT ]] && warnings+="
ROOT not mounted"
	if [[ -z $warnings  ]]; then
		# check duplicate names
		(( $( echo "$BOOT" | wc -l ) > 1 )) && warnings+="
BOOT has more than 1"
		(( $( echo "$ROOT" | wc -l ) > 1 )) && warnings+="
ROOT has more than 1"
		# check empty to prevent wrong partitions
		[[ $( ls $BOOT | grep -v 'System Volume Information\|lost+found\|features' ) ]] && warnings+="
BOOT not empty"
		[[ $( ls $ROOT | grep -v 'lost+found' ) ]] && warnings+="
ROOT not empty"
		# check fstype
		[[ $( df --output=fstype $BOOT | tail -1 ) != vfat ]] && warnings+="
BOOT not fat32"
		[[ $( df --output=fstype $ROOT | tail -1 ) != ext4 ]] && warnings+="\
ROOT not ext4"
	fi
	# partition warnings
	if [[ $warnings ]]; then
#----------------------------------------------------------------------------
		dialog "${opt[@]}" --msgbox "
\Z1Warnings:\Z0
$warnings

" 0 0
		exit
		
	fi
fi

# get build data
getData() { # --menu <message> <lines exclude menu box> <0=autoW dialog> <0=autoH menu>
	if [[ -z $nopathcheck ]]; then
#----------------------------------------------------------------------------
		dialog "${opt[@]}" --yesno "
Confirm \Z1SD card\Z0 path:

BOOT: \Z1$BOOT\Z0
ROOT: \Z1$ROOT\Z0

" 0 0
		[[ $? == 1 ]] && exit
		
	fi
	
	addons=( $( curl -skL https://github.com/rern/rAudio-addons/raw/main/addons-list.json \
				| grep -A2 '"r.":' \
				| sed -e 2d -e 's/[^0-9]*//g' ) )
#----------------------------------------------------------------------------
	release=$( dialog "${opt[@]}" --output-fd 1 --nocancel --inputbox "
 \Z1r\Z0Audio $version release:
" 0 0 ${addons[1]} )
#----------------------------------------------------------------------------
	rpi=$( dialog "${opt[@]}" --output-fd 1 --nocancel --menu "
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
#----------------------------------------------------------------------------
	dialog "${opt[@]}" --yesno "
 RPi with \Z1pre-assigned\Z0 IP?

" 0 0
	if [[ $? == 0 ]]; then
#----------------------------------------------------------------------------
		assignedip=$( dialog "${opt[@]}" --output-fd 1 --nocancel --inputbox "
 \Z1Pre-assigned\Z0 IP:
" 0 0 $subip )
		[[ $rpi == 1 ]] && sboot=30 || sboot=40
		confirmassignedip="
Assigned IP  : $assignedip"
	fi
#----------------------------------------------------------------------------	
	dialog $( [[ $rpi != 3 ]] && echo --defaultno ) "${opt[@]}" --yesno "
Connect \Z1Wi-Fi\Z0 on boot?

" 0 0
	if [[ $? == 0 ]]; then
#----------------------------------------------------------------------------
		ssid=$( dialog "${opt[@]}" --output-fd 1 --nocancel --inputbox "
\Z1Wi-Fi\Z0 - SSID:
" 0 0 $ssid )
#----------------------------------------------------------------------------
		password=$( dialog "${opt[@]}" --output-fd 1 --nocancel --inputbox "
\Z1Wi-Fi\Z0 - Password:
" 0 0 $password )
#----------------------------------------------------------------------------
		wpa=$( dialog "${opt[@]}" --output-fd 1 --nocancel --menu "
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
#----------------------------------------------------------------------------
	dialog "${opt[@]}" --yesno "
\Z1Confirm data:\Z0

\Z1r\Z0Audio       : $version
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
#----------------------------------------------------------------------------
	ans=$( dialog "${opt[@]}" --output-fd 1 --nocancel --menu "
\Z1Found IP address of RPi?\Z0
" 8 30 0 \
1 'Yes' \
2 'Rescan' \
3 'Ping assigned IP' \
4 'No' )
	case $ans in
		2 ) scanIP;;
#----------------------------------------------------------------------------
		3 ) ipping=$( dialog "${opt[@]}" --output-fd 1 --nocancel --inputbox "
 Ping RPi at IP:
" 0 0 $subip )
			pingIP 5 $ipping
#----------------------------------------------------------------------------
			dialog "${opt[@]}" --msgbox "
$ping
" 15 90
			foundIP
			;;
#----------------------------------------------------------------------------
		4 ) dialog "${opt[@]}" --msgbox "
 RPi IP cannot be found.
 Try starting over again.
 
" 0 0
			clear -x && exit
			;;
	esac
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
#----------------------------------------------------------------------------
	dialog "${opt[@]}" --infobox "
  Scan hosts in network ...
  
" 5 50
	lines=$( nmap -sn $subip* \
				| grep '^Nmap scan\|^MAC' \
				| paste -sd ' \n' \
				| grep 'MAC Address' \
				| sed -e 's/Nmap.*for \|MAC Address//g' -e '/Raspberry Pi/ {s/^/\\Z1/; s/$/\\Z0/}' \
				| tac )
#----------------------------------------------------------------------------
	dialog "${opt[@]}" --msgbox "
\Z1Find IP address of Raspberry Pi:\Z0
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
		if [[ $? == 0 ]]; then
			exit
		else
			sleep 3
		fi
	done
	scanIP
}

# features
    bluez='\Z1Bluez\Z0      - Bluetooth audio'
  camilla='\Z1CamillaDSP\Z0 - Digital signal processor'
  browser='\Z1Chromium\Z0   - Browser on RPi screen'
  hostapd='\Z1hostapd\Z0    - RPi access point'
      kid='\Z1Kid3\Z0       - Metadata tag editor'
    samba='\Z1Samba\Z0      - File sharing'
shairport='\Z1Shairport\Z0  - AirPlay renderer'
 snapcast='\Z1Snapcast\Z0   - Synchronous multiroom player'
  spotify='\Z1Spotifyd\Z0   - Spotify renderer'
 upmpdcli='\Z1upmpdcli\Z0   - UPnP renderer'

selectFeatures() { # --checklist <message> <lines exclude checklist box> <0=autoW dialog> <0=autoH checklist>
#----------------------------------------------------------------------------
	select=$( dialog "${opt[@]}" --output-fd 1 --nocancel --checklist "
\Z1Select features to install:
\Z4[space] = Select / Deselect\Z0
" 9 0 0 \
1 "$bluez" on \
2 "$camilla" on \
3 "$browser" on \
4 "$hostapd" on \
5 "$kid" on \
6 "$samba" on \
7 "$shairport" on \
8 "$snapcast" on \
9 "$spotify" on \
10 "$upmpdcli" on )
	
	select=" $select "
	features=
	list=
	[[ $select == *' 1 '* ]] && features+='bluez bluez-alsa bluez-utils python-dbus python-gobject python-requests ' && list+="$bluez"$'\n'
	[[ $select == *' 2 '* ]] && features+='python-aiohttp python-jsonschema python-matplotlib python-numpy python-pip python-websockets python-websocket-client python-wheel unzip ' && list+="$camilla"$'\n'
	[[ $select == *' 3 '* ]] && features+='chromium matchbox-window-manager plymouth-lite-rbp upower xf86-input-evdev xf86-video-fbdev xf86-video-fbturbo-git xf86-video-vesa xinput_calibrator xorg-server xorg-xinit ' && list+="$browser"$'\n'
	[[ $select == *' 4 '* ]] && features+='dnsmasq hostapd ' && list+="$hostapd"$'\n'
	[[ $select == *' 5 '* ]] && features+='kid3-common ' && list+="$kid"$'\n'
	[[ $select == *' 6 '* ]] && features+='samba ' && list+="$samba"$'\n'
	[[ $select == *' 7 '* ]] && features+='shairport-sync ' && list+="$shairport"$'\n'
	[[ $select == *' 8 '* ]] && features+='snapcast ' && list+="$snapcast"$'\n'
	[[ $select == *' 9 '* ]] && features+='spotifyd ' && list+="$spotify"$'\n'
	[[ $select == *' 10 '* ]] && features+='upmpdcli ' && list+="$upmpdcli"$'\n'
}
selectFeatures

[[ -z $list ]] && list=(none)
#----------------------------------------------------------------------------
dialog "${opt[@]}" --yesno "
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
							| grep . \
							| sed -n '/### A/,$ p' \
							| sed 's/ (not Austria\!)//; s/.mirror.*//; s|.*//||' )
clist=( 0 'Auto - By Geo-IP' )
codelist=( '' )
i=0
for line in "${lines[@]}"; do
	if [[ ${line:0:4} == '### ' ]];then
		city=
		country=${line:4}
	elif [[ ${line:0:3} == '## ' ]];then
		city=${line:3}
	else
		[[ $city ]] && cc="$country - $city" || cc=$country
		(( i++ ))
		clist+=( $i "$cc" )
		codelist+=( $line )
	fi
done
#----------------------------------------------------------------------------
code=$( dialog "${opt[@]}" --output-fd 1 --nocancel --menu "
\Z1Package mirror server:\Z0
" 0 0 0 \
"${clist[@]}" )
mirror=${codelist[$code]}
[[ $mirror == 0 ]] && url=http://os.archlinuxarm.org/os || url=http://$mirror.mirror.archlinuxarm.org/os

echo "\
version=$version
release=$release
col=$COLUMNS
mirror=$mirror
" > $BOOT/versions

# if already downloaded, verify latest
if [[ -e $file ]]; then
#----------------------------------------------------------------------------	   
	curl -skLO $url/$file.md5 \
		| dialog "${opt[@]}" --gauge "
  Verify already downloaded file ...
" 9 50
	md5sum --quiet -c $file.md5 || rm $file
fi

# download
if [[ -e $file ]]; then
#----------------------------------------------------------------------------
	dialog "${opt[@]}" --infobox "
 Existing is the latest:
 \Z1$file\Z0
 
 No download required.
 
" 0 0
	sleep 2
else
#----------------------------------------------------------------------------
	( wget -O $file $url/$file 2>&1 \
		| stdbuf -o0 awk '/[.] +[0-9][0-9]?[0-9]?%/ { \
			print "XXX\n "substr($0,63,3)
			print "\\n Download"
			print "\\n \\Z1'$file'\\Z0"
			print "\\n Time left: "substr($0,74,5)"\nXXX" }' ) \
		| dialog "${opt[@]}" --gauge "
 Connecting ...
" 9 50
	# checksum
	curl -skLO $url/$file.md5
	if ! md5sum -c $file.md5; then
		rm $file
#----------------------------------------------------------------------------
		dialog "${opt[@]}" --msgbox "
\Z1Download incomplete!\Z0

Run \Z1./create-alarm.sh\Z0 again.

" 0 0
		exit
	fi
fi

rm $file.md5

# expand
#----------------------------------------------------------------------------
( pv -n $file \
	| bsdtar -C $ROOT -xpf - ) 2>&1 \
	| dialog "${opt[@]}" --gauge "
  Decompress
  \Z1$file\Z0 ...
" 9 50

sync &

Sstart=$( date +%s )
dirty=$( awk '/Dirty:/{print $2}' /proc/meminfo )
#----------------------------------------------------------------------------
( while (( $( awk '/Dirty:/{print $2}' /proc/meminfo ) > 1000 )); do
	left=$( awk '/Dirty:/{print $2}' /proc/meminfo )
	echo $(( $(( dirty - left )) * 100 / dirty ))
	sleep 2
done ) \
	| dialog "${opt[@]}" --gauge "
  Write to SD card
  \Z1$file\Z0 ...
" 9 50

sync

shopt -s extglob
rm -rf $ROOT/boot/dtbs/!(broadcom)/ # aarch64 - remove other drivers to save time

mv $ROOT/boot/* $BOOT &> /dev/null

# fstab
PATH=$PATH:/sbin  # Debian not include /sbin in PATH
partuuidBOOT=$( blkid | awk '/LABEL="BOOT"/ {print $NF}' | tr -d '"' )
partuuidROOT=${partuuidBOOT:0:-1}2
cat << EOF > $ROOT/etc/fstab
$partuuidBOOT  /boot  vfat  defaults,noatime  0  0
$partuuidROOT  /      ext4  defaults,noatime  0  0
EOF
# cmdline.txt, config.txt
[[ $rpi == 1 ]] && mv $BOOT/config.txt{,.backup}
cat << EOF > $BOOT/cmdline.txt
root=$partuuidROOT rw rootwait selinux=0 plymouth.enable=0 smsc95xx.turbo_mode=N dwc_otg.lpm_enable=0 ipv6.disable=1 fsck.repair=yes isolcpus=3 console=tty1
EOF
cat << EOF > $BOOT/config.txt
gpu_mem=32
initramfs initramfs-linux.img followkernel
max_usb_current=1
disable_splash=1
disable_overscan=1
dtparam=krnbt=on
dtparam=audio=on
EOF
if [[ $rpi == 1 ]]; then
	mv $BOOT/cmdline.txt{,0}
	mv $BOOT/config.txt{,0}
	mv $BOOT/config.txt{.backup,}
else
	cp $BOOT/cmdline.txt{,0}
	cp $BOOT/config.txt{,0}
fi
# wifi
if [[ $ssid ]]; then
	profile=$ROOT/etc/netctl/$ssid
	cat << EOF > $profile
Interface=wlan0
Connection=wireless
IP=dhcp
ESSID="$ssid"
Security=$wpa
Key="$password"
EOF
	[[ -z $wpa ]] && sed -i '/Security=\|Key=/ d' "$profile"
	dir="$ROOT/etc/systemd/system/netctl@$ssid.service.d"
	mkdir -p $dir
	cat << EOF > "$dir/profile.conf"
[Unit]
BindsTo=sys-subsystem-net-devices-wlan0.device
After=sys-subsystem-net-devices-wlan0.device
EOF
	ln -sr $ROOT/usr/lib/systemd/system/netctl@.service "$ROOT/etc/systemd/system/multi-user.target.wants/netctl@$ssid.service"
fi

# dhcpd - disable arp
echo noarp >> $ROOT/etc/dhcpcd.conf

# fix dns errors
echo DNSSEC=no >> $ROOT/etc/systemd/resolved.conf

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

#----------------------------------------------------------------------------
dialog "${optbox[@]}" --msgbox "

                   Arch Linux Arm
                         for
                 \Z1Raspberry Pi $rpiname\Z0
                Created successfully.
				
$( date -d@$SECONDS -u +%M:%S )
" 12 58

umount -l $BOOT
umount -l $ROOT

[[ ${partuuidBOOT:0:-3} != ${partuuidROOT:0:-3} ]] && usb=' and USB drive'
#----------------------------------------------------------------------------
dialog "${optbox[@]}" --msgbox "
\Z1Arch Linux Arm\Z0 is ready.

\Z1BOOT\Z0 and \Z1ROOT\Z0 have been unmounted.

- Move micro SD card$usb to RPi > Power on
- Press \Z1Enter\Z0 to start boot timer > IP scan

" 13 55

title='rAudio - Connect to Raspberry Pi'
opt=( --backtitle "$title" ${optbox[@]} )
#----------------------------------------------------------------------------
( for (( i = 1; i < sboot; i++ )); do
	echo $(( i * 100 / sboot ))
	sleep 1
done ) \
	| dialog "${opt[@]}" --gauge "
  Boot ...
  \Z1Arch Linux Arm\Z0
" 9 50

if [[ $assignedip ]]; then
#----------------------------------------------------------------------------
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
		| dialog "${opt[@]}" --gauge '' 9 50
	if ping -4 -c 1 -w 1 $assignedip &> /dev/null; then
		dialog "${opt[@]}" --infobox "
  SSH \Z1Arch Linux Arm\Z0 ...
  $assignedip
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
#----------------------------------------------------------------------------
rpiip=$( dialog "${opt[@]}" --output-fd 1 --cancel-label Rescan --inputbox "
\Z1Raspberry Pi IP:\Z0

" 0 0 $subip )
[[ $? == 1 ]] && scanIP

sshRpi $rpiip
