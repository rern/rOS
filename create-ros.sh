#!/bin/bash

trap 'rm -f /var/lib/pacman/db.lck' EXIT

. common.sh

dir_system=/etc/systemd/system
features=$( < features )
release=$( < release )

retryCreate() {
	dialog.retry "$@" && ./create-ros.sh || exit
}
#............................
dialog.splash r A u d i o
SECONDS=0
#............................
banner Initialize Arch Linux ARM ...
pacman-key --init
pacman-key --populate archlinuxarm
systemctl restart systemd-timesyncd # force time sync
systemctl start systemd-random-seed # fill entropy pool (fix - Kernel entropy pool is not initialized)
#............................
banner Upgrade system and default packages ...
packages='alsaequal alsa-utils cava cronie cd-discid dosfstools dtc evtest gifsicle hdparm hfsprogs 
i2c-tools imagemagick inetutils iwd jq kid3-common libgpiod mmc-utils mpc mpd mpd_oled nfs-utils nginx-mainline nss-mdns 
parted php-fpm python-rpi-gpio python-rplcd python-smbus2 python-websocket-client python-websockets
raspberrypi-utils sudo udevil websocat wget xorg-xset'
pkgs=$( pacman -Q )
if grep -q 'linux-firmware ' <<< $pkgs; then
	remove=linux-firmware
	for n in amdgpu broadcom intel nvidia radeon; do
		remove+=" linux-firmware-$n"
	done
fi
if [[ -e /boot/kernel8.img ]]; then
	grep -q linux-aarch64 <<< $pkgs && remove+=' linux-aarch64'
	grep -q uboot-raspberrypi <<< $pkgs && remove+=' uboot-raspberrypi'
	! grep -q linux-rpi <<< $pkgs && packages+=' linux-rpi'
fi
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
pacman -Syu --noconfirm
if [[ $? != 0 ]]; then
	echo -e "\e[38;5;0m\e[48;5;3m ! \e[0m Retry upgrade system ..."
	sleep 3
	pacman -Syu --noconfirm
	[[ $? != 0 ]] && retryCreate Upgrade system incomplete.
fi
if [[ -e /boot/cmdline.txt0 ]]; then
	mv -f /boot/cmdline.txt{0,}
	mv -f /boot/config.txt{0,}
fi
# usb boot - disable sd card polling
! df | grep -q /dev/mmcblk && echo 'dtoverlay=sdtweak,poll_once' >> /boot/config.txt
#............................
banner Install packages ...
pacman -S --noconfirm --needed $packages $features
if [[ $? != 0 ]]; then
	echo -e "\e[38;5;0m\e[48;5;3m ! \e[0m Retry download packages ..."
	pacman -S --noconfirm --needed $packages $features
	[[ $? != 0 ]] && retryCreate Install packages incomplete.
fi
#............................
banner Setup rAudio ...
mkdir -p /tmp/config
curl -skL https://github.com/rern/rAudio/archive/$release.tar.gz | bsdtar xvf - --strip 1 -C /tmp/config
curl -skL https://github.com/rern/rOS/archive/main.tar.gz | bsdtar xvf - --strip 1 -C /tmp/config
rm -f /tmp/config/{.*,*} 2> /dev/null
chmod -R go-wx /tmp/config
chmod -R u+rwX,go+rX /tmp/config
cp -r /tmp/config/* /
chown http:http /etc/fstab
chown -R http:http /etc/netctl /etc/systemd/network
dirbash=/srv/http/bash
chmod -R 755 $dirbash
mkdir /srv/http/assets/img/guide
curl -skL https://github.com/rern/_assets/raw/master/guide/guide.tar.xz | bsdtar xf - -C /srv/http/assets/img/guide
# alsa
alsactl store
# bluetooth
if [[ -e /usr/bin/bluetoothctl ]]; then
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
# cron - for addons updates
echo "00 01 * * * $dirbash/settings/addons-data.sh" | crontab -
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
# initramfs disable
dirhooks=/etc/pacman.d/hooks
mkdir -p $dirhooks
for file in linux-rpi mkinitcpio-install; do
	ln -s /dev/null $dirhooks/90-$file.hook
done
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
# locale
if ! locale | grep -q -m1 ^LANG=C.UTF-8; then
	if ! grep -q ^C.UTF-8 /etc/locale.gen; then
		echo 'C.UTF-8 UTF-8' >> /etc/locale.gen
		locale-gen
	fi
	localectl set-locale LANG=C.UTF-8
fi
# mpd
chsh -s /bin/bash mpd
# motd
ln -sf $dirbash/motd.sh /etc/profile.d/
# pam - fix freedesktop.home1.service not found (upgrade somehow overwrite)
sed -i '/^-.*pam_systemd_home/ s/^/#/' /etc/pam.d/system-auth
# password
echo root:ros | chpasswd
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
if [[ -e /usr/bin/spotifyd ]]; then
	ln -s /lib/systemd/{user,system}/spotifyd.service
else
	rm /etc/spotifyd.conf $dir_system/spotifyd.service
fi
# ssh
sed -i -E 's/.*(PermitEmptyPasswords ).*/\1no/' /etc/ssh/sshd_config # connect faster
echo '. /srv/http/bash/bashrc' >> /etc/bash.bashrc # prompt
# user
users=$( cut -d: -f1 /etc/passwd )
for user in $users; do
	chage -E -1 $user # set expire to none
done
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
# wireless-regdom
echo 'WIRELESS_REGDOM="00"' > /etc/conf.d/wireless-regdom
# default startup services
systemctl daemon-reload
systemctl enable avahi-daemon cronie devmon@http nginx php-fpm startup websocket
# data - settings directories
$dirbash/settings/system-datadefault.sh $release
# system
rm -f /boot/{cmdline,config}.txt.pacnew
rm * &> /dev/null
touch /boot/expand
exit 0
