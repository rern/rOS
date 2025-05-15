#!/bin/bash

trap exit INT

SECONDS=0

features=$( cat /boot/features )

banner() {
	echo
	def='\e[0m'
	bg='\e[44m'
    printf "$bg%*s$def\n" $COLUMNS
    printf "$bg%-${COLUMNS}s$def\n" "  $1"
    printf "$bg%*s$def\n" $COLUMNS
}
#----------------------------------------------------------------------------
banner 'Initialize Arch Linux Arm ...'

pacman-key --init
pacman-key --populate archlinuxarm
systemctl restart systemd-timesyncd # force time sync

rm -f /var/lib/pacman/db.lck  # in case of rerun

# fill entropy pool (fix - Kernel entropy pool is not initialized)
systemctl start systemd-random-seed

title='r  A  u  d  i  o'
optbox=( --colors --no-shadow --no-collapse )
opt=( --backtitle "$title" ${optbox[@]} )
#----------------------------------------------------------------------------
dialog "${optbox[@]}" --infobox "


                        \Z1r\Z0Audio
" 9 58
sleep 2

clear -x # needed: fix stdout not scroll
#----------------------------------------------------------------------------
banner 'Upgrade system and default packages ...'

packages='alsaequal alsa-utils cava cronie cd-discid dosfstools dtc evtest gifsicle 
hdparm hfsprogs i2c-tools imagemagick inetutils iwd jq kid3-common libgpiod mmc-utils mpc mpd mpd_oled nfs-utils nginx-mainline nss-mdns 
parted php-fpm python-rpi-gpio python-rplcd python-smbus2 python-websocket-client python-websockets sudo udevil websocat wget '

if [[ -e /boot/kernel8.img ]]; then
	pacman -R --noconfirm linux-aarch64 uboot-raspberrypi
	packages+='linux-rpi raspberrypi-utils '
fi

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
	if [[ $? != 0 ]]; then
		echo -e "\e[38;5;7m\e[48;5;1m ! \e[0m System upgrade incomplete."
		exit
	fi
fi

if [[ -e /boot/cmdline.txt0 ]]; then
	mv -f /boot/cmdline.txt{0,}
	mv -f /boot/config.txt{0,}
fi
# usb boot - disable sd card polling
! df | grep -q /dev/mmcblk && echo 'dtoverlay=sdtweak,poll_once' >> /boot/config.txt
#----------------------------------------------------------------------------
banner 'Install packages ...'

pacman -S --noconfirm --needed $packages $features
if [[ $? != 0 ]]; then
	echo -e "\e[38;5;0m\e[48;5;3m ! \e[0m Retry download packages ..."
	pacman -S --noconfirm --needed $packages $features
	if [[ $? != 0 ]]; then
		echo -e "\e[38;5;7m\e[48;5;1m ! \e[0m Packages download incomplete."
		exit
		
	fi
fi
#----------------------------------------------------------------------------
banner 'Get configurations and user interface ...'

mkdir -p /tmp/config
release=$( cat /boot/release )
curl -skL https://github.com/rern/rAudio/archive/$release.tar.gz | bsdtar xvf - --strip 1 -C /tmp/config
curl -skL https://github.com/rern/rOS/archive/main.tar.gz | bsdtar xvf - --strip 1 -C /tmp/config
rm -f /tmp/config/{.*,*}

chmod -R go-wx /tmp/config
chmod -R u+rwX,go+rX /tmp/config
cp -r /tmp/config/* /
chown http:http /etc/fstab
chown -R http:http /etc/netctl /etc/systemd/network
dirbash=/srv/http/bash
chmod -R 755 $dirbash

mkdir /srv/http/assets/img/guide
curl -skL https://github.com/rern/_assets/raw/master/guide/guide.tar.xz | bsdtar xf - -C /srv/http/assets/img/guide
#---------------------------------------------------------------------------------
banner 'Configure ...'

# alsa
alsactl store
# bluetooth
if [[ -e /usr/bin/bluetoothctl ]]; then
	sed -i 's/#*\(AutoEnable=\).*/\1true/' /etc/bluetooth/main.conf
else
	rm -rf /etc/systemd/system/{bluealsa,bluetooth}.service.d
	rm -f /etc/systemd/system/blue*
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
ln -s /etc/cava.conf /root/.config/cava
# cron - for addons updates
echo "00 01 * * * $dirbash/settings/addons-data.sh" | crontab -
echo VISUAL=nano >> /etc/environment
# firefox
if [[ -e /usr/bin/firefox ]]; then
	echo MOZ_USE_XINPUT2 DEFAULT=1 >> /etc/security/pam_env.conf # fix touch scroll
	chmod 775 /etc/X11/xorg.conf.d                               # fix permission for rotate file
	mv /usr/share/X11/xorg.conf.d/{10,45}-evdev.conf             # reorder
	timeout 1 firefox --headless &> /dev/null                    # init /root/.mozilla/firefox
	profile=$( ls /root/.mozilla/firefox | grep release$ )
	echo '
user_pref("layout.css.prefers-color-scheme.content-override", 0);
user_pref("browser.display.background_color.dark", "#000000");
' > /root/.mozilla/firefox/$profile/user.js
	systemctl disable getty@tty1                                 # disable login prompt
	systemctl enable bootsplash localbrowser
else
	rm -f /etc/systemd/system/{bootsplash,localbrowser}*
	rm -rf /etc/X11
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
localectl set-locale LANG=C.utf8
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
	rm /etc/shairport-sync.conf /etc/systemd/system/shairport.service
	rm -rf /etc/systemd/system/shairport-sync.service.d/
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
	rm /etc/spotifyd.conf /etc/systemd/system/spotifyd.service
fi
# sshd
sed -i -e 's/\(PermitEmptyPasswords \).*/#\1no/
' -e 's/.*\(PrintLastLog \).*/\1no/
' /etc/ssh/sshd_config
cat << 'EOF' >> /etc/bash.bashrc # prompt
PS1='\[\e[38;5;242m\]'$HOSTNAME'\[\e[0m\]\
:\
\[\e[36m\]\w\[\e[0m\]\
 \[\e[30m\e[46m\] \$ \[\e[0m\] '

alias grepr='grep --color --exclude-dir plugin -nr'
EOF
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
	rm -rf /etc/upmpdcli.conf /etc/systemd/system/upmpdcli.service
fi
# wireless-regdom
echo 'WIRELESS_REGDOM="00"' > /etc/conf.d/wireless-regdom
# default startup services
systemctl daemon-reload
systemctl enable avahi-daemon cronie devmon@http nginx php-fpm startup websocket

#---------------------------------------------------------------------------------
# data - settings directories
$dirbash/settings/system-datadefault.sh $release
# flag expand partition
touch /boot/expand
[[ -e /boot/finish.sh ]] && . /boot/finish.sh
rm -f /boot/{features,finish.sh,release} \
	  /boot/{cmdline,config}.txt.pacnew \
	  /root/create-ros.sh
#----------------------------------------------------------------------------
dialog "${optbox[@]}" --infobox "

            \Z1r\Z0Audio created successfully.

                       \Z1Reboot\Z0 ...

$( date -d@$SECONDS -u +%M:%S )
" 9 58

shutdown -r now
