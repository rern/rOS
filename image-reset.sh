#!/bin/bash

. <( curl -sL https://github.com/rern/rOS/raw/main/common.sh )

dirdata=/srv/http/data
#........................
dialogSplash 'Reset \Z1rZnAudio for Image'
#........................
select=$( dialog $opt_check '
 \Z1Tasks:\Zn
' 9 50 0 \
	"Reset MPD database" on \
	"Reset user data directory" on \
	"Clear package cache" on \
	"Clear system log" on \
	"Clear Wi-Fi connection" on )
systemctl stop mpd
dirnas=/mnt/MPD/NAS
dirusb=/mnt/MPD/USB
mount | grep $dirnas && umount -l "$dirnas/"*
mount | grep $dirusb && udevil umount -l "$dirusb/"*
clear -x
if selected database; then
#........................
	banner Reset MPD database ...
	rm -f $dirdata/mpd/*
fi
if selected user; then
#........................
	banner Reset user data directory ...
	rm -rf /root/.cache/*
	rm -f $dirdata/{bookmarks,coverarts,lyrics,playlists}/*
	echo '{
  "playlists" : 0
, "webradio"  : '$( find -L $dirdata/webradio -type f ! -path '*/img/*' | wc -l )'
}' > $dirdata/mpd/counts
fi
if selected cache; then
#........................
	banner Clear package cache ...
	rm -f /var/cache/pacman/pkg/*
fi
if selected log; then
#........................
	banner Clear system log ...
	rm -rf /var/log/journal/*
fi
if selected Wi-Fi; then
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
banner Check Filesystems ...
fsck.fat -taw /dev/mmcblk0p1
e2fsck -p /dev/mmcblk0p2
echo -e "
$bar rAudio reset finished.

Shutdown ...

Before disconnecting power, observe \e[32;5m■\e[0m LED:
  - Stop services - Blips
  - Shutdown      - 10 steady flashes » off
"
poweroff
exit
