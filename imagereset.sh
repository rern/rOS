#!/bin/bash

optbox=( --colors --no-shadow --no-collapse )

col=$( tput cols )
banner() {
	echo
	def='\e[0m'
	bg='\e[44m'
    printf "$bg%*s$def\n" $col
    printf "$bg%-${col}s$def\n" "  $1"
    printf "$bg%*s$def\n" $col
}

select=$( dialog "${optbox[@]}" \
	   --output-fd 1 \
	   --checklist '\n\Z1Select tasks:\n
\Z4[space] = Select / Deselect\Z0' 9 50 0 \
			1 "Reset MPD database" on \
			2 "Reset user data directory" on \
			3 "Clear package cache" on \
			4 "Clear system log" on \
			5 "Clear Wi-Fi connection" on )

clear
[[ $? == 1 ]] && exit

select=" $select "

systemctl stop mpd
mount | grep /mnt/MPD/NAS && umount -l "/mnt/MPD/NAS/"*
mount | grep /mnt/MPD/USB && udevil umount -l "/mnt/MPD/USB/"*

if [[ $select == *' 1 '* ]]; then
	banner 'Reset MPD database ...'
	rm -f /srv/http/data/mpd/*
fi
if [[ $select == *' 2 '* ]]; then
	banner 'Reset user data directory ...'
	rm -rf /root/.cache/* /srv/http/data/tmp/*
	rm -f /srv/http/data/{bookmarks,coverarts,lyrics,mpd,playlists,webradios}/* /srv/http/data/system/gpio
	wget -qO - https://github.com/rern/rOS/raw/main/radioparadise.tar.xz | bsdtar xvf - -C /
fi
if [[ $select == *' 3 '* ]]; then
	banner 'Clear package cache ...'
	rm -f /var/cache/pacman/pkg/*
fi
if [[ $select == *' 4 '* ]]; then
	banner 'Clear system log ...'
	journalctl --rotate
	journalctl --vacuum-time=1s
fi
if [[ $select == *' 5 '* ]] && systemctl -q is-enabled netctl-auto@wlan0; then
	banner 'Clear Wi-Fi connection ...'
	systemctl disable netctl-auto@wlan0
	rm /etc/netctl/* /srv/http/data/system/netctl-* 2> /dev/null
fi

wget -q --show-progress https://github.com/archlinuxarm/PKGBUILDs/raw/master/core/pacman-mirrorlist/mirrorlist -O /etc/pacman.d/mirrorlist

banner 'Check disk ...'
fsck.fat -traw /dev/mmcblk0p1
rm -f /boot/FSCK*

dialog "${optbox[@]}" --yesno "
               \Z1r\Z0Audio reset finished.

               \Z1Shutdown\Z0 Raspberry Pi?
" 9 58

if [[ $? == 0 ]]; then
	dialog "${optbox[@]}" --infobox "

       Before power off, Make sure \Z2green\Z0 LED:
           - Blip (may take 1-2 min.)
           - Blink rapidly until stop
" 9 58
	shutdown -h now
	exit
fi
