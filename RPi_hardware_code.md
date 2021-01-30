**Raspberry Pi Hardware**

- Code:
	- `EDCBBA=$( awk '/Revision/ {print $NF}' /proc/cpuinfo )`
	- `BB=${EDCBBA: -3:2}` (RPi Zero W: `19000c1` - 7 characters)
	- `C=${EDCBBA: -4:1}`


| Name       | code `BB` | no wl | no eth | SoC       | code `C` | 4 cores | 64-bit  |
|------------|-----------|-------|--------|-----------|----------|---------|---------|
| RPi Zero   | `09`      | :x:   | :x:    | BCM2835   | `0`      |         |         |
| RPi Zero W | `0c`      |       | :x:    | BCM2835   | `0`      |         |         |
| RPi B      | `00`      | :x:   |        | BCM2835   | `0`      |         |         |
| RPi A      | `00`      | :x:   | :x:    | BCM2835   | `0`      |         |         |
| RPi A+     | `01` `02` | :x:   | :x:    | BCM2835   | `0`      |         |         |
| RPi B+     | `01` `03` | :x:   |        | BCM2835   | `0`      |         |         |
|            |           |       |        |           |          |         |         |
| RPi 2B     | `04`      | :x:   |        | BCM2836   | `1`      | &check; |         |
|            |           |       |        |           |          |         |         |
| RPi 2B 1.2 | `04`      | :x:   |        | BCM2837   | `2`      | &check; | &check; |
| RPi 3B     | `08`      |       |        | BCM2837   | `2`      | &check; | &check; |
|            |           |       |        |           |          |         |         |
| RPi 3A+    | `0e`      |       | :x:    | BCM2837B0 | `2`      | &check; | &check; |
| RPi 3B+    | `0d`      |       |        | BCM2837B0 | `2`      | &check; | &check; |
|            |           |       |        |           |          |         |         |
| RPi 4B     | `11`      |       |        | BCM2711   | `3`      | &check; | &check; |

- `A` - PCB revision
- `BB` - Name
- `C` - SoC
	- `0` - ARMv6 (32-bit) RPi Zero, 1
	- `1` - ARMv7 (32-bit) RPi 2
	- `2`, `3` - ARMv8 (64/32-bit) RPi 2 v 1.2, 3, 4
- `D` - Manufacturer:
	- `0` - Sony UK
	- `2` - Embest
	- `3` - Stadium
	- `5` - Sony Japan
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
