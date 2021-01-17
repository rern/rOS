rOS - DIY rAudio
---
Build [**rAudio**](https://github.com/rern/rAudio-1) - Audio player and renderer for Raspberry Pi

- For all **Raspberry Pi**s: Zero, 1, 2, 3 and 4
- Create **rAudio** from latest releases of [**Arch Linux Arm**](https://archlinuxarm.org/about/downloads)
- Interactive interface
- Options:
	- Run `ROOT` partition on USB drive
	- Run on USB only - no SD card ([boot from USB](https://www.raspberrypi.org/documentation/hardware/raspberrypi/bootmodes/msd.md))
	- Pre-configure Wi-Fi connection (headless mode)
	- Exclude features (can be as light as possible in terms of build time and disk space)
- Take less than 15 minutes for the whole process with a decent download speed.

**Procedure**
- [Prepare partitions](#prepare-partitions)
	- Create `BOOT` and `ROOT` partitions
- [Create Arch Linux Arm + rAudio](#create-arch-linux-arm--raudio)
	- Optional - Pre-configure Wi-Fi (For reliable connection, use wired LAN if possible)
	- Select features
	- Download Arch Linux Arm
	- Write `BOOT` and `ROOT`
	- SSH connect PC to Raspberry Pi
	- Upgrade kernel and default packages
	- Install feature packages
	- Install web user interface
	- Configure
	- Set defaults
- [Optionals](#optionals)
	- Setup Wi-Fi auto-connect
	- Create image file
- Expert mode (1 command line - micro SD card only)
```sh
bash <( wget -qO - https://github.com/rern/rOS/raw/main/create.sh )
```

![dialog1](https://github.com/rern/_assets/raw/master/rOS/select-hw.jpg)
![dialog2](https://github.com/rern/_assets/raw/master/rOS/select-features.jpg)  

**Need**
- PC - Linux - any distro
	- or on USB e.g., [Manjaro](https://itsfoss.com/create-live-usb-manjaro-linux/) - Arch Linux
	- or on Raspberry Pi itself (If no GUI, `fdisk` and `mount` skills needed.)
	- or on VirtualBox on Windows (with network set as `Bridge Adapter`) - Slowest
- Raspberry Pi
- Network connection to Raspberry Pi 
	- Wired LAN
	- Optional: Wi-Fi (if necessary)
- Media:
	- Micro SD card shoule be at least class 10 or U1.
	- Option 1: Micro SD card: 8GB+ for `BOOT` + `ROOT` partitions
	- Option 2: Micro SD card + USB drive (`ROOT` partition on USB drive)
		- Micro SD card: 100MB+ for `BOOT` partition only
		- USB drive: 8GB+ for `ROOT` partition (or USB hard drive with existing data)
	- Option 3: USB drive only - no SD card (Boot from USB drive)
		- Raspberry Pi 3 and 2 v1.2 only (4 not yet supported)
		- USB drive: 8GB+ for `BOOT` + `ROOT` partition
	- Note for USB drive:
		- Suitable for hard drives or faster-than-SD-card thumb drives.
		- Boot from USB drive:
			- Suitable for solid state drives.
			- Normal hard drive needs external power, e.g., powered USB hub, to have it spin up 5+ seconds before boot.
			- Boot takes 10+ seconds longer (detect no sd card > read boot loader into memory > boot)
---

### Prepare partitions
- On Linux PC
- Open **GParted** app (Manjaro root password: `manjaro`)
- 3 Alternatives:
	- Micro SD card only
	- Micro SD card + USB drive
	- USB drive only
	
**Alternative 1: Micro SD card only**
- `Unmount` > `Delete` all partitions (make sure it's the micro SD card)
- Create partitions:

| No. | Size        | Type    | Format | Label |
|-----|-------------|---------|--------|-------|
| #1  | 100MiB      | primary | fat32  | BOOT  |
| #2  | (the rest)  | primary | ext4   | ROOT  |
	
**Alternative 2: Micro SD card + USB drive**
- Micro SD card
	- `Unmount` > `Delete` all partitions (Caution: make sure it's the SD card)
	- Create a partition:

| No. | Size        | Type    | Format | Label |
|-----|-------------|---------|--------|-------|
| #1  | 100MiB      | primary | fat32  | BOOT  |

- USB drive - Blank:
	- `Unmount` > `Delete` all partitions (Caution: make sure it's the USB drive)
	- Create partitions:
	
| No. | Size        | Type    | Format | Label |
|-----|-------------|---------|--------|-------|
| #1  | 3500MiB     | primary | ext4   | ROOT  |
| #2  | (the rest)  | primary | ext4   | (any) |
	
- or USB drive - with existing data:
	- No need to reformat or change format of existing partition
	- Resize the existing to get 3500MiB unallocated space (anywhere - at the end, middle or start of the disk)
	- Create a partition in the space:
		
| No.   | Size        | Type    | Format | Label |
|-------|-------------|---------|--------|-------|
| (any) | (existing)  | primary | (any)  | (any) |
| (any) | 3500MiB     | primary | ext4   | ROOT  |
			
**Alternative 3: USB drive only**

- Enable boot from USB: [Set boot bit](https://www.raspberrypi.org/documentation/hardware/raspberrypi/bootmodes/msd.md) (Micro SD card can still be used as usual if inserted.)
- Create partitions: (Drive with existing data must be resized and rearranged respectively.)

| No. | Size        | Type    | Format | Label |
|-----|-------------|---------|--------|-------|
| #1  | 100MiB      | primary | fat32  | BOOT  |
| #2  | 3500MiB     | primary | ext4   | ROOT  |
| #3  | (the rest)  | primary | ext4   | (any) |

---
	
### Create Arch Linux Arm + rAudio
- Open **Files** app (**File Manager** on Manjaro)
- Click `BOOT` and `ROOT` to mount
- Note each path in location bar or hover mouse over `BOOT` and `ROOT` for confirmation
- Switch user to root
```sh
su
```
- (Manjaro only) - update package mirror list
```sh
pacman-mirrors -c COUNRTY
```
- Create script
```sh
# ssh - no stdout | sh
bash <( wget -qO - https://github.com/rern/rOS/raw/main/create-alarm.sh )
```
- Errors or too slow download: press `Ctrl+C` and run `./create-alarm.sh` again (while in `Create Arch Linux Arm` mode only)

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
	
**Create image file** (Micro SD card mode only)

- Once started rAudio successfully
- SSH to RPi
- Reset for image
```sh
ssh root@<RPI IP>
bash <( wget -qO - https://github.com/rern/rOS/raw/main/reset.sh )
```
- Shutdown
- Move micro SD card to Linux
- Click `BOOT` and `ROOT` to mount
- Create compressed image file
```sh
bash <( wget -qO - https://github.com/rern/rOS/raw/main/imagecreate.sh )
```

**Write image file**
- Run in image file directory
```sh
bash <( wget -qO - https://github.com/rern/rOS/raw/main/imagewrite.sh )
```
