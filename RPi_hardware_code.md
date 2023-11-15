**Raspberry Pi Hardware Code**

- Code: `EDCBBA=$( awk '/Revision/ {print $NF}' /proc/cpuinfo )`


| Name    | code `BB` | no wl | no eth | SoC       | CPU x core       | GHz      | code `C` |
|:--------|:----------|:------|:-------|:----------|:-----------------|:---------|:---------|
|         |           |       |        |           |                  |          |          |
| **ARMv6Z** (32bit)      |
| Zero    | `09`      | X     | X      | BCM2835   | ARM1176JZF-S x 1 | 1        | `0`      |
| Zero W  | `0c`      |       | X      | &#8593;   | &#8593;          | &#8593;  | &#8593;  |
| B       | `00`      | X     |        | &#8593;   | &#8593;          | 0.7      | &#8593;  |
| A       | `00`      | X     | X      | &#8593;   | &#8593;          | &#8593;  | &#8593;  |
| A+      | `01` `02` | X     | X      | &#8593;   | &#8593;          | &#8593;  | &#8593;  |
| B+      | `01` `03` | X     |        | &#8593;   | &#8593;          | &#8593;  | &#8593;  |
|         |           |       |        |           |                  |          |          |
| **ARMv7-A** (32bit)     |
| 2B      | `04`      | X     |        | BCM2836   | Cortex-A7 x 4    | 0.9      | `1`      |
|         |           |       |        |           |                  |          |          |
| **ARMv8-A** (64/32bit)  |
| Zero 2W | `12`      |       | X      | BCM2710A1 | Cortex-A53 x 4   | 1        | `2`      |
| 2B 1.2  | `04`      | X     |        | BCM2837   | &#8593;          | 0.9      | &#8593;  |
| 3B      | `08`      |       |        | &#8593;   | &#8593;          | 1.3      | &#8593;  |
|         |           |       |        |           |                  |          |          |
| 3A+     | `0e`      |       | X      | BCM2837B0 | &#8593;          | 1.4      | &#8593;  |
| 3B+     | `0d`      |       |        | &#8593;   | &#8593;          | &#8593;  | &#8593;  |
|         |           |       |        |           |                  |          |          |
| 4B      | `11`      |       |        | BCM2711   | Cortex-A72 x 4   | 1.5      | `3`      |

- `A` - PCB revision
- `BB` - Name - `BB=${EDCBBA: -3:2}` (Zero W: `19000c1` - 7 characters)
- `C` - CPU - `C=${EDCBBA: -4:1}`
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
- Single core (Zero and 1 - BCM2835): `[[ $C == 0 ]]`
- On-board Audio: `[[ ! $BB =~ ^(09|0c|12)$ ]]` (not zero, zero w, zero 2w)
- On-board Wi-Fi and Bluetooth: `[[ ! $BB =~ ^(00|01|02|03|04|09)$ ]]` (not zero, 1, 2)
- Ethernet:
	- Model A - without ethernet
	- Model B - on-board ethernet
- On-board HDMI: (If not connected, disabled by kernel.)
- None in Zero and Zero 2:
	- 3.5mm headphone output
	- DSI - MIPI display interface
- `/boot/kernel*.img` :
	- `/boot/kernel8.img` - 64bit
	- `/boot/kernel7.img` - 32bit
	- `/boot/kernel.img` - legacy (Zero, 1)
