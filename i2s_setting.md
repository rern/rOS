I2S Setting
---

### System > I2S module:
- Populate select: `/srv/http/settings/system-i2smodules.php`
	- set `selected` and show
		- `name` = `/srv/http/data/system/audio-output`
		- `sysname` = `/srv/http/data/system/audio-aplayname`
- Selected: `/srv/http/assets/js/system.js`
	- `/boot/config.txt`
		- disable on-board audio
		- append `dtoverlay=<sysname>`
	- `sysname` > `/srv/http/data/system/audio-aplayname`
	- `name` > `/srv/http/data/system/audio-output`
	- set reboot flag

### MPD > Interface:
- Populate select: `/srv/http/settings/mpd.php`
	- get `aplayname` list with `aplay -l`
	- each card:
		- `aplayname`
		- if subdevices, append index
		- get from `/srv/http/settings/i2s/<aplayname>`
			- `mixer_control` for each card
			- if `routecmd` exists, route to subdevice
			- `extlabel` for USB DAC notify change
	- set `selected`
- Selected: (skip if USB DAC)
	- `/srv/http/assets/js/mpd.js`
		- `name` > `/srv/http/data/system/audio-output`
		- `sysname` > `/srv/http/data/system/audio-aplayname`

### Boot:
- Script: `/srv/http/settings/mpd-conf.sh`
