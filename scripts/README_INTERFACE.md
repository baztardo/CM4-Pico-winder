# Klipper Interface for Winder

This directory contains scripts for controlling the winder via Klipper's webhooks API.

## Files

- **`klipper_interface.py`** - Main Python interface for communicating with Klipper via Unix socket
- **`winder_control.py`** - Winder-specific control script with examples
- **`whconsole.py`** - Original Klipper webhooks console (for reference)

## Quick Start

### 1. Test Connection

```bash
# From your Mac (if socket is accessible via SSH)
ssh winder@winder.local "python3 ~/klipper/scripts/klipper_interface.py --info"

# Or directly on CM4
python3 ~/klipper/scripts/klipper_interface.py --info
```

### 2. Basic Commands

```bash
# Interactive mode
python3 ~/klipper/scripts/klipper_interface.py -i

# Home Y axis
python3 ~/klipper/scripts/klipper_interface.py -g "G28 Y"

# Get status
python3 ~/klipper/scripts/winder_control.py --status

# Move to position
python3 ~/klipper/scripts/winder_control.py --move 45
```

### 3. Wind a Coil

```bash
# Wind 10 layers (default)
python3 ~/klipper/scripts/winder_control.py --wind

# Wind custom number of layers
python3 ~/klipper/scripts/winder_control.py --wind --layers 20

# Custom parameters
python3 ~/klipper/scripts/winder_control.py --wind \
    --layers 15 \
    --start-y 38.0 \
    --end-y 50.0 \
    --e-per-layer 12.0 \
    --feedrate 336.0
```

## Python API Usage

```python
#!/usr/bin/env python3
import sys
sys.path.insert(0, '/path/to/klipper/scripts')
from klipper_interface import KlipperInterface

# Connect
k = KlipperInterface("/tmp/klippy_uds")
k.connect()

# Home
k.send_gcode("G28 Y")

# Get status
status = k.query_objects({
    "toolhead": ["position", "homed_axes"],
    "winder": None
})
print(f"Y position: {status['toolhead']['position'][1]}")

# Wind
k.send_gcode("G92 E0")
k.send_gcode("G1 Y38 F1000")
for layer in range(10):
    e_pos = 12 * (layer + 1)
    if layer % 2 == 0:
        k.send_gcode(f"G1 Y50 E{e_pos} F336")
    else:
        k.send_gcode(f"G1 Y38 E{e_pos} F336")

k.disconnect()
```

## Socket Path

The default socket path is `/tmp/klippy_uds`. This is set when Klipper starts with:

```bash
python3 ~/klipper/klippy/klippy.py --api-server /tmp/klippy_uds ...
```

If your socket is in a different location, specify it with `-s`:

```bash
python3 ~/klipper/scripts/klipper_interface.py -s /tmp/printer --info
```

## Installation on CM4

Copy the scripts to your CM4:

```bash
# From your Mac
scp scripts/klipper_interface.py scripts/winder_control.py winder@winder.local:~/klipper/scripts/

# On CM4, make executable
ssh winder@winder.local "chmod +x ~/klipper/scripts/klipper_interface.py ~/klipper/scripts/winder_control.py"
```

## Troubleshooting

### Connection Failed

```bash
# Check if Klipper is running
ssh winder@winder.local "ps aux | grep klippy"

# Check if socket exists
ssh winder@winder.local "ls -la /tmp/klippy_uds"

# Check Klipper log
ssh winder@winder.local "tail -20 /tmp/klippy.log"
```

### Socket Not Found

Make sure Klipper is started with the `--api-server` argument. Check your systemd service:

```bash
ssh winder@winder.local "cat /etc/systemd/system/klipper.service | grep api-server"
```

If it's missing, add it to the ExecStart line:

```
ExecStart=/usr/bin/python3 /home/winder/klipper/klippy/klippy.py \
    --api-server /tmp/klippy_uds \
    /home/winder/klipper/config/printer.cfg
```

## See Also

- `INTERFACE_GUIDE_1.md` - Detailed usage guide
- `CHEAT_SHEET.md` - Quick reference
- `klippy/webhooks.py` - Klipper webhooks implementation

