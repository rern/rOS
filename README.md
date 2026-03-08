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
	- Run `ROOT` partition on USB drive
	- Run on USB only - no SD card ([boot from USB](https://www.raspberrypi.org/documentation/hardware/raspberrypi/bootmodes/msd.md))
	- Pre-configure Wi-Fi connection
	- Exclude features (can be as light as possible in terms of build time and disk space)
- Take less than 15 minutes for the whole process with a decent download speed.

**Procedure**
- [Create Arch Linux ARM + rAudio](#create-arch-linux-arm--raudio)
	- Use wired LAN connection if possible
	- Use router pre-assigned IP address if possible
	- Run script:
		- Setup
		- Create Arch Linux ARM
			- Write `BOOT` and `ROOT`
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
- Linux
	- Or PC:
		- Linux on USB e.g., [Manjaro](https://itsfoss.com/create-live-usb-manjaro-linux/) *(Arch Linux)*
		- Linux on VirtualBox (with network set as `Bridge Adapter`)
- Raspberry Pi
- Network connection to Raspberry Pi 
	- Wired LAN
	- Optional: Wi-Fi (if necessary)
- Media:
	- Micro SD card or/and USB drive

---

### Create rAudio
**Target device:**
- Option 1: Micro SD card (Should be at least class 10 or U1)
- Option 2: USB drive (Not for Zero and 1)
- Option 3: Micro SD card + USB drive
	- Create partitions:
		| Device    | Size        | Type    | Format | Label |
		|:----------|:------------|:--------|:-------|:------|
		| SD card   | 300MiB      | primary | VFAT   | BOOT  |
		| USB drive | 4000MiB     | primary | Ext4   | ROOT  |

Note: USB drive
- Suitable for much-faster-than-SD-card drives.
- Normal hard drive needs external power, e.g., powered USB hub, to have it spin up 5+ seconds before boot.
- Boot takes 10+ seconds longer (detect no sd card > read boot loader into memory > boot)
- [USB mass storage boot](https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#usb-mass-storage-boot) must be enabled on Raspberry.

**Run script on Linux terminal**
```sh
sudo bash <( curl -sL https://github.com/rern/rOS/raw/main/create-alarm.sh )
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
