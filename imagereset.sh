#!/bin/bash

dirdata=/srv/http/data
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
	rm -f $dirdata/mpd/*
fi
if [[ $select == *' 2 '* ]]; then
	banner 'Reset user data directory ...'
	rm -rf /root/.cache/* $dirdata/tmp/*
	rm -f $dirdata/{bookmarks,coverarts,lyrics,mpd,playlists,webradios}/* $dirdata/system/gpio
	curl -skL https://github.com/rern/rAudio-addons/raw/main/webradio/radioparadise.tar.xz | bsdtar xvf - -C /
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
if [[ $select == *' 5 '* ]]; then
	banner 'Clear Bluetooth and Wi-Fi connection ...'
	rm -rf /var/lib/bluetooth/*
	readarray -t profiles <<< $( ls -p /etc/netctl | grep -v / )
	if [[ $profiles ]]; then
		for profile in "${profiles[@]}"; do
			netctl disable "$profile"
		done
		rm /etc/netctl/* 2> /dev/null
	fi
fi

if [[ ! -e $dirdata/mpd/counts ]]; then
	webradio=$( ls -1q $dirdata/webradios | wc -l )
cat << EOF > $dirdata/mpd/counts
{
  "album": 0,
  "albumartist": 0,
  "artist": 0,
  "composer": 0,
  "conductor": 0,
  "date": 0,
  "genre": 0,
  "playlists": 0,
  "latest": 0,
  "nas": 0,
  "sd": 0,
  "usb": 0,
  "song": 0,
  "webradio": $webradio
}
EOF
fi

if ! grep -q alaa.ad24.cz /etc/pacman.d/mirrorlist; then # skip on rpi 0, 1
	curl -skL https://github.com/archlinuxarm/PKGBUILDs/raw/master/core/pacman-mirrorlist/mirrorlist -o /etc/pacman.d/mirrorlist
fi

rm -rf /root/.config/chromium

banner 'Check disk ...'
fsck.fat -traw /dev/mmcblk0p1
rm -f /boot/FSCK*

dialog "${optbox[@]}" --infobox "
                    \Z1r\Z0Audio reset finished.

                         \Z1Shutdown\Z0 ...

       Before disconnecting power, observe \Z2\Zr LED \ZR\Z0:
         - Stop all services - Blips
         - Shutdown - 10 steady flashes to completely off
" 11 65
shutdown -h now
exit
