#!/bin/bash

. <( curl -sL https://github.com/rern/rOS/raw/refs/heads/main/common.sh )

dirdata=/srv/http/data
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
mount | grep /mnt/MPD/NAS && umount -l "/mnt/MPD/NAS/"*
mount | grep /mnt/MPD/USB && udevil umount -l "/mnt/MPD/USB/"*
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
banner Check disk ...
fsck.fat -traw /dev/mmcblk0p1
rm -f /boot/FSCK*
#........................
dialog $opt_info "
                    \Z1r\ZnAudio reset finished.

                         \Z1Shutdown\Zn ...

       Before disconnecting power, observe \Z2\Zr  \ZR\Zn LED:
         - Stop all services - Blips
         - Shutdown - 10 steady flashes to completely off
" 11 65
shutdown -h now
exit
