**Raspberry Pi Hardware Code**

- Code: `EDCBBA=$( awk '/Revision/ {print $NF}' /proc/cpuinfo )`


| Name    | code `BB` |  wl   |  eth   | SoC       | CPU x core       | GHz      | code `C` |
|:--------|:----------|:------|:-------|:----------|:-----------------|:---------|:---------|
|         |           |       |        |           |                  |          |          |
| **ARMv6Z** (32bit)                                                                        |
| Zero    | `09`      | X     | X      | BCM2835   | ARM1176JZF-S x 1 | 1        | `0`      |
| Zero W  | `0c`      |       | X      | ↑         | ↑                | ↑        | ↑        |
| A+      | `02`      | X     | X      | ↑         | ↑                | ↑        | ↑        |
| B+      | `03`      | X     |        | ↑         | ↑                | ↑        | ↑        |
|         |           |       |        |           |                  |          |          |
| **ARMv7-A** (32bit)                                                                       |
| 2B      | `04`      | X     |        | BCM2836   | Cortex-A7 x 4    | 0.9      | `1`      |
|         |           |       |        |           |                  |          |          |
| **ARMv8-A** (64/32bit)                                                                    |
| Zero 2W | `12`      |       | X      | BCM2710A1 | Cortex-A53 x 4   | 1        | `2`      |
| 2B 1.2  | `04`      | X     |        | BCM2837   | ↑                | 0.9      | ↑        |
| 3B      | `08`      |       |        | ↑         | ↑                | 1.2      | ↑        |
|         |           |       |        |           |                  |          |          |
| 3A+     | `0e`      | +5GHz | X      | BCM2837B0 | ↑                | 1.4      | ↑        |
| 3B+     | `0d`      | ↑     | Gbit   | ↑         | ↑                | ↑        | ↑        |
|         |           |       |        |           |                  |          |          |
| 4B      | `11`      | ↑     | ↑      | BCM2711   | Cortex-A72 x 4   | 1.5/1.8  | `3`      |
|         |           |       |        |           |                  |          |          |
| **ARMv8.2-A** (64/32bit)                                                                  |
| 5       | `17`      | ↑     | ↑      | BCM2712   | Cortex-A76 x 4   | 2.4      | `4`      |
```sh
#!/bin/bash
revision=$( grep ^Revision /proc/cpuinfo )
BB=${revision: -3:2}
if [[ $BB == 00 ]]; then # 1 - BB[C]
	[[ ${revision: -1} =~ 7|8|9 ]] && model=A || model=B
elif [[ $BB == 04 ]]; then # 2B - [A]BB
	[[ ${revision: -4:1} == 1 ]] && model=2B || model=2B1.2
else
	declare -A BB_model=( [01]=CM1  [02]=A+ [03]=B+     [06]=CM1 [08]=3B  [09]=Zero [0a]=CM3 [0c]=ZeroW [0d]=3B+ [0e]=3A+ \
	                      [10]=CM3+ [11]=4B [12]=Zero2W [13]=400 [14]=CM4 [15]=CM4S [16]=CM2 [17]=5 )
	model=${BB_model[$BB]}
fi
echo $model
```

- `A` - PCB revision
- `BB` - Name - `BB=${EDCBBA: -3:2}` (Zero W: `19000c1` - 7 characters)
- `C` - CPU - `C=${EDCBBA: -4:1}`
- `D` - Manufacturer:
	- `0` - Sony - UK
	- `2` - Embest - China
	- `3` - Sony - Japan
	- `5` - Stadium - China
- `E` - RAM:
	- `9` - 512KB
	- `a` - 1GB
	- `b` - 2GB
	- `c` - 4GB
	- `d` - 8GB
- Example: `a22082` : 1GB - Embest - BCM2837 - Raspberry Pi 3B - revision 2
- Single core (Zero and 1 - BCM2835): `[[ $C == 0 ]]`
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
