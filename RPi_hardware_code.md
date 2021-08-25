**Raspberry Pi Hardware Code**

- Code: `EDCBBA=$( awk '/Revision/ {print $NF}' /proc/cpuinfo )`


| Name       | code `BB` | no wl | no eth | SoC - core - instr-bit    | code `C` | idle/max (mA) |
|:-----------|:----------|:------|:-------|:--------------------------|:---------|:--------------|
| RPi Zero   | `09`      | :x:   | :x:    | BCM2835 - 1 - ARMv6Z-32   | `0`      | 100 / 350     |
| RPi Zero W | `0c`      |       | :x:    | &#8593;                   | &#8593;  | &#8593;       |
| RPi B      | `00`      | :x:   |        | &#8593;                   | &#8593;  | 700           |
| RPi A      | `00`      | :x:   | :x:    | &#8593;                   | &#8593;  | 300           |
| RPi A+     | `01` `02` | :x:   | :x:    | &#8593;                   | &#8593;  | 200           |
| RPi B+     | `01` `03` | :x:   |        | &#8593;                   | &#8593;  | 200 / 350     |
|            |           |       |        |                           |          |               |
| RPi 2B     | `04`      | :x:   |        | BCM2836 - 4 - ARMv7A-32   | `1`      | 220 / 820     |
|            |           |       |        |                           |          |               |
| RPi 2B 1.2 | `04`      | :x:   |        | BCM2837 - 4 - ARMv8A-64   | `2`      | 220 / 820     |
| RPi 3B     | `08`      |       |        | &#8593;                   | &#8593;  | 300 / 1340    |
|            |           |       |        |                           |          |               |
| RPi 3A+    | `0e`      |       | :x:    | BCM2837B0 - 4 - ARMv8A-64 | `2`      |               |
| RPi 3B+    | `0d`      |       |        | &#8593;                   | &#8593;  | 460 / 1130    |
|            |           |       |        |                           |          |               |
| RPi 4B     | `11`      |       |        | BCM2711 - 4 - ARMv8A-64   | `3`      | 600 / 1250    |

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

