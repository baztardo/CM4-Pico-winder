# Klipper Interface Integration

The Klipper interface has been integrated into the project to provide programmatic control of the winder.

## What Was Added

### Scripts

1. **`scripts/klipper_interface.py`** - Main Python interface for Klipper webhooks
   - Connects to Klipper via Unix socket (`/tmp/klippy_uds`)
   - Sends G-code commands
   - Queries printer status
   - Command-line and Python API

2. **`scripts/winder_control.py`** - Winder-specific control script
   - Home Y axis
   - Get status
   - Wind coils with configurable parameters
   - Move to positions
   - Send custom G-code

3. **`scripts/README_INTERFACE.md`** - Documentation for the interface

4. **`sync_interface_to_cm4.sh`** - Script to sync interface files to CM4

## Quick Start

### 1. Sync to CM4

```bash
# Option 1: Use the sync script
./sync_interface_to_cm4.sh

# Option 2: Use the main copy script (includes interface)
./copy_to_cm4.sh

# Option 3: Manual copy
scp scripts/klipper_interface.py scripts/winder_control.py winder@winder.local:~/klipper/scripts/
ssh winder@winder.local "chmod +x ~/klipper/scripts/klipper_interface.py ~/klipper/scripts/winder_control.py"
```

### 2. Test Connection

```bash
# From CM4
python3 ~/klipper/scripts/klipper_interface.py --info

# Or via SSH from Mac
ssh winder@winder.local "python3 ~/klipper/scripts/klipper_interface.py --info"
```

### 3. Basic Usage

```bash
# Get status
python3 ~/klipper/scripts/winder_control.py --status

# Home Y axis
python3 ~/klipper/scripts/winder_control.py --home

# Move to position
python3 ~/klipper/scripts/winder_control.py --move 45

# Wind 10 layers
python3 ~/klipper/scripts/winder_control.py --wind --layers 10
```

## Python API Example

```python
#!/usr/bin/env python3
import sys
sys.path.insert(0, '/home/winder/klipper/scripts')
from klipper_interface import KlipperInterface

k = KlipperInterface()
k.connect()

# Home
k.send_gcode("G28 Y")

# Get position
status = k.query_objects({"toolhead": ["position"]})
print(f"Y: {status['toolhead']['position'][1]}mm")

# Wind
k.send_gcode("G92 E0")
for layer in range(10):
    e = 12 * (layer + 1)
    if layer % 2 == 0:
        k.send_gcode(f"G1 Y50 E{e} F336")
    else:
        k.send_gcode(f"G1 Y38 E{e} F336")

k.disconnect()
```

## Socket Path

The default socket is `/tmp/klippy_uds`. Make sure Klipper is started with:

```bash
python3 ~/klipper/klippy/klippy.py --api-server /tmp/klippy_uds ...
```

Check your systemd service:

```bash
cat /etc/systemd/system/klipper.service | grep api-server
```

## Files Structure

```
scripts/
├── klipper_interface.py      # Main interface (NEW)
├── winder_control.py         # Winder control script (NEW)
├── README_INTERFACE.md       # Interface documentation (NEW)
└── whconsole.py              # Original Klipper console (existing)
```

## Integration with Existing Scripts

The interface works alongside existing scripts:
- `calibrate_rotation_distance.py` - Uses same socket
- `whconsole.py` - Original example (for reference)

## Next Steps

1. **Test the interface** on CM4
2. **Create custom winding scripts** using the Python API
3. **Integrate with your workflow** (e.g., automated winding sequences)
4. **Add error handling** for production use

## Troubleshooting

See `scripts/README_INTERFACE.md` for detailed troubleshooting.

## Documentation

- `scripts/README_INTERFACE.md` - Detailed usage guide
- `INTERFACE_GUIDE_1.md` - Architecture and protocol details (in Downloads)
- `CHEAT_SHEET.md` - Quick reference (in Downloads)

