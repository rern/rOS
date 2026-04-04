#!/bin/bash

trap 'START=; rm -f /var/lib/pacman/db.lck; exit 1' EXIT

for f in BRANCH FEATURES RELEASE START; do
	declare "$f=$( < $f )"
done

. common.sh

dir_bash=/srv/http/bash
dir_config=/tmp/config
dir_data=/srv/http/data
dir_hooks=/etc/pacman.d/hooks
dir_settings=$dir_bash/settings
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
mkdir -p $dir_config
for repo in rAudio rAudio-assets rOS; do
	[[ $repo == rAudio ]] && f=$RELEASE || f=main
	curl -sL https://github.com/rern/$repo/archive/$f.tar.gz | bsdtar xvf - --strip-components=1 -C $dir_config
done
find $dir_config -maxdepth 1 -type f -delete
chmod -R go-wx $dir_config
chmod -R u+rwX,go+rX $dir_config
cp -r $dir_config/* /
chmod -R 755 $dir_bash
$dir_settings/system-datadefault.sh
mv /root/RELEASE $dir_data/addons/r1
webradio=$( find $dir_data/webradio/ -maxdepth 1 -type f | wc -l )
cat << EOF > $dir_data/mpd/counts
{
  "song"      : 0
, "playlists" : 0
, "webradio"  : $webradio
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
	dirconfigs=$dir_data/camilladsp/configs
	mkdir -p $dirconfigs
	sed -e '/  Volume:/,/type: Volume/ d
' -e '/- Volume/ d
' /etc/camilladsp/configs/camilladsp.yml > $dirconfigs/camilladsp.yml
else
	rm -f $dir_data/mpdconf/conf/camilladsp.conf
fi
# cava
ln -s /etc/cava.conf /root/.config/
echo VISUAL=nano >> /etc/environment
# firefox
if [[ -e /bin/firefox ]]; then
	echo MOZ_USE_XINPUT2 DEFAULT=1 >> /etc/security/pam_env.conf # fix touch scroll
	chmod 775 /etc/X11/xorg.conf.d                               # fix permission for rotate file
	mv /usr/share/X11/xorg.conf.d/{10,45}-evdev.conf             # reorder
	timeout 1 firefox --headless &> /dev/null                    # init .mozilla/firefox
	systemctl disable getty@tty1                                 # disable login prompt
	systemctl enable bootsplash localbrowser
else
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
if [[ -e /bin/snapserver ]]; then
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
bar Set root password
chpasswd <<< root:ros
while read user; do
	chage -E -1 $user # set expire to none
done < <( cut -d: -f1 /etc/passwd )
sed -i -E 's/.*(PermitEmptyPasswords ).*/\1no/' /etc/ssh/sshd_config # login faster
chown -R http:http /etc/fstab /etc/netctl /etc/systemd/network
if ! locale | grep -q -m1 ^LANG=C.UTF-8; then
	if ! grep -q ^C.UTF-8 /etc/locale.gen; then
		echo 'C.UTF-8 UTF-8' >> /etc/locale.gen
		locale-gen
	fi
	localectl set-locale LANG=C.UTF-8
fi
ln -sf $dir_bash/motd.sh /etc/profile.d/ # motd
echo ". $dir_bash/bashrc" >> /etc/bash.bashrc # prompt
echo "00 01 * * * $dir_settings/addons-data.sh" | crontab -
alsactl store
systemctl daemon-reload
systemctl enable avahi-daemon cronie devmon@http nginx php-fpm startup websocket # default startup services
systemctl disable systemd-homed # fix freedesktop.home1.service not found
for F in CMDLINE CONFIG; do
	mv $F /boot/${F,,}.txt
done
rm -rf /boot/*.pacnew /root/*
touch /boot/expand
#............................
dialog.splash "\
r A u d i o

Created successfully
\Z4$( date -d@$(( $( date +%s ) - $START )) -u +%M:%S )\Zn
\Z1   Reboot ...\Zn"
reboot
