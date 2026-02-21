#!/bin/bash

wget -q https://github.com/rern/rOS/raw/refs/heads/main/common.sh
. common.sh
rm common.sh

dirdata=/srv/http/data
#........................
select=$( dialog $opt_check '\n\Z1Select tasks:\n
\Z4[space] = Select / Deselect\Z0' 9 50 0 \
			1 "Reset MPD database" on \
			2 "Reset user data directory" on \
			3 "Clear package cache" on \
			4 "Clear system log" on \
			5 "Clear Wi-Fi connection" on )
[[ $? == 1 ]] && clear -x && exit
#---------------------------------------------------------------
select=" $select "
systemctl stop mpd
mount | grep /mnt/MPD/NAS && umount -l "/mnt/MPD/NAS/"*
mount | grep /mnt/MPD/USB && udevil umount -l "/mnt/MPD/USB/"*
if [[ $select == *' 1 '* ]]; then
#........................
	banner Reset MPD database ...
	rm -f $dirdata/mpd/*
fi
if [[ $select == *' 2 '* ]]; then
#........................
	banner Reset user data directory ...
	rm -rf /root/.cache/*
	rm -f $dirdata/{bookmarks,coverarts,lyrics,playlists}/*
	echo '{
  "playlists" : 0
, "webradio"  : '$( find -L $dirdata/webradio -type f ! -path '*/img/*' | wc -l )'
}' > $dirdata/mpd/counts
fi
if [[ $select == *' 3 '* ]]; then
#........................
	banner Clear package cache ...
	rm -f /var/cache/pacman/pkg/*
fi
if [[ $select == *' 4 '* ]]; then
#........................
	banner Clear system log ...
	rm -rf /var/log/journal/*
fi
if [[ $select == *' 5 '* ]]; then
#........................
	banner Clear Bluetooth and Wi-Fi connection ...
	rm -rf /var/lib/bluetooth/*
	profiles=$( ls -1p /etc/netctl | grep -v / )
	if [[ $profiles ]]; then
		while read profile; do
			netctl disable "$profile"
		done <<< $profiles
		rm /etc/netctl/* 2> /dev/null
	fi
fi
if [[ ! -e /boot/kernel.img ]]; then # skip on rpi 0, 1
	curl -skL https://github.com/archlinuxarm/PKGBUILDs/raw/master/core/pacman-mirrorlist/mirrorlist -o /etc/pacman.d/mirrorlist
fi
rm -rf /root/.config/chromium
#........................
banner Check disk ...
fsck.fat -traw /dev/mmcblk0p1
rm -f /boot/FSCK*
#........................
dialog $opt_info "
                    \Z1r\Z0Audio reset finished.

                         \Z1Shutdown\Z0 ...

       Before disconnecting power, observe \Z2\Zr  \ZR\Z0 LED:
         - Stop all services - Blips
         - Shutdown - 10 steady flashes to completely off
" 11 65
shutdown -h now
exit
