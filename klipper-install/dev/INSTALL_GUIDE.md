# Installation Guide

This guide explains how to install the custom files from `klipper-install` to your Klipper installation.

## Prerequisites

- Klipper cloned: `git clone https://github.com/Klipper3d/klipper.git ~/klipper`
- This `klipper-install` folder

## Quick Install

```bash
cd klipper-install
./install.sh ~/klipper
```

## Manual Install

### Step 1: Copy Required Files

```bash
# Required Python modules
cp extras/winder.py ~/klipper/klippy/extras/
cp kinematics/winder.py ~/klipper/klippy/kinematics/
```

### Step 2: Copy Build Config (Recommended)

```bash
cp .config.winder-minimal ~/klipper/.config
```

### Step 3: Copy Optional Scripts

```bash
cp scripts/*.py ~/klipper/scripts/
```

### Step 4: Copy Config File (to CM4)

```bash
# On your Mac
scp config/generic-bigtreetech-manta-m8p-V1_1.cfg winder@winder.local:~/printer.cfg

# Or manually copy to ~/printer.cfg on CM4
```

## Verification

After installation, verify files exist:

```bash
# Check required files
ls -la ~/klipper/klippy/extras/winder.py
ls -la ~/klipper/klippy/kinematics/winder.py

# Test import
cd ~/klipper
python3 -c "import sys; sys.path.insert(0, 'klippy'); from extras import winder; print('✓ winder module OK')"
```

## Build Firmware

```bash
cd ~/klipper

# Option 1: Use minimal config
cp .config.winder-minimal .config
make

# Option 2: Configure manually
make menuconfig
make
```

## File Locations

| File | Source | Destination |
|------|--------|-------------|
| Winder module | `extras/winder.py` | `~/klipper/klippy/extras/winder.py` |
| Winder kinematics | `kinematics/winder.py` | `~/klipper/klippy/kinematics/winder.py` |
| Build config | `.config.winder-minimal` | `~/klipper/.config` |
| Config file | `config/*.cfg` | `~/printer.cfg` (on CM4) |
| Scripts | `scripts/*.py` | `~/klipper/scripts/` |

## Troubleshooting

**Import errors:**
- Verify files are in correct locations
- Check file permissions

**Build errors:**
- Verify `.config` exists: `ls -la ~/klipper/.config`
- Check MCU selection matches your board

**Config errors:**
- Update serial port in `printer.cfg`
- Check Klipper logs: `tail -f /tmp/klippy.log`

