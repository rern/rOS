#!/bin/bash

BRANCH="${BRANCH:-main}"

. <( curl -sL https://github.com/rern/rOS/raw/$BRANCH/common.sh )

dirnas=/mnt/MPD/NAS
dirusb=/mnt/MPD/USB
dirdata=/srv/http/data

selected() {
	grep -q $1 <<< $reset && return 0
}
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
mount | grep $dirnas && umount -l $dirnas/*
mount | grep $dirusb && udevil umount -l $dirusb/*
clear -x
if selected database; then
	bar Reset MPD database ...
	rm -f $dirdata/mpd/*
	cat << EOF > $dirdata/mpd/counts
{
  "song"      : 0
, "playlists" : 0
, "webradio"  : $( find $dirdata/webradio -maxdepth 1 -type f | wc -l )
}
EOF
fi
if selected directory; then
	bar Reset user data directory ...
	rm -rf /root/.cache/*
	rm -f $dirdata/{bookmarks,coverarts,lyrics,playlists}/*
fi
if selected cache; then
	bar Clear package cache ...
	rm -f /var/cache/pacman/pkg/*
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
if selected log; then
	bar Clear system log ...
	rm -rf /var/log/journal/*
fi
if [[ -e /bin/firefox ]]; then
	if ! grep -q tty3 /boot/cmdline.txt; then
		sed -i 's/tty1.*/tty3 quiet loglevel=0 logo.nologo vt.global_cursor_default=0/' /boot/cmdline.txt
		systemctl disable --now getty@tty1
	fi
	systemctl enable bootsplash localbrowser
fi
bar 'rAudio reset done.

Shutdown ...

Before disconnecting power, observe \e[32;5m■\e[0m LED:
  - Stop services - Blips
  - Shutdown      - 10 steady flashes » off'

find /root -mindepth 1 -depth -exec rm -rf {} +
mkdir -p /root/.config
ln -s /etc/cava.conf /root/.config/

poweroff
