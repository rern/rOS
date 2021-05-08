Play Audio CD
---

```sh
# CD insert/eject events
cat << EOF > /etc/udev/rules.d/cdrom.rules
ACTION=="change", SUBSYSTEM=="block", KERNEL=="sr*", ENV{DISK_EJECT_REQUEST}=="", RUN+="/srv/http/bash/audiocd.sh"
ACTION=="change", SUBSYSTEM=="block", KERNEL=="sr*", ENV{DISK_EJECT_REQUEST}=="1", RUN+="/srv/http/bash/audiocd.sh stop"
EOF

# reload udev
udevadm control --reload-rules && udevadm trigger

# allow read for all
chmod +r /dev/sr0

# for metadata, id, tracks
pacman -Sy abcde cd-discid cdparanoia

# mpd.conf
sed -i '/plugin.*"curl"/ {n;a\
input {\
	plugin         "cdio_paranoia"\
}
}' /etc/mpd.conf
systemctl restart mpd

# get metadata
discid=$( cd-discid )
server='http://gnudb.gnudb.org/~cddb/cddb.cgi 6 owner rAudio'
data=$( cddb-tool query $server $discid )
code=$( echo "$data" | head -1 | cut -d' ' -f1 )
if (( $code == 210 )); then
  genre_album=$( echo "$data" | sed -n 2p | cut -d' ' -f1,2 )
elif (( $code == 200 )); then
  genre_album=$( echo "$data" | sed -n 2p | cut -d' ' -f2,3 )
fi
data=$( cddb-tool read $server $genre_album | grep '^.TITLE' )
artist_album=$( echo "$data" | grep ^DTITLE | cut -d= -f2- )
tracks=$( echo "$data" | grep ^TTITLE | cut -d= -f2- )

# add tracks to playlist - audiocd.sh
tracks=$( cdparanoia -sQ |& grep -P '^\s+\d+\.' | wc -l )
for i in $( seq 1 $tracks ); do
  mpc add cdda:///$i
done

# remove tracks - audiocd.sh stop
tracks=$( mpc -f %file%^%position% playlist | grep ^cdda: | cut -d^ -f2 )
for i in $tracks; do
  mpc del $i
done
