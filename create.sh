#!/bin/bash

trap trapExit EXIT SIGINT

START=$( date +%s )
BRANCH=${1:-main}

[[ ! $logo ]] && . <( curl -sL https://github.com/rern/rOS/raw/$BRANCH/common.sh )

export PATH+=:/sbin # debian
package.required bsdtar dialog gawk jq nmap pigz pv sfdisk ssh
alias awk=gawk      # debian - awk=mawk - no sub gsub

create_ros() {
	ssh $opt_ssh root@$1 /root/create-ros.sh
	[[ $? == 255 ]] && dialog.scanIP "Unable to SSH connect: \Z1$1\Zn"
	[[ $file_del ]] && rm $file_del
}
dialog.data() {
	latest=$( curl -sL -o /dev/null -w %{url_effective} $https_raudio/releases/latest | awk -F/ '{print $NF}' )
#............................
	RELEASE=$( dialog.input '\Z1r\ZnAudio release:' $latest )
	if [[ $( curl -sfIL -o /dev/null -w '%{http_code}' $https_raudio/archive/$RELEASE.tar.gz ) != 200 ]]; then
		dialog.retry "Release: $RELEASE not found." && dialog.data
		return
	fi
#............................
	i=$( dialog.menu 'Raspberry Pi' "\
64bit  : 5, 4, 3, 2, Zero 2
32bit  : 2 (BCM2836)" )
	file=ArchLinuxARM-rpi-
	case $i in
		1 )
			file+=aarch64-
			bit=64bit
			;;
		2 )
			file+=armv7-
			bit=32bit
			;;
	esac
	file+=latest.tar.gz
	txt_confirm="
\Z1Confirm data:\Zn
Release      : $RELEASE
Raspberry Pi : $bit
"
#............................
	dialog $opt_yesno "
 RPi with \Z1pre-assigned\Zn IP?

" 0 0
	if [[ $? == 0 ]]; then
#............................
		ip=$( dialog.ip 'Pre-assigned IP' $ip )
		txt_confirm+="
Assigned IP  : $ip"
	fi
#............................
	dialog $opt_yesno "
Connect \Z1Wi-Fi\Zn on boot?

" 0 0
	if [[ $? == 0 ]]; then
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
	url_file=http://os.archlinuxarm.org/os/$file
	if [[ $( curl -sfILo /dev/null -w %{http_code} $url_file ) != 200 ]]; then
		dialog.retry "URL: $url_file not ready." && dialog.data
		return
	fi
	if [[ ! $( stat -f -c %T $PWD ) =~ ^(overlayfs|ramfs|tmpfs)$ ]]; then
		file_gib=$( curl -sfIL $url_file \
						| awk '/^Content-Length/ {val=$2} END {printf "(%.2f GiB)", val/1073741824}' )
#............................
		dialog --defaultno $opt_yesno "
 Keep file once done?
 \Z1$file\Zn
 $file_gib

" 0 0 && keep=Yes || keep=No
		[[ $keep == No ]] && file_del=$PWD/$file
		txt_confirm+="

Keep file    : $keep"
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

					eta = substr( $11, length( $11 ) - 4 )
					s = $7
					num = substr( s, 1, length( s ) - 1 )
					unit = substr( s, length( s ) )
					if ( unit == "k" && num > 1023 ) speed = sprintf( "%.2f M", num / 1024 )
					else speed = num " " unit

					print "XXX"
					print $1
					print ""
					print "  Download ..."
					print "  \\Z1" file "\\Zn"
					print "  Time left: " eta " (" speed "iB/s)"
					print "XXX"

					fflush()
				}'
	 ) 2>&1 | dialog $opt_gauge "
  Connect ...
  \Z1$url\Zn
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
		FEATURES=
		while read l; do
			FEATURES+=$( sed -n "/^$l/ {s/.*://; p}" <<< $list_features )
		done <<< $checked
	else
		checked='(none)'
	fi
#............................
	dialog $opt_yesno "
  \Z1Confirm features to install:\Zn

$( sed 's/^/  /' <<< $checked )
" 0 0 || dialog.feature
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
		txt_select="$( kbKey ↑ ) $( kbKey ↓ ) $space_select \Z1BOOT\Zn and \Z1ROOT\Zn"
		txt_retry='Selected not both BOOT and ROOT'
		readarray -t list_target_check < <( sed -E -e 's/^..|\s*$//;' -e 'a\off' <<< $list_BR )
	else
		count=1
		opt_check_sd=$opt_check
		txt_select="$space_select $sd_usb"
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
		mp=$( findmnt -no TARGET $p ) && umount -l $mp
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
	dialog.info "
  Verify ...
  \Z1$file\Zn"
	curl -sLO $url/$file.md5
	[[ $? != 0 ]] && dialog.retry 'Download *.md5 failed.' && md5verify
	if md5sum --quiet -c $file.md5; then
#............................
		[[ $1 ]] && dialog.info "
  Existing is the latest:
  \Z1$file\Zn


 No download required."
	else
		rm $file
		dialog.retry "Verify failed:\n$file" && dialog.download
	fi
}
memBuffer() {
	awk '/^(Dirty|Writeback):/ {sum += $2} END {print sum}' /proc/meminfo
}
scanIP() {
#............................
	dialog.info '
  Scan hosts in network ...'
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

#............................
dialog.splash 'Arch Linux ARM \Z1»\Zn rAudio'
dialog.data
dialog.feature
read DEV PART_B PART_R < <( dialog.sd )
sleep 1 # fix: label ready for read
dialog.sdCard
banner Rank Servers
if [[ ! -e rate_mirrors ]]; then
	if [[ -e /usr/bin/rate_mirrors ]]; then
		ln -s /usr/bin/rate_mirrors .
	else
		url=https://github.com/westandskif/rate-mirrors/releases
		rel=$( curl -sL -o /dev/null -w %{url_effective} $url/latest | awk -F/ '{print $NF}' )
		curl -sL $url/download/$rel/rate-mirrors-$rel-$( uname -m )-unknown-linux-musl.tar.gz \
			| bsdtar xf - --strip-components=1 */rate_mirrors
	fi
fi
if [[ -e rate_mirrors ]]; then
	./rate_mirrors --allow-root --disable-comments-in-file --save mirrorlist archarm
	while read sub; do # verify file exists
		[[ $sub == mirror ]] && sub=os
		url=http://$sub.archlinuxarm.org/os
		curl -sfIo /dev/null $url/$file && break

		sed -i '1 d' mirrorlist
	done < <( sed -E 's|.*//(.*\.*mirror)\..*|\1|' mirrorlist )
	[[ ! -s mirrorlist ]] && dialog.error_exit All package servers not responsive.
fi
if [[ -e $file ]]; then
	md5verify existing
else
	dialog.download
fi
rm $file.md5
BR.mount
file_size=$( stat -c %s $file )
#............................
( # -n: force stdout in each new line -Y: no buffer (26 ETA 0:00:02 261569003.1868)
	pv -nY -s $file_size $file -F '%{progress-amount-only} %e %r' \
		| pigz -dc \
		| bsdtar xpf - -C ROOT --exclude=*fallback.img
) 2>&1 | awk -v file=$file '
			{
				if ( $1 == 100 ) exit

				eta = substr( $3, length( $3 ) - 4 )
				speed = sprintf( "%.2f", $NF / 1048576 )

				print "XXX"
				print $1
				print ""
				print "  Decompress ..."
				print "  \\Z1" file "\\Zn"
  				print "  Time left: " eta " (" speed " MiB/s)"
				print "XXX"

				fflush()
			}' \
	| dialog $opt_gauge "
  Decompress ...
  \Z1$file\Zn
" 9 $W
sleep 1
mem_buffer=$( memBuffer )
#........................
( while true; do
	left=$( memBuffer )
	(( $left < 1024 )) && echo 100 && break

	echo $(( $(( mem_buffer - left )) * 100 / mem_buffer ))
	sleep 1
done ) \
	| dialog $opt_gauge "
  Write ...
  \Z1$file\Zn
" 9 $W
sync
mv ROOT/boot/* BOOT
# fstab
read PARTID_B PARTID_R < <( blkid -o value -s PARTUUID $PART_B $PART_R | awk '{printf "PARTUUID=%s ", $0}' )
opt_fstab='defaults,noatime  0  0'
cat << EOF > ROOT/etc/fstab
$PARTID_B  /boot  vfat  $opt_fstab
$PARTID_R  /      ext4  $opt_fstab
EOF
# wifi
if [[ $essid ]]; then
	file_essid="ROOT/etc/netctl/$essid"
	cat << EOF > "$file_essid"
Interface=wlan0
Connection=wireless
IP=dhcp
ESSID="$essid"
Security=$security
Key="$key"
EOF
	[[ ! $security ]] && sed -E -i '/^Security|^Key/ d' "$file_essid"
	dir="ROOT/etc/systemd/system/netctl@$essid.service.d"
	mkdir -p "$dir"
	cat << EOF > "$dir/profile.conf"
[Unit]
BindsTo=sys-subsystem-net-devices-wlan0.device
After=sys-subsystem-net-devices-wlan0.device
EOF
	ln -sr ROOT/lib/systemd/system/netctl@.service "ROOT/etc/systemd/system/multi-user.target.wants/netctl@$essid.service"
fi
# dhcpd - disable arp
echo noarp >> ROOT/etc/dhcpcd.conf
# fix dns errors
cat << EOF >> ROOT/etc/systemd/resolved.conf
MulticastDNS=no
DNSSEC=no
EOF
# fix: time not sync on wlan
files=$( ls ROOT/etc/systemd/network/* )
for file in $files; do
	! grep -q RequiredForOnline=no $file && cat << EOF >> $file
[Link]
RequiredForOnline=no
EOF
done
# disable wait-online
rm -r ROOT/etc/systemd/system/network-online.target.wants
# fix: slow login
sed -i '/^-.*pam_systemd/ s/^/#/' ROOT/etc/pam.d/system-login
# ssh create-ros.sh without password
sed -i 's/^#*\(PermitRootLogin \).*/\1yes/
		s/^#*\(PermitEmptyPasswords \).*/\1yes/
' ROOT/etc/ssh/sshd_config
id=$( awk -F':' '/^root/ {print $3}' ROOT/etc/shadow )
sed -i "s/^root.*/root::$id::::::/" ROOT/etc/shadow
# ranked mirrorlist
[[ -e mirrorlist ]] && mv mirrorlist ROOT/etc/pacman.d/
################################################################################
# scripts
cd ROOT/root
for f in common create-ros; do
	curl -sLO $https_ros/$f.sh
done
chmod +x create-ros.sh
for v in BRANCH FEATURES PARTID_R RELEASE START; do
	DATA+="$v=\"${!v}\""$'\n'
done
echo "$DATA" > DATA
sync
BR.unmount
#............................
	dialog.splash "\
Arch Linux ARM

Created successfully"
#............................
dialog $opt_msg "
Arch Linux ARM      : Ready
SD card / USB drive : Unmounted

» \Z1Move\Zn SD card / USB drive to Raspberry Pi
» \Z1Power\Zn on
» \Z1Press\Zn $( kbKey Enter ):
	• Start boot timer
	• Create $logo rAudio
" 14 $W
#............................
(
	for (( i = 1; i < 75; i++ )); do
		ping -c 1 -W 1 $ip &> /dev/null && touch /tmp/ping_ok && break
#..............................................................................
		echo $i
		sleep 1
	done
) | dialog $opt_gauge "
  Boot ...
  \Z1Arch Linux ARM\Zn
" 9 $W
if [[ -e /tmp/ping_ok ]]; then
	rm /tmp/ping_ok
	dialog.info "
  SSH Arch Linux ARM ...
  @ \Z1$ip\Zn" # sleep 2 in function
	create_ros $ip
elif [[ $ip ]]; then
#............................
	dialog.scanIP "\Z1Assigned IP\Zn not found: $ip"
else
	scanIP
fi
