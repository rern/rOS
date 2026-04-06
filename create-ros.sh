#!/bin/bash

trap 'START=; rm -f /var/lib/pacman/db.lck; exit 1' EXIT SIGINT

. DATA
cmdline_txt="\
root=$PARTID_R rw rootwait plymouth.enable=0 dwc_otg.lpm_enable=0 fsck.repair=yes isolcpus=3 console=tty3 \
quiet loglevel=0 logo.nologo vt.global_cursor_default=0
"
config_txt="\
disable_overscan=1
disable_splash=1
dtparam=audio=on
dtparam=sd_poll_once=on
hdmi_force_hotplug=1
max_usb_current=1
usb_max_current_enable=1
"

. common.sh

dir_config=/tmp/config
dir_hooks=/etc/pacman.d/hooks
dir_systemd=/etc/systemd/system
file_mirrorlist=/etc/pacman.d/mirrorlist

packages='alsaequal alsa-utils cava cronie cd-discid dosfstools dtc evtest
gifsicle hdparm hfsprogs i2c-tools imagemagick inetutils iwd jq kid3-common
libgpiod libupnp linux-rpi mmc-utils mpc mpd mpd_oled nfs-utils nginx-mainline nss-mdns
parted php-fpm python-rpi-gpio python-rplcd python-smbus2 python-websocket-client python-websockets
raspberrypi-utils sudo udevil websocat wget xorg-xset'

upgrade_install() {
	[[ ! $START ]] && return
#..............................................................................
#                                                           fix: debian standard - /boot/... exists
	pacman -Syyu --noconfirm --needed $packages $FEATURES --overwrite '/boot/*'
	if [[ $? != 0 ]]; then
		if (( $( wc -l < $file_mirrorlist ) == 1 )); then
			mv /tmp/mirrorlist $file_mirrorlist
#............................
			dialog.error_exit '\Z1All package servers\Zn not responsive.'
#------------------------------------------------------------------------------
		fi
		sed -i '1 d' $file_mirrorlist
		bar Package server: $( awk -F'[ $]' 'NR==1 {print $3}' $file_mirrorlist )
		sleep 1
		upgrade_install
	fi
}

#............................
dialog.splash r A u d i o
#............................
banner Initialize Arch Linux ARM
pacman-key --init
pacman-key --populate archlinuxarm
systemctl restart systemd-timesyncd # force time sync
systemctl start systemd-random-seed # fill entropy pool (fix - kernel entropy pool is not initialized)
#............................
banner Upgrade and Install Packages
for n in amdgpu broadcom intel nvidia radeon linux-aarch64 linux-firmware uboot-raspberrypi; do
	[[ ${n:0:1} != [lu] ]] && n="linux-firmware-$n"
	pacman -Qq $n &> /dev/null && remove+="$n "
done
[[ $remove ]] && pacman -Rdd --noconfirm $remove
# add +R repo
if ! grep -q '^\[+R\]' /etc/pacman.conf; then
	sed -i -e '/community/,/^$/ d
' -e '/aur/,/^$/ d
' -e '/core/ i\
[+R]\
SigLevel = Optional TrustAll\
Server = https://rern.github.io/$arch\
' /etc/pacman.conf
fi
cp $file_mirrorlist /tmp
# initramfs disable
mkdir -p $dir_hooks
for f in linux-rpi mkinitcpio-install; do
	ln -sf /dev/null $dir_hooks/90-$f.hook
done
upgrade_install
#............................
banner r A u d i o
for repo in rAudio rAudio-assets rOS; do
	case $repo in
		rAudio )        d_f=tags/$RELEASE;;
		rAudio-assets ) d_f=heads/main;;
		rOS )           d_f=heads/$BRANCH;;
	esac
	curl -sL https://github.com/rern/$repo/archive/refs/$d_f.tar.gz \
		| bsdtar xvf - --strip-components=1 -C /
done
find / -maxdepth 1 -type f -delete
# default dirs
. /srv/http/bash/settings/system-datadefault.sh
echo $RELEASE > $diraddons/r1
cat << EOF > $dirmpd/counts
{
  "song"      : 0
, "playlists" : 0
, "webradio"  : $( find $dirwebradio/ -maxdepth 1 -type f | wc -l )
}
EOF
# bluetooth
if [[ -e /bin/bluetoothctl ]]; then
	sed -i 's/#*\(AutoEnable=\).*/\1true/' /etc/bluetooth/main.conf
else
	rm -rf $dir_systemd/{bluealsa,bluetooth}.service.d
	rm -f $dir_systemd/blue*
fi
# camilladsp
if [[ -e /bin/camilladsp ]]; then
	sed -i '/^CONFIG/ s|etc|srv/http/data|' /etc/default/camilladsp
	dirconfigs=$dircamilladsp/configs
	mkdir -p $dirconfigs
	sed -e '/  Volume:/,/type: Volume/ d
' -e '/- Volume/ d
' /etc/camilladsp/configs/camilladsp.yml > $dirconfigs/camilladsp.yml
else
	rm -f $dirmpdconf/conf/camilladsp.conf
fi
# cava
ln -s /etc/cava.conf /root/.config/
echo VISUAL=nano >> /etc/environment
# firefox
if [[ -e /bin/firefox ]]; then
	echo MOZ_USE_XINPUT2 DEFAULT=1 >> /etc/security/pam_env.conf # fix touch scroll
	chmod 775 /etc/X11/xorg.conf.d                               # fix permission for rotate file
	mv /usr/share/X11/xorg.conf.d/{10,45}-evdev.conf             # reorder
	firefox --headless &> /dev/null &                            # init .config/mozilla/firefox/...
	for i in {0..5}; do
		sleep 1
		[[ $( find /root -type d -path '/root/*mozilla' ) ]] && pkill firefox && break
	done
	systemctl disable getty@tty1                                 # disable login prompt
	systemctl enable bootsplash localbrowser
else
	cmdline_txt=${cmdline_txt/tty3*/tty1}
	config_txt=$( sed '/hdmi_force_hotplug/ d' <<< $config_txt )
	rm -f $dir_systemd/{bootsplash,localbrowser}*
fi
# iwd
if [[ -e /bin/iwctl ]]; then
	mkdir -p /var/lib/iwd/ap
	cat << EOF > /var/lib/iwd/ap/rAudio.ap
[Security]
Passphrase=raudioap

[IPv4]
Address=192.168.5.1
EOF
	groupadd netdev # fix: group for iwd
else
	rm -f /etc/iwd/main.conf
fi
# mpd
chsh -s /bin/bash mpd
alsactl store
# samba
if [[ -e /bin/smbd ]]; then
	( echo ros; echo ros ) | smbpasswd -s -a root
else
	rm -rf /etc/samba
fi
# shairport-sync
if [[ ! -e /bin/shairport-sync ]]; then
	rm /etc/shairport-sync.conf $dir_systemd/shairport.service
	rm -rf $dir_systemd/shairport-sync.service.d/
fi
# snapcast
if [[ -e /bin/snapclient ]]; then
	echo 'SNAPCLIENT_OPTS="--latency=800"' > /etc/default/snapclient
	sed -i '/^#bind_to_address/ a\
bind_to_address = 0.0.0.0
' /etc/snapserver.conf
fi
# spotifyd
[[ -e /bin/spotifyd ]] && ln -s /lib/systemd/{user,system}/spotifyd.service
# upmpdcli
if [[ -e /bin/upmpdcli ]]; then
	dir=/var/cache/upmpdcli/ohcreds
	file_pem=$dir/credkey.pem
	mkdir -p $dir
	openssl genrsa -out $file_pem 4096
	openssl rsa -in $file_pem -RSAPublicKey_out
	chown upmpdcli:root $file_pem
else
	rm -rf /etc/upmpdcli.conf $dir_systemd/upmpdcli.service
fi
# system
echo "00 01 * * * $dirsettings/addons-data.sh" | crontab -
echo ". $dirbash/bashrc" >> /etc/bash.bashrc # prompt
if ! locale | grep -q -m1 ^LANG=C.UTF-8; then
	if ! grep -q ^C.UTF-8 /etc/locale.gen; then
		echo 'C.UTF-8 UTF-8' >> /etc/locale.gen
		locale-gen
	fi
	localectl set-locale LANG=C.UTF-8
fi
curl -sL https://raw.githubusercontent.com/archlinuxarm/PKGBUILDs/master/core/pacman-mirrorlist/mirrorlist \
	-o /etc/pacman.d/mirrorlist
ln -sf $dirbash/motd.sh /etc/profile.d/ # motd
sed -i '/^-.*pam_systemd_home/ s/^/#/' /etc/pam.d/system-auth # fix freedesktop.home1.service not found
sed -i -E 's/^#*(PermitEmptyPasswords ).*/\1no/' /etc/ssh/sshd_config # login faster
sed -i -E 's/^#*(SystemMaxUse=)/\199M/' /etc/systemd/journald.conf
sed -i 's/#NTP=.*/NTP=pool.ntp.org/' /etc/systemd/timesyncd.conf
systemctl daemon-reload
systemctl disable systemd-homed
systemctl enable avahi-daemon cronie devmon@http nginx php-fpm startup websocket
hostnamectl set-hostname rAudio
timedatectl set-timezone UTC
# users
bar Set root password
chpasswd <<< root:ros
while read user; do
	chage -E -1 $user # set expire to none
done < <( cut -d: -f1 /etc/passwd )
usermod -a -G root http # add user http to group root to allow /dev/gpiomem access
chown -R http:http /etc/fstab /etc/netctl /etc/systemd/network
# cmdline.txt config.txt
for v in cmdline_txt config_txt; do
	echo -n "${!v}" > /boot/${v/_/.}
done
rm -f /boot/*.pacnew
touch /boot/expand
#............................
dialog.splash "\
r A u d i o

Created successfully
\Z4$( date -d@$(( $( date +%s ) - $START )) -u +%M:%S )\Zn
\Z1   Reboot ...\Zn"
# reset all data
rm -rf /var/log/journal/*
find . -mindepth 1 -delete
cp /etc/skel/.* .
reboot
