#!/bin/bash

. <( curl -sL $https_ros_raw/$branch/common.sh )

selected() {
	grep -q $1 <<< $reset && return 0
}
dirdata=/srv/http/data
#............................
dialog.splash Reset for Image
list_reset="\
Reset MPD database
Reset user data directory
Clear package cache
Clear system log
Clear Wi-Fi connection"
readarray -t list_check < <( awk '{print $0; print "on"}' <<< $list_reset )
#............................
reset=$( dialog $opt_check '
 \Z1Tasks:\Zn
' 8 $W 0 "${list_check[@]}" )
systemctl stop mpd
dirnas=/mnt/MPD/NAS
dirusb=/mnt/MPD/USB
mount | grep $dirnas && umount -l "$dirnas/"*
mount | grep $dirusb && udevil umount -l "$dirusb/"*
clear -x
if selected database; then
	bar Reset MPD database ...
	rm -f $dirdata/mpd/*
fi
if selected directory; then
	bar Reset user data directory ...
	rm -rf /root/.cache/*
	rm -f $dirdata/{bookmarks,coverarts,lyrics,playlists}/*
	echo '{
  "playlists" : 0
, "webradio"  : '$( find -L $dirdata/webradio -type f ! -path '*/img/*' | wc -l )'
}' > $dirdata/mpd/counts
fi
if selected cache; then
	bar Clear package cache ...
	rm -f /var/cache/pacman/pkg/*
fi
if selected log; then
	bar Clear system log ...
	rm -rf /var/log/journal/*
fi
if selected connection; then
	bar Clear Bluetooth and Wi-Fi connection ...
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
bar 'rAudio reset done.

Shutdown ...

Before disconnecting power, observe \e[32;5m■\e[0m LED:
  - Stop services - Blips
  - Shutdown      - 10 steady flashes » off'
nohup sh -c 'sleep 2 && poweroff' &> /dev/null &
exit
