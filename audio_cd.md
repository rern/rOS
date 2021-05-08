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

# for discid, tracks count
pacman -Sy cd-discid cdparanoia

# mpd.conf
sed -i '/plugin.*"curl"/ {n;a\
input {\
	plugin         "cdio_paranoia"\
}
}' /etc/mpd.conf
systemctl restart mpd

# get metadata
server='http://gnudb.gnudb.org/~cddb/cddb.cgi?cmd=cddb'
options='hello=owner+rAudio+rAudio+1&proto=6'
discid=$( cd-discid | tr ' ' + )
query=$( curl -s "$server+query+$discid&$options" | head -2 )
code=$( echo "$query" | head -1 | cut -d' ' -f1 )
if (( $code == 210 )); then  # exact match
  genre_id=$( echo "$query" | tail -1 | cut -d' ' -f1,2 | tr ' ' + )
elif (( $code == 200 )); then
  genre_id=$( echo "$query" | tail -1 | cut -d' ' -f2,3 | tr ' ' + )
fi
if [[ -n $genre_id ]]; then
	read=$( curl -s "$server+read+$genre_id&$options" )
	artist_album=$( echo "$read" | grep ^DTITLE | cut -d= -f2- )
	tracks=$( echo "$read" | grep ^TTITLE | cut -d= -f2- )
fi

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
