# Installation Usage Guide

## Basic Usage

```bash
cd klipper-install
./install.sh [options]
```

## Options

### Environment Type

- **`--dev`** or **`--development`** - Set up full development environment
  - Full Klipper clone in `klipper-install/klipper-dev/`
  - Lean install in `~/klipper`
  - Git workflow enabled
  - Official docs downloaded

- **Default (no flag)** - Minimal production install
  - Only essential files copied to `~/klipper`
  - Smaller footprint
  - Production-ready

### MCU Selection

- **`--mcu=AUTO`** (default) - Auto-detect MCU from USB devices
- **`--mcu=STM32G0B1`** - Force STM32G0B1 (Manta MP8, etc.)
- **`--mcu=RP2040`** - Force RP2040 (SKR Pico, etc.)

### Other Options

- **`--skip-upgrade`** - Skip system upgrade prompt
- **`--non-interactive`** - Skip all prompts (useful for automation)

## Examples

### Development Environment

```bash
# Dev environment, auto-detect MCU
./install.sh --dev

# Dev environment, specific MCU
./install.sh --dev --mcu=STM32G0B1

# Dev environment, no prompts
./install.sh --dev --mcu=AUTO --non-interactive
```

### Production/Minimal Install

```bash
# Minimal install, auto-detect MCU
./install.sh

# Minimal install, specific MCU
./install.sh --mcu=STM32G0B1

# Minimal install, no prompts
./install.sh --mcu=RP2040 --non-interactive
```

### On CM4 (Remote)

```bash
# SSH to CM4 first
ssh winder@winder.local

# Then run install
cd ~/klipper-install
./install.sh --dev --mcu=AUTO
```

## What Happens

1. **Checks prerequisites** (Python, git, etc.)
2. **Installs dependencies** (build tools, ARM compiler, etc.)
3. **Cleans up old installation** (if exists)
4. **Clones/sets up Klipper:**
   - `--dev`: Full clone → `klipper-install/klipper-dev/`, lean → `~/klipper`
   - Default: Temp clone → `klipper-install/tmp-klipper/`, lean → `~/klipper`
5. **Sets up Python environment** (`~/klipper/klippy-env/`)
6. **Compiles chelper** (C helper modules)
7. **Installs custom files** (winder.py modules)
8. **Creates systemd service** (Klipper service)
9. **Runs MCU setup** (detects MCU, applies config, builds/flashes firmware)

## After Installation

### Development Environment (`--dev`)

```bash
cd ~/klipper

# Build firmware
./dev_build.sh

# Flash firmware
./dev_flash.sh

# Git workflow
./dev_git.sh status

# Update from upstream
./dev_update.sh
```

### Minimal Install

```bash
cd ~/klipper

# Build firmware
make menuconfig  # Configure MCU
make

# Flash firmware
make flash FLASH_DEVICE=/dev/serial/by-id/...
```

## Troubleshooting

### MCU Not Detected

```bash
# Check USB devices
lsusb

# Check serial ports
ls -la /dev/serial/by-id/

# Force MCU type
./install.sh --mcu=STM32G0B1
```

### Installation Fails

```bash
# Check prerequisites
python3 --version
git --version

# Install dependencies manually
sudo apt update
sudo apt install build-essential git python3 python3-pip python3-dev
sudo apt install gcc-arm-none-eabi binutils-arm-none-eabi
```

### Need to Reinstall

```bash
# Clean up first
rm -rf ~/klipper
rm -rf ~/klipper-install/klipper-dev
rm -rf ~/klipper-install/tmp-klipper

# Reinstall
./install.sh --dev
```

