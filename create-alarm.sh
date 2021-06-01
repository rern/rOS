#!/bin/bash

trap exit INT

# required packages
if [[ -e /usr/bin/pacman ]]; then
	[[ ! -e /usr/bin/bsdtar ]] && packages+='bsdtar '
	[[ ! -e /usr/bin/dialog ]] && packages+='dialog '
	[[ ! -e /usr/bin/nmap ]] && packages+='nmap '
	[[ ! -e /usr/bin/pv ]] && packages+='pv '
	[[ -n $packages ]] && pacman -Sy --noconfirm $packages
else
	[[ ! -e /usr/bin/bsdtar ]] && packages+='bsdtar libarchive-tools '
	[[ ! -e /usr/bin/dialog ]] && packages+='dialog '
	[[ ! -e /usr/bin/nmap ]] && packages+='nmap '
	[[ ! -e /usr/bin/pv ]] && packages+='pv '
	[[ -n $packages ]] && apt install -y $packages
fi

#----------------------------------------------------------------------------
title='Create Arch Linux Arm'
optbox=( --colors --no-shadow --no-collapse )
opt=( --backtitle "$title" ${optbox[@]} )

dialog "${optbox[@]}" --infobox "

                    \Z1Arch Linux Arm\Z0
                          for
                     Raspberry Pi
" 9 58
sleep 2

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
	[[ -n $( ls $BOOT | grep -v 'System Volume Information\|lost+found\|features' ) ]] && warnings+="
BOOT not empty"
	[[ -n $( ls $ROOT | grep -v 'lost+found' ) ]] && warnings+="
ROOT not empty"
	# check fstype
	[[ $( df --output=fstype $BOOT | tail -1 ) != vfat ]] && warnings+="
BOOT not fat32"
	[[ $( df --output=fstype $ROOT | tail -1 ) != ext4 ]] && warnings+="\
ROOT not ext4"
fi
# partition warnings
if [[ -n $warnings ]]; then
	dialog "${opt[@]}" --msgbox "
\Z1Warnings:\Z0
$warnings

" 0 0
	exit
fi

# version - branch
addons=( $( wget -qO - https://github.com/rern/rAudio-addons/raw/main/addons-list.json \
			| grep -A2 '"r.":' \
			| sed -e 2d -e 's/[^0-9]*//g' ) )
version=$( dialog "${opt[@]}" --output-fd 1 --inputbox "
 \Z1r\Z0Audio version:

" 0 0 ${addons[0]} )
revision=$( dialog "${opt[@]}" --output-fd 1 --inputbox "
 Revision:

" 0 0 ${addons[1]} )
branch=$( dialog "${opt[@]}" --output-fd 1 --inputbox "
 Branch:

" 0 0 main )

# get build data
getData() { # --menu <message> <lines exclude menu box> <0=autoW dialog> <0=autoH menu>
	dialog "${opt[@]}" --yesno "
\Z1Confirm path:\Z0

BOOT: \Z1$BOOT\Z0
ROOT: \Z1$ROOT\Z0

" 0 0
	[[ $? == 1 ]] && exit

	rpi=$( dialog "${opt[@]}" --output-fd 1 --menu "
\Z1Target:\Z0
" 8 0 0 \
0 'Raspberry Pi Zero' \
1 'Raspberry Pi 1' \
2 'Raspberry Pi 2' \
3 'Raspberry Pi 3' \
4 'Raspberry Pi 4' \
5 'Raspberry Pi 64bit' )
	file=ArchLinuxARM-rpi-
	case $rpi in
		0 | 1 ) rpi01=1;; 
		2 | 3 ) file+=2-;;
		4 )     file+=4-;;
		5 )     file+=aarch64-;;
	esac
	file+=latest.tar.gz
	if [[ $rpi == 0 ]]; then
		rpiname=Zero
	elif [[ $rpi == 5 ]]; then
		rpiname=64bit
	else
		rpiname=$rpi
	fi
	
	dialog $( [[ $rpi != 0 ]] && echo --defaultno ) "${opt[@]}" --yesno "
Connect \Z1Wi-Fi\Z0 on boot?

" 0 0
	if [[ $? == 0 ]]; then
		ssid=$( dialog "${opt[@]}" --output-fd 1 --inputbox "
\Z1Wi-Fi\Z0 - SSID:

" 0 0 $ssid )
		password=$( dialog "${opt[@]}" --output-fd 1 --inputbox "
\Z1Wi-Fi\Z0 - Password:

" 0 0 $password )
		wpa=$( dialog "${opt[@]}" --output-fd 1 --menu "
\Z1Wi-Fi\Z0 -Security:
" 8 0 0 \
1 WPA \
2 WEP \
3 None )
		if [[ $wpa == 1 ]]; then
			wpa=wpa
		elif [[ $wpa == 2 ]]; then
			wpa=wep
		else
			wpa=
		fi
		wifi="Wi-Fi settings
 SSID     : \Z1$ssid\Z0
 Password : \Z1$password\Z0
 Security : \Z1${wpa^^}\Z0"
	fi

	dialog "${opt[@]}" --yesno "
\Z1Confirm data:\Z0

\Z1r\Z0Audio    : $version
Revision  : $revision
Branch    : $branch
Target    : \Z1Raspberry Pi $rpiname\Z0

BOOT path : \Z1$BOOT\Z0
ROOT path : \Z1$ROOT\Z0

$wifi

" 0 0
	[[ $? == 1 ]] && getData
}
getData

echo -n "\
$version
$revision
$branch
$COLUMNS
$rpi01
" > $BOOT/versions

# features
  audiocd='\Z1Audio CD\Z0  - Play audio CD'
    bluez='\Z1Bluez\Z0     - Bluetooth audio'
 chromium='\Z1Chromium\Z0  - Browser on RPi screen'
  hostapd='\Z1hostapd\Z0   - RPi access point'
      kid='\Z1Kid3\Z0      - Metadata tag editor'
    samba='\Z1Samba\Z0     - File sharing'
shairport='\Z1Shairport\Z0 - AirPlay renderer'
 snapcast='\Z1Snapcast\Z0  - Synchronous multiroom player'
  spotify='\Z1Spotifyd\Z0  - Spotify renderer'
 upmpdcli='\Z1upmpdcli\Z0  - UPnP renderer'

if [[ $rpi == 0 || $rpi == 1 ]]; then
	chromium='Chromium  - (not for RPi Zero, 1)'
	onoffchromium=off
else
	onoffchromium=on
fi

selectFeatures() { # --checklist <message> <lines exclude checklist box> <0=autoW dialog> <0=autoH checklist>
	select=$( dialog "${opt[@]}" --output-fd 1 --checklist "
\Z1Select features to install:
\Z4[space] = Select / Deselect\Z0
" 9 0 0 \
1 "$bluez" on \
2 "$chromium" $onoffchromium \
3 "$hostapd" on \
4 "$kid" on \
5 "$samba" on \
6 "$shairport" on \
7 "$snapcast" on \
8 "$spotify" on \
9 "$upmpdcli" on )
	
	select=" $select "
	features=
	list=
	[[ $select == *' 1 '* ]] && features+='bluez bluez-alsa bluez-utils python-dbus python-gobject python-requests ' && list+="$bluez"$'\n'
	[[ $select == *' 2 '* ]] && features+='chromium matchbox-window-manager plymouth-lite-rbp upower xf86-input-evdev xf86-video-fbdev xf86-video-fbturbo xf86-video-vesa xinput_calibrator xorg-server xorg-xinit ' && list+="$chromium"$'\n'
	[[ $select == *' 3 '* ]] && features+='dnsmasq hostapd ' && list+="$hostapd"$'\n'
	[[ $select == *' 4 '* ]] && features+='kid3-common ' && list+="$kid"$'\n'
	[[ $select == *' 5 '* ]] && features+='samba ' && list+="$samba"$'\n'
	[[ $select == *' 6 '* ]] && features+='shairport-sync ' && list+="$shairport"$'\n'
	[[ $select == *' 7 '* ]] && features+='snapcast ' && list+="$snapcast"$'\n'
	[[ $select == *' 8 '* ]] && features+='spotifyd ' && list+="$spotify"$'\n'
	[[ $select == *' 9 '* ]] && features+='upmpdcli ' && list+="$upmpdcli"$'\n'
}
selectFeatures

[[ -z $list ]] && list=(none)

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
wget -q https://github.com/archlinuxarm/PKGBUILDs/raw/master/core/pacman-mirrorlist/mirrorlist \
	| dialog "${opt[@]}" --gauge "
 Get package mirror list ...
" 9 50
mirrorlist=$( grep . mirrorlist \
	| sed -n '/### A/,$ p' \
	| sed 's/ (not Austria\!)//' )
rm mirrorlist
readarray -t lines <<< "$mirrorlist"
clist=( 0 'Auto - By Geo-IP' )
url=( '' )
i=0
for line in "${lines[@]}"; do
	if [[ ${line:0:4} == '### ' ]];then
		city=
		country=${line:4}
	elif [[ ${line:0:3} == '## ' ]];then
		city=${line:3}
	else
		[[ -n $city ]] && cc="$country - $city" || cc=$country
		(( i++ ))
		clist+=( $i "$cc" )
		url+=( $( sed 's|.*//\(.*\).mirror.*|\1|' <<< $line ) )
	fi
done

code=$( dialog "${opt[@]}" --output-fd 1 --menu "
\Z1Package mirror server:\Z0
" 0 0 0 \
"${clist[@]}" )
ccode=${url[$code]}

# if already downloaded, verify latest
if [[ -e $file ]]; then
	wget -qO $file.md5 http://os.archlinuxarm.org/os/$file.md5 \
		| dialog "${opt[@]}" --gauge "
  Verify already downloaded file ...
" 9 50
	md5sum --quiet -c $file.md5 || rm $file
fi

# download
if [[ -e $file ]]; then
	dialog "${opt[@]}" --infobox "
Existing is the latest:
\Z1$file\Z0

No download required.

" 0 0
	sleep 3
else
	( wget -O $file http://os.archlinuxarm.org/os/$file 2>&1 \
		| stdbuf -o0 awk '/[.] +[0-9][0-9]?[0-9]?%/ { \
			print "XXX\n "substr($0,63,3)
			print "\\n Download"
			print "\\n \\Z1'$file'\\Z0"
			print "\\n Time left: "substr($0,74,5)"\nXXX" }' ) \
		| dialog "${opt[@]}" --gauge "
Connecting ...
" 9 50
	# checksum
	wget -qO $file.md5 http://os.archlinuxarm.org/os/$file.md5
	if ! md5sum -c $file.md5; then
		rm $file
		dialog "${opt[@]}" --msgbox "
\Z1Download incomplete!\Z0

Run \Z1./create-alarm.sh\Z0 again.

" 0 0
		exit
	fi
fi

rm $file.md5

# expand
( pv -n $file \
	| bsdtar -C $ROOT -xpf - ) 2>&1 \
	| dialog "${opt[@]}" --gauge "
  Decompress
  \Z1$file\Z0 ...
" 9 50

sync &

Sstart=$( date +%s )
dirty=$( awk '/Dirty:/{print $2}' /proc/meminfo )
( while (( $( awk '/Dirty:/{print $2}' /proc/meminfo ) > 1000 )); do
	left=$( awk '/Dirty:/{print $2}' /proc/meminfo )
	percent=$(( $(( dirty - left )) * 100 / dirty ))
	cat <<EOF
XXX
$percent
\n  Write to SD card
\n  \Z1$file\Z0 ...
XXX
EOF
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

#----------------------------------------------------------------------------
# fstab
PATH=$PATH:/sbin  # Debian not include /sbin in PATH
partuuidBOOT=$( blkid | awk '/LABEL="BOOT"/ {print $NF}' | tr -d '"' )
partuuidROOT=${partuuidBOOT:0:-1}2
cat << EOF > $ROOT/etc/fstab
$partuuidBOOT  /boot  vfat  defaults,noatime  0  0
$partuuidROOT  /      ext4  defaults,noatime  0  0
EOF
if [[ $rpi != 5 ]]; then
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
	if [[ $rpi == 0 ]]; then
		sed -i 's/ isolcpus=3//' $BOOT/cmdline.txt
		sed -i '1 i\
over_voltage=2\
force_turbo=1\
hdmi_drive=2' $BOOT/config.txt
	fi
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
wget -qN https://github.com/rern/rOS/raw/main/create-ros.sh -P $ROOT/root
chmod 755 $ROOT/root/create-ros.sh

# packages mirror
[[ -n $ccode ]] && sed -i '/^Server/ s|//.*mirror|//'$ccode'.mirror|' $ROOT/etc/pacman.d/mirrorlist

target="                 \Z1Raspberry Pi $rpiname\Z0"
[[ $rpi != 5 ]] && target="  $target"
dialog "${optbox[@]}" --msgbox "

                   Arch Linux Arm
                         for
$target
                Created successfully.
$( date -d@$SECONDS -u +%M:%S )
" 11 58

#----------------------------------------------------------------------------
umount -l $BOOT
umount -l $ROOT

[[ ${partuuidBOOT:0:-3} != ${partuuidROOT:0:-3} ]] && usb=' and USB drive'
[[ $rpi == 0 ]] && wait=60 || wait=30

dialog "${optbox[@]}" --msgbox "
\Z1Finish\Z0

\Z1BOOT\Z0 and \Z1ROOT\Z0 have been unmounted.

1. Move micro SD card$usb to RPi
2. Power on
3. \Z1Wait $wait seconds\Z0
4. Press \Z1Enter\Z0 to continue

" 14 55

#----------------------------------------------------------------------------
title='Connect to Raspberry Pi'
opt=( --backtitle "$title" ${optbox[@]} )

# scan ip
routerip=$( ip r get 1 | head -1 | cut -d' ' -f3 )
subip=${routerip%.*}.
scanIP() {
	dialog "${opt[@]}" --infobox "
  Scan IP address ...

" 5 50
	nmap=$( nmap -sn $subip* \
		| grep -v 'Starting\|Host is up\|Nmap done' \
		| head -n -1 \
		| tac \
		| sed 's/$/\\n/; s/Nmap.*for/IP :/; s/MAC Address/\\nMAC/; s/\(Raspberry Pi\)/\\Z1\1\\Z0/' \
		| tr -d '\n' )
	dialog "${opt[@]}" --msgbox "
\Z1Find IP address of Raspberry Pi:\Z0
(Raspberri Pi 4 may listed as Unknown)
\Z4[arrowdown] = scrolldown\Z0

$nmap

" 50 100

	dialog "${opt[@]}" --ok-label Yes --extra-button --extra-label Rescan --cancel-label No --yesno "\n
\Z1Found IP address of Raspberry Pi?\Z0
(Ping may find missing fixed IP.)
" 8 38
	ans=$?
	if [[ $ans == 3 ]]; then
		scanIP
	elif [[ $ans == 1 && -n $rescan ]]; then
		dialog "${opt[@]}" --msgbox "
Try starting over again.

" 0 0
		clear -x && exit
	fi
}
scanIP

if [[ $ans == 1 ]]; then
	dialog "${opt[@]}" --yesno "
\Z1Connect with Wi-Fi?\Z0

" 0 0
	if [[ $? == 0 ]]; then
		rescan=1
		dialog "${opt[@]}" --msgbox "
- Power off
- Connect wired LAN
- Power on
- Wait 30 seconds
- Press Enter to rescan

" 0 0
		scanIP
	else
		dialog "${opt[@]}" --msgbox "
- Power off
- Connect a monitor/TV
- Power on and observe errors
- Try starting over again

" 0 0
		clear -x && exit
	fi
fi

# connect RPi
rpiip=$( dialog "${opt[@]}" --output-fd 1 --cancel-label Rescan --inputbox "
\Z1Raspberry Pi IP:\Z0

" 0 0 $subip )
[[ $? == 1 ]] && scanIP

sed -i "/$rpiip/ d" ~/.ssh/known_hosts

ssh -tt -o StrictHostKeyChecking=no root@$rpiip /root/create-ros.sh

clear -x
