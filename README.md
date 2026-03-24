rOS - DIY rAudio
---
Build [**rAudio**](https://github.com/rern/rAudio-1) - Audio player and renderer for Raspberry Pi

- For all **Raspberry Pi**s:
	- 64bit:
		- `4`, `3` and `2`
		- `Zero 2` cannot be used to run this DIY. Use pre-built [image file](https://github.com/rern/rAudio-1#image-files) instead.
	- 32bit:
		- `2 (BCM2836)`
	- Legacy:
		- `1` and `Zero` : Arch LinuxARM [ended ARMv6 CPU support](https://archlinuxarm.org/forum/viewtopic.php?f=3&t=15721). Use pre-built [image file](https://github.com/rern/rAudio-1#image-files) instead.
- Create **rAudio** from latest releases of [**Arch Linux ARM**](https://archlinuxarm.org/about/downloads)
- Interactive interface
- Options:
	- Pre-configure Wi-Fi connection
	- Exclude features (can be as light as possible in terms of build time and disk space)

**Procedure**
- Download and create Arch Linux ARM
- SSH to Raspberry Pi
- Create rAudio
	- Upgrade kernel and default packages
	- Install feature packages
	- Install web user interface
	- Configure
	- Setup defaults

![dialog1](https://github.com/rern/rOS/raw/main/select-hw.png)
![dialog2](https://github.com/rern/rOS/raw/main/select-features.png)

**Need**
- PC - Any Linux flavors:
	- With package manager: `apt` or `pacman`
	- Live USB can be used as well e.g,
		- [Puppy Linux](https://sourceforge.net/projects/pb-gh-releases/files/TrixiePup64Wayland_release/) - Trixie (1.2GB)
		- [Linux Mint](https://linuxmint.com/download.php) (2.9GB)
		- [Debian](https://cdimage.debian.org/debian-cd/current-live/amd64/iso-hybrid/) *(3.5GB+)*
		- Recommend: Create bootable USB drive with [Ventoy](https://www.ventoy.net) + Puppy Linux
- Raspberry Pi
- Micro SD card or USB drive

---

### Create rAudio
**Target device:**
- Option 1: Micro SD card (Should be at least class 10 or U1)
- Option 2: USB drive (Not for Zero and 1)
	- Suitable for much-faster-than-SD-card drives.
	- Normal hard drive needs external power, e.g., powered USB hub, to have it spin up 5+ seconds before boot.
	- [USB mass storage boot](https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#usb-mass-storage-boot) must be enabled on Raspberry.
	- Boot might takes 10+ seconds longer: Detect no sd card » read boot loader » boot

Note: Device larger than 2TB will be setup as `GPT`
- For Raspberry Pi 5, 4 and 3B+ only
- Other models: Use the device as storage with rAudio on SD card

Note: Use router pre-assigned IP address for Raspberry Pi if possible.

**Run script**
- Open terminal on Linux
	- Maximize terminal window
- Switch to user root
	```sh
	# set root password, if not yet
	sudo passwd root

	su
	```
- Run
	```sh
	bash <( wget -qO- https://raw.githubusercontent.com/rern/rOS/main/create-alarm.sh )
	```
---

### Optionals
**Setup Wi-Fi auto-connect** for headless/no screen (if not set during build)
- On Linux or Windows
- Insert micro SD card
- 3 alternatives:
	1. From existing
		- Backup the profile file from `/etc/netctl/PROFILE`
		- Rename it to `wifi` then copy it to `BOOT` before power on.
	2. Edit template file - name and password
		- Open `wifi0` in BOOT with text editor
		- Edit SSID and Key
		- Save as `wifi`
	3. Generate a complex profile - static IP, hidden SSID
		- With [**Pre-configure Wi-Fi connection**](https://rern.github.io/WiFi_profile/)
		- Save it in BOOT
- Move micro SD card to Raspberry Pi
- Power on

**Create image file** (`BOOT` and `ROOT` on single device only)
- Once started rAudio successfully
- SSH to RPi
- Reset for image
```sh
ssh root@<RPI IP>
bash <( curl -sL https://github.com/rern/rOS/raw/main/image-reset.sh )
```
- Shutdown
- Move micro SD card to Linux
- Create compressed image file
```sh
bash <( curl -sL https://github.com/rern/rOS/raw/main/image-create.sh )
```

**LED flashes - errors**
Decode: https://support.pishop.ca/article/33-raspberry-pi-act-led-error-patterns
