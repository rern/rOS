#!/bin/bash

trap exit INT

SECONDS=0

. /boot/versions
[[ $mirror != 0 ]] && sed -i '/^Server/ s|//.*mirror|//'$mirror'.mirror|' /etc/pacman.d/mirrorlist
features=$( cat /boot/features )

banner() {
	echo
	def='\e[0m'
	bg='\e[44m'
    printf "$bg%*s$def\n" $col
    printf "$bg%-${col}s$def\n" "  $1"
    printf "$bg%*s$def\n" $col
}
#----------------------------------------------------------------------------
banner 'Initialize Arch Linux Arm ...'

pacman-key --init
pacman-key --populate archlinuxarm

rm -f /var/lib/pacman/db.lck  # in case of rerun

# fill entropy pool (fix - Kernel entropy pool is not initialized)
systemctl start systemd-random-seed

title="rAudio $version"
optbox=( --colors --no-shadow --no-collapse )
opt=( --backtitle "$title" ${optbox[@]} )
#----------------------------------------------------------------------------
dialog "${optbox[@]}" --infobox "


                       \Z1r\Z0Audio $version
" 9 58
sleep 2

clear -x # needed: fix stdout not scroll
#----------------------------------------------------------------------------
banner 'Upgrade system and default packages ...'

packages='alsaequal alsa-utils audio_spectrum_oled cava cronie cd-discid dosfstools evtest gifsicle hdparm hfsprogs 
i2c-tools imagemagick inetutils jq mpc mpd nfs-utils nginx-mainline-pushstream nss-mdns 
parted php-fpm sshpass python-rpi-gpio python-rplcd python-smbus2 raspberrypi-stop-initramfs sudo udevil wget wiringpi'
if [[ $features == *'aiohttp'* ]]; then
	camilladsp=1
	packages+=' python-aiohttp python-jsonschema python-matplotlib python-numpy python-pip python-websockets python-websocket-client python-wheel'
fi

if [[ -e /boot/kernel8.img ]]; then
	pacman -R --noconfirm linux-aarch64 uboot-raspberrypi
	packages+=' linux-rpi raspberrypi-firmware'
fi

# add +R repo
if ! grep -q '^\[+R\]' /etc/pacman.conf; then
	sed -i '/\[core\]/ i\
[+R]\
SigLevel = Optional TrustAll\
Server = https://rern.github.io/$arch\
' /etc/pacman.conf
fi

pacman -Syu --noconfirm
if [[ $? != 0 ]]; then
	echo -e "\e[38;5;0m\e[48;5;3m ! \e[0m Retry upgrade system ..."
	pacman -Syu --noconfirm
	if [[ $? != 0 ]]; then
		echo -e "\e[38;5;7m\e[48;5;1m ! \e[0m System upgrade incomplete."
		exit
	fi
fi
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
# camilladsp
if [[ $camilladsp ]]; then
	getVersion() {
		user=HEnquist
		repo=$1
		v=$( curl -I https://github.com/$user/$repo/releases/latest \
					| awk -F'/' '/^location/ {print $NF}' \
					| sed 's/[^v.0-9]//g' )
	}
	getVersion pycamilladsp
	pip install https://github.com/HEnquist/pycamilladsp/archive/refs/tags/$v.tar.gz
	getVersion pycamilladsp-plot
	pip install https://github.com/HEnquist/pycamilladsp-plot/archive/refs/tags/$v.tar.gz
	getVersion camillagui-backend
	wget https://github.com/HEnquist/camillagui-backend/releases/download/$v/camillagui.zip
	dircamillagui=/srv/http/settings/camillagui
	unzip camillagui -d $dircamillagui
	rm camillagui.zip
	# binary
	curl -L https://github.com/rern/rAudio-addons/raw/main/CamillaDSP/camilladsp.tar.xz | bsdtar xf - -C /usr/bin
	chmod +x /usr/bin/camilladsp
	# remove git python-pip python-wheel after install
	pacman -R --noconfirm git perl-error perl-mailtools perl-timedate python-appdirs \
		python-cachecontrol python-cffi python-colorama python-contextlib2 python-cryptography python-distlib python-distro \
		python-html5lib python-more-itertools python-msgpack python-ordered-set \
		python-packaging python-pep517 python-pip python-ply python-progress python-pycparser python-pyopenssl python-pyparsing \
		python-resolvelib python-retrying python-setuptools python-six python-toml python-tomli python-webencodings python-wheel unzip
fi
#----------------------------------------------------------------------------
banner 'Get configurations and user interface ...'

curl -skLO https://github.com/rern/rOS/archive/main.tar.gz
curl -skLO https://github.com/rern/rAudio-$version/archive/$release.tar.gz
mkdir -p /tmp/config
bsdtar --strip 1 -C /tmp/config -xvf main.tar.gz
bsdtar --strip 1 -C /tmp/config -xvf $release.tar.gz
rm *.gz /tmp/config/*.* /tmp/config/.* 2> /dev/null

chmod -R go-wx /tmp/config
chmod -R u+rwX,go+rX /tmp/config
cp -r /tmp/config/* /
chown http:http /etc/fstab
chown -R http:http /etc/netctl /etc/systemd/network /srv/http
chmod 755 /srv/http/* /srv/http/bash/* /srv/http/settings/*

mv -f /boot/cmdline.txt{0,}
mv -f /boot/config.txt{0,}
rm -f /boot/{cmdline,config}.txt.pacsave
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
# browser
if [[ -e /usr/bin/chromium ]]; then
	sed -i 's/\(console=\).*/\1tty3 quiet loglevel=0 logo.nologo vt.global_cursor_default=0/' /boot/cmdline.txt # boot splash
	chmod 775 /etc/X11/xorg.conf.d                   # fix permission for rotate file
	ln -sf /srv/http/bash/xinitrc /etc/X11/xinit     # startx
	mv /usr/share/X11/xorg.conf.d/{10,45}-evdev.conf # reorder
	systemctl disable getty@tty1                     # login prompt
	systemctl enable bootsplash localbrowser
	[[ $( uname -m ) == armv7l ]] && sed -i '/^chromium/ a\	--no-xshm \\' /srv/http/bash/xinitrc
else
	rm -f /etc/systemd/system/{bootsplash,localbrowser}* /etc/X11/* \
	    /srv/http/assets/img/{splah,CW,CCW,NORMAL,UD}* /srv/http/bash/xinitrc /usr/local/bin/ply-image 2> /dev/null
fi
# camilladsp - allow symlinks
if [[ $camilladsp ]]; then
	sed -i 's/"build")$/"build", follow_symlinks=True)/' $dircamillagui/backend/routes.py
	ln -s /srv/http/assets $dircamillagui/build/static/assets
fi
# cron - for addons updates
( crontab -l &> /dev/null; echo '00 01 * * * /srv/http/bash/cmd.sh addonsupdates &' ) | crontab -
# hostapd
[[ ! -e /usr/bin/hostapd ]] && rm -rf /etc/{hostapd,dnsmasq.conf}
# mpd
chsh -s /bin/bash mpd
# motd
ln -sf /srv/http/bash/motd.sh /etc/profile.d/
# pam - fix freedesktop.home1.service not found (upgrade somehow overwrite)
sed -i '/^-.*pam_systemd_home/ s/^/#/' /etc/pam.d/system-auth
# password
echo root:ros | chpasswd
# samba
[[ -e /usr/bin/smbd ]] && ( echo ros; echo ros ) | smbpasswd -s -a root
# shairport-sync - not installed
[[ ! -e /usr/bin/shairport-sync ]] && rm /etc/sudoers.d/shairport-sync /etc/systemd/system/shairport-meta.service
# spotifyd
if [[ -e /usr/bin/spotifyd ]]; then
	mv /lib/systemd/{user,system}/spotifyd.service
else
	rm /etc/spotifyd.conf
fi
# sshd
sed -i -e 's/\(PermitEmptyPasswords \).*/#\1no/
' -e 's/.*\(PrintLastLog \).*/\1no/
' /etc/ssh/sshd_config
# timesyncd - fix if no eth connection
file=$( ls /etc/systemd/network/eth* )
grep -q RequiredForOnline=no $file || echo "
[Link]
RequiredForOnline=no" >> $file
# user - set expire to none
users=$( cut -d: -f1 /etc/passwd )
for user in $users; do
	chage -E -1 $user
done
# upmpdcli - not installed
if [[ -e /usr/bin/upmpdcli ]]; then
	dir=/var/cache/upmpdcli/ohcreds
	file=$dir/credkey.pem
	mkdir -p $dir
	openssl genrsa -out $file 4096
	openssl rsa -in $file -RSAPublicKey_out
	chown upmpdcli:root $file
else
	rm -rf /etc/upmpdcli.conf /etc/systemd/system/upmpdcli.service.d
fi
# wireless-regdom
echo 'WIRELESS_REGDOM="00"' > /etc/conf.d/wireless-regdom
# default startup services
systemctl daemon-reload
systemctl enable avahi-daemon cronie devmon@http nginx php-fpm startup

#---------------------------------------------------------------------------------
# data - settings directories
/srv/http/bash/datareset.sh $version $release
# remove files and package cache
rm /boot/{features,versions} /root/create-ros.sh /var/cache/pacman/pkg/*
# usb boot - disable sd card polling
! df | grep -q /dev/mmcblk && echo 'dtoverlay=sdtweak,poll_once' >> /boot/config.txt
# expand partition
touch /boot/expand
#----------------------------------------------------------------------------
dialog "${optbox[@]}" --infobox "

            \Z1r\Z0Audio $version created successfully.

                       \Z1Reboot\Z0 ...

$( date -d@$SECONDS -u +%M:%S )
" 9 58

shutdown -r now
