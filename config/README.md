# Modular Configuration System

Inspired by [RatOS](https://github.com/Rat-OS/RatOS), this modular config system makes it easy to swap hardware, share presets, and maintain your winder configuration.

## Directory Structure

```
config/
├── boards/              # Control board configurations
│   ├── manta-m4p.cfg
│   ├── manta-m8p.cfg
│   └── skr-pico.cfg
├── hardware/            # Hardware component configs
│   ├── bldc-motor.cfg
│   ├── angle-sensor-5v.cfg
│   ├── angle-sensor-3.3v.cfg
│   └── hall-sensor.cfg
├── presets/             # Pickup-specific presets
│   ├── humbucker.cfg
│   ├── stratocaster.cfg
│   ├── p90.cfg
│   └── telecaster.cfg
├── macros/              # G-code macros
│   ├── winding.cfg
│   └── pickup-presets.cfg
├── printer-modular.cfg  # NEW modular master config
└── printer-manta-m4p-modular.cfg  # OLD monolithic config (backup)
```

## Benefits

### 1. **Easy Hardware Swaps**
Switching from Manta M4P to M8P? Just change one line:
```ini
# [include boards/manta-m4p.cfg]
[include boards/manta-m8p.cfg]
```

### 2. **Pickup Presets**
Wind common pickups with one command:
```gcode
WIND_HUMBUCKER          # 5000 turns @ 300 RPM
WIND_STRATOCASTER       # 8000 turns @ 400 RPM
WIND_P90                # 10000 turns @ 350 RPM
WIND_TELECASTER_BRIDGE  # 9000 turns @ 400 RPM
```

### 3. **Share Configurations**
Share your custom pickup preset:
```bash
# Share your custom preset
cp config/presets/my-custom-pickup.cfg ~/shared/
```

### 4. **Easy Updates**
Update motor calibration once, all configs benefit:
```bash
# Edit hardware/bldc-motor.cfg
motor_speed_calibration: 1.09  # All configs use this now
```

## Quick Start

### Option 1: Use Modular Config (Recommended)
```bash
# Copy the new modular config
scp ~/Documents/GitHub/CM4-Pico-winder/config/printer-modular.cfg winder@winder.local:~/printer.cfg

# Copy all the modules
scp -r ~/Documents/GitHub/CM4-Pico-winder/config/boards winder@winder.local:~/printer_data/config/
scp -r ~/Documents/GitHub/CM4-Pico-winder/config/hardware winder@winder.local:~/printer_data/config/
scp -r ~/Documents/GitHub/CM4-Pico-winder/config/presets winder@winder.local:~/printer_data/config/
scp -r ~/Documents/GitHub/CM4-Pico-winder/config/macros winder@winder.local:~/printer_data/config/

# Restart Klipper
ssh winder@winder.local 'sudo service klipper restart'
```

### Option 2: Keep Old Config
Your old `printer-manta-m4p-modular.cfg` still works! No changes needed.

## Creating Custom Presets

### Example: Custom Humbucker
Create `config/presets/my-humbucker.cfg`:
```ini
# My Custom Hot Humbucker
wire_diameter: 0.056
wire_coating_margin: 0.016
bobbin_width: 6.35
default_rpm: 350      # Wind hotter
default_turns: 5500   # More turns
default_layers: 1
spindle_edge: 43.0
home_offset: 2.0
```

Then in `printer-modular.cfg`:
```ini
[include presets/my-humbucker.cfg]
```

Add a macro in `macros/pickup-presets.cfg`:
```ini
[gcode_macro WIND_MY_HUMBUCKER]
description: Wind my custom hot humbucker
gcode:
    HOME_TRAVERSE
    WINDER_START RPM=350 LAYERS=1 TURNS=5500
```

## Switching Sensors

### When you get the 3.3V sensor:
```ini
# In printer-modular.cfg, comment out 5V, uncomment 3.3V:
# [include hardware/angle-sensor-5v.cfg]
[include hardware/angle-sensor-3.3v.cfg]
```

## Troubleshooting

### "Config file not found"
Make sure modules are in `~/printer_data/config/` on the CM4:
```bash
ssh winder@winder.local "ls -la ~/printer_data/config/"
```

### "Duplicate section"
Check that you're not including the same module twice.

### "Unknown config section"
Make sure all referenced modules exist and are copied to the CM4.

## Migration Guide

### From Old Config to Modular:
1. Backup your current config:
   ```bash
   ssh winder@winder.local "cp ~/printer.cfg ~/printer.cfg.backup"
   ```

2. Copy modular structure (see Quick Start above)

3. Test with `FIRMWARE_RESTART` first, then `sudo service klipper restart`

4. If issues, revert:
   ```bash
   ssh winder@winder.local "cp ~/printer.cfg.backup ~/printer.cfg"
   ssh winder@winder.local "sudo service klipper restart"
   ```

## Next Steps

- [ ] Create your own custom pickup presets
- [ ] Share presets with the community
- [ ] Add more boards (M8P, SKR Pico)
- [ ] Create wire gauge presets (42 AWG, 43 AWG, 44 AWG)

