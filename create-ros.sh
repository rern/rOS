#!/bin/bash

trap cleanup EXIT
cleanup() {
	rm -f /var/lib/pacman/db.lck
	[[ -e $file_mirrorlist.bak ]] && mv $file_mirrorlist{.bak,}
}

[[ -e branch ]] && branch=$( < branch )
. common.sh

dir_system=/etc/systemd/system
file_mirrorlist=/etc/pacman.d/mirrorlist
features=$( < features )
release=$( < release )
sec_start=$( < sec_start )
packages='alsaequal alsa-utils cava cronie cd-discid dosfstools dtc evtest gifsicle hdparm hfsprogs
i2c-tools imagemagick inetutils iwd jq kid3-common libgpiod mmc-utils mpc mpd mpd_oled nfs-utils nginx-mainline nss-mdns
parted php-fpm python-rpi-gpio python-rplcd python-smbus2 python-websocket-client python-websockets
raspberrypi-utils sudo udevil websocat wget xorg-xset'

currentServer() {
	sed -n '1 {s|.*= ||; s|$.*|...|; p}' $file_mirrorlist
}
nextServerRetry() {
	dialog.retry "Package server not responsive.
$( currentServer )" || exit 1
#------------------------------------------------------------------------------
	if (( $( wc -l < $file_mirrorlist ) == 1 )); then
		mv $file_mirrorlist{.bak,}
		dialog.error_exit '\Z1All package servers\Zn not responsive.'
#------------------------------------------------------------------------------
	fi
	sed -i '1 d' $file_mirrorlist
	bar Switch package server...
	currentServer
	rm -f /var/lib/pacman/db.lck
	pacman -Sy
	$1
}
packageInstall() {
	pacman -S --noconfirm --needed $packages $features
	[[ $? != 0 ]] && nextServerRetry packageInstall
}
systemUpgrade() {
	pacman -Su --noconfirm
	! pacman -Qq linux-rpi &> /dev/null && pacman -S --noconfirm linux-rpi --overwrite '/boot/*' # fix: debian standard - /boot/... exists
	[[ $? != 0 ]] && nextServerRetry systemUpgrade
}

#............................
dialog.splash r A u d i o
#............................
banner Initialize Arch Linux ARM
pacman-key --init
pacman-key --populate archlinuxarm
systemctl restart systemd-timesyncd # force time sync
systemctl start systemd-random-seed # fill entropy pool (fix - Kernel entropy pool is not initialized)
#............................
banner Upgrade Arch Linux ARM
for n in amdgpu broadcom intel nvidia radeon  linux-aarch64 linux-firmware uboot-raspberrypi; do
	[[ ${n:0:1} != [lu] ]] && n="linux-firmware-$n"
	pacman -Qq $n &> /dev/null && remove+="$n "
done
pacman -Rdd --noconfirm $remove
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
# initramfs disable
dirhooks=/etc/pacman.d/hooks
mkdir -p $dirhooks
for file in linux-rpi mkinitcpio-install; do
	ln -s /dev/null $dirhooks/90-$file.hook
done
pacman -Sy
systemUpgrade
if [[ -e /boot/cmdline.txt0 ]]; then
	mv -f /boot/cmdline.txt{0,}
	mv -f /boot/config.txt{0,}
fi
# usb boot - disable sd card polling
! df | grep -q /dev/mmcblk && echo 'dtoverlay=sdtweak,poll_once' >> /boot/config.txt
#............................
banner Install Packages for rAudio
packageInstall
#............................
banner r A u d i o
mkdir -p /tmp/config
for repo in rAudio rAudio-assets rOS; do
	[[ $repo == rAudio ]] && file=$release || file=main
	curl -sL https://github.com/rern/$repo/archive/$file.tar.gz | bsdtar xvf - --strip-components=1 -C /tmp/config
done
find /tmp/config -maxdepth 1 -type f -delete
chmod -R go-wx /tmp/config
chmod -R u+rwX,go+rX /tmp/config
cp -r /tmp/config/* /
# bluetooth
if commandNotFound bluetoothctl; then
	sed -i 's/#*\(AutoEnable=\).*/\1true/' /etc/bluetooth/main.conf
else
	rm -rf $dir_system/{bluealsa,bluetooth}.service.d
	rm -f $dir_system/blue*
fi
# camilladsp
if [[ -e /usr/bin/camilladsp ]]; then
	sed -i '/^CONFIG/ s|etc|srv/http/data|' /etc/default/camilladsp
	dirconfigs=/srv/http/data/camilladsp/configs
	mkdir -p $dirconfigs
	sed -e '/  Volume:/,/type: Volume/ d
' -e '/- Volume/ d
' /etc/camilladsp/configs/camilladsp.yml > $dirconfigs/camilladsp.yml
else
	rm -f /srv/http/data/mpdconf/conf/camilladsp.conf
fi
# cava
ln -s /etc/cava.conf .config
echo VISUAL=nano >> /etc/environment
# firefox
if [[ -e /usr/bin/firefox ]]; then
	echo MOZ_USE_XINPUT2 DEFAULT=1 >> /etc/security/pam_env.conf # fix touch scroll
	chmod 775 /etc/X11/xorg.conf.d                               # fix permission for rotate file
	mv /usr/share/X11/xorg.conf.d/{10,45}-evdev.conf             # reorder
	timeout 1 firefox --headless &> /dev/null                    # init .mozilla/firefox
	systemctl disable getty@tty1                                 # disable login prompt
	systemctl enable bootsplash localbrowser
else
	rm -f $dir_system/{bootsplash,localbrowser}*
fi
# iwd
if [[ -e /usr/bin/iwctl ]]; then
	mkdir -p /var/lib/iwd/ap
	echo "\
[Security]
Passphrase=raudioap

[IPv4]
Address=192.168.5.1
" > /var/lib/iwd/ap/rAudio.ap
	groupadd netdev # fix: group for iwd
else
	rm -f /etc/iwd/main.conf
fi
# mpd
chsh -s /bin/bash mpd
# samba
if [[ -e /usr/bin/smbd ]]; then
	( echo ros; echo ros ) | smbpasswd -s -a root
else
	rm -rf /etc/samba
fi
# shairport-sync
if [[ ! -e /usr/bin/shairport-sync ]]; then
	rm /etc/shairport-sync.conf $dir_system/shairport.service
	rm -rf $dir_system/shairport-sync.service.d/
fi
# snapcast
if [[ -e /usr/bin/snapserver ]]; then
	sed -i '/^#bind_to_address/ a\
bind_to_address = 0.0.0.0
' /etc/snapserver.conf
fi
# spotifyd
[[ -e /usr/bin/spotifyd ]] && ln -s /lib/systemd/{user,system}/spotifyd.service
# upmpdcli
if [[ -e /usr/bin/upmpdcli ]]; then
	dir=/var/cache/upmpdcli/ohcreds
	file=$dir/credkey.pem
	mkdir -p $dir
	openssl genrsa -out $file 4096
	openssl rsa -in $file -RSAPublicKey_out
	chown upmpdcli:root $file
else
	rm -rf /etc/upmpdcli.conf $dir_system/upmpdcli.service
fi
# system
bar Set root password
chpasswd <<< root:ros
chown -R http:http /etc/fstab /etc/netctl /etc/systemd/network
sed -i -E 's/.*(PermitEmptyPasswords ).*/\1no/' /etc/ssh/sshd_config # login faster
sed -i '/^-.*pam_systemd_home/ s/^/#/' /etc/pam.d/system-auth # pam - fix freedesktop.home1.service not found (upgrade somehow overwrite)
alsactl store
if ! locale | grep -q -m1 ^LANG=C.UTF-8; then
	if ! grep -q ^C.UTF-8 /etc/locale.gen; then
		echo 'C.UTF-8 UTF-8' >> /etc/locale.gen
		locale-gen
	fi
	localectl set-locale LANG=C.UTF-8
fi
if [[ -e $file_mirrorlist.pacnew ]]; then
	mv $file_mirrorlist{.pacnew,}
	rm $file_mirrorlist.bak
else
	mv $file_mirrorlist{.bak,}
fi
# data - settings directories
dir_bash=/srv/http/bash
dir_settings=$dir_bash/settings
ln -sf $dir_bash/motd.sh /etc/profile.d/ # motd
echo ". $dir_bash/bashrc" >> /etc/bash.bashrc # prompt
echo "00 01 * * * $dir_settings/addons-data.sh" | crontab -
mv release /srv/http/data/addons/r1
rm -f /boot/{cmdline,config}.txt.pacnew
rm * &> /dev/null
chmod -R 755 $dir_bash
$dir_settings/system-datadefault.sh
systemctl daemon-reload
systemctl enable avahi-daemon cronie devmon@http nginx php-fpm startup websocket # default startup services
touch /boot/expand
#............................
dialog.splash "\
r A u d i o

Created successfully
\Z4$( elapsed $sec_start )\Zn
\Z1   Reboot ...\Zn"
reboot
