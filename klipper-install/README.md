# Klipper Install - Custom Files Package

This folder contains all custom files that need to be added to a Klipper installation. These files are **NOT** in the master Klipper repository.

## Structure

```
klipper-install/
├── extras/                    # Python modules → klippy/extras/
│   └── winder.py             # REQUIRED: Winder controller module
├── kinematics/                # Python modules → klippy/kinematics/
│   └── winder.py             # REQUIRED: Winder kinematics module
├── scripts/                   # Helper scripts → scripts/
│   ├── klipper_interface.py  # Python interface to Klipper API
│   ├── winder_control.py     # Winder control interface
│   └── ...                   # Other helper scripts
├── config/                    # Configuration files → ~/printer.cfg
│   ├── generic-bigtreetech-manta-m8p-V1_1.cfg  # Full MP8 config
│   └── ...                   # Other config files
├── docs/                      # Documentation (optional)
│   └── ...                   # PDFs, images, guides
├── mp8-boot/                  # Bootloader files (optional)
│   └── M8P_bootloader.bin    # MP8 bootloader
├── .config.winder-minimal     # Build config → .config
└── README.md                  # This file
```

## Remote Development

**Most development happens on CM4 via SSH.** See `REMOTE_DEVELOPMENT.md` for complete guide.

**Quick start:**
```bash
# Sync files to CM4
./scripts/sync_winder_module.sh

# Run tests remotely
./scripts/remote_test.sh

# Watch logs
./scripts/remote_logs.sh
```

## Quick Install

### Method 1: Use Install Script (Recommended)

```bash
cd klipper-install

# Development environment (recommended)
./install.sh --dev --mcu=AUTO

# Or minimal production install
./install.sh --mcu=AUTO
```

See `USAGE.md` for complete usage guide and all options.

### Method 2: Manual Install

```bash
# From project root
./scripts/add_custom_files_to_klipper.sh ~/klipper
```

### Method 2: Manual Copy

```bash
# Required files
cp extras/winder.py ~/klipper/klippy/extras/
cp kinematics/winder.py ~/klipper/klippy/kinematics/

# Build config (recommended)
cp .config.winder-minimal ~/klipper/.config

# Optional: Scripts
cp scripts/*.py ~/klipper/scripts/

# Optional: Config (copy to ~/printer.cfg on CM4)
cp config/generic-bigtreetech-manta-m8p-V1_1.cfg ~/printer.cfg
```

## Required Files

These files **MUST** be copied for the winder to work:

1. **`extras/winder.py`** → `~/klipper/klippy/extras/winder.py`
   - Winder controller module
   - Handles motor control, Hall sensors, RPM measurement

2. **`kinematics/winder.py`** → `~/klipper/klippy/kinematics/winder.py`
   - Winder kinematics module
   - Only uses Y-axis (traverse stepper)

## Recommended Files

1. **`.config.winder-minimal`** → `~/klipper/.config`
   - Minimal build configuration
   - Disables unused features (LCD, neopixel, etc.)

2. **`config/generic-bigtreetech-manta-m8p-V1_1.cfg`** → `~/printer.cfg`
   - Full MP8 configuration
   - Includes winder module, stepper, TMC2209 settings

## Optional Files

- **Scripts** - Helper scripts for testing and debugging
- **Docs** - Documentation and schematics
- **Bootloader** - MP8 bootloader binary

## Installation Steps

1. **Clone Klipper:**
   ```bash
   cd ~
   git clone https://github.com/Klipper3d/klipper.git
   ```

2. **Copy custom files:**
   ```bash
   cd ~/klipper-install
   cp extras/winder.py ~/klipper/klippy/extras/
   cp kinematics/winder.py ~/klipper/klippy/kinematics/
   cp .config.winder-minimal ~/klipper/.config
   ```

3. **Build firmware:**
   ```bash
   cd ~/klipper
   make menuconfig  # Or use .config.winder-minimal
   make
   ```

4. **Copy config to CM4:**
   ```bash
   scp config/generic-bigtreetech-manta-m8p-V1_1.cfg winder@winder.local:~/printer.cfg
   ```

## File Locations

| Source | Destination | Required? |
|--------|-------------|-----------|
| `extras/winder.py` | `~/klipper/klippy/extras/winder.py` | ✅ Yes |
| `kinematics/winder.py` | `~/klipper/klippy/kinematics/winder.py` | ✅ Yes |
| `.config.winder-minimal` | `~/klipper/.config` | ⚠️ Recommended |
| `config/*.cfg` | `~/printer.cfg` | ⚪ User config |
| `scripts/*.py` | `~/klipper/scripts/` | ⚪ Optional |

## Verification

After copying files, verify they exist:

```bash
# Check required files
ls -la ~/klipper/klippy/extras/winder.py
ls -la ~/klipper/klippy/kinematics/winder.py

# Test import (should not error)
cd ~/klipper
python3 -c "import sys; sys.path.insert(0, 'klippy'); from extras import winder; print('OK')"
```

## Notes

- **Config files** are user-specific and should be copied to `~/printer.cfg` on your CM4
- **Build config** (`.config.winder-minimal`) goes in the Klipper root directory
- **Python modules** go in their respective `klippy/` subdirectories
- **Scripts** are optional but useful for testing and debugging

## Troubleshooting

**Import errors:**
- Make sure files are in correct locations
- Check file permissions: `chmod +x scripts/*.py`

**Build errors:**
- Verify `.config` file exists: `ls -la ~/klipper/.config`
- Check MCU selection in config matches your board

**Config errors:**
- Update serial port in `printer.cfg`: `ls -la /dev/serial/by-id/`
- Verify winder module is loaded: Check Klipper logs

