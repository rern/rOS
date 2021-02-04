**Raspberry Pi Hardware Code**

- Code: `EDCBBA=$( awk '/Revision/ {print $NF}' /proc/cpuinfo )`


| Name       | code `BB` | no wl | no eth | SoC - core x bit | code `C` |
|------------|-----------|-------|--------|------------------|----------|
| RPi Zero   | `09`      | X     | X      | BCM2835 - 1x32   | `0`      |
| RPi Zero W | `0c`      |       | X      | BCM2835 - 1x32   | `0`      |
| RPi B      | `00`      | X     |        | BCM2835 - 1x32   | `0`      |
| RPi A      | `00`      | X     | X      | BCM2835 - 1x32   | `0`      |
| RPi A+     | `01` `02` | X     | X      | BCM2835 - 1x32   | `0`      |
| RPi B+     | `01` `03` | X     |        | BCM2835 - 1x32   | `0`      |
|            |           |       |        |                  |          |
| RPi 2B     | `04`      | X     |        | BCM2836 - 4x32   | `1`      |
|            |           |       |        |                  |          |
| RPi 2B 1.2 | `04`      | X     |        | BCM2837 - 4x64   | `2`      |
| RPi 3B     | `08`      |       |        | BCM2837 - 4x64   | `2`      |
|            |           |       |        |                  |          |
| RPi 3A+    | `0e`      |       | X      | BCM2837B0 - 4x64 | `2`      |
| RPi 3B+    | `0d`      |       |        | BCM2837B0 - 4x64 | `2`      |
|            |           |       |        |                  |          |
| RPi 4B     | `11`      |       |        | BCM2711 - 4x64   | `3`      |

- `A` - PCB revision
- `BB` - Name - `BB=${EDCBBA: -3:2}` (RPi Zero W: `19000c1` - 7 characters)
- `C` - SoC - `C=${EDCBBA: -4:1}`
- `D` - Manufacturer:
	- `0` - Sony - UK
	- `2` - Embest - China
	- `3` - Stadium - China
	- `5` - Sony - Japan
- `E` - RAM:
	- `9` - 512KB
	- `a` - 1GB
	- `b` - 2GB
	- `c` - 4GB
- Example: `a22082` : 1GB - Embest - BCM2837 - Raspberry Pi 3B - revision 2
- Single core (RPi Zero and 1 - BCM2835): `[[ $C == 0 ]]`
- On-board Wi-Fi and Bluetooth: `[[ $BB =~ ^(08|0c|0d|0e|11)$ ]]`
- On-board HDMI: If not connected, disabled by kernel.
- Ethernet:
	-  Model A - without ethernet
	-  Model B - on-board ethernet
- 3.5mm headphone output: None in Zero and Zero W
- By `/boot/bcm*` file:
```sh
if [[ -e /boot/bcm2711-rpi-4-b.dtb ]]; then
	rpi=4
else
	[[ -e /boot/bcm2837-rpi-3-b.dtb ]] && rpi=23 || rpi=01
fi
```

