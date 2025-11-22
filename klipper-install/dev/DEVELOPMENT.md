# Klipper Development Environment - CNC Guitar Winder

## Overview

This setup creates a complete Klipper development environment specifically for the CNC Guitar Winder project.

### Architecture

**Two-tier approach:**
- **Full dev clone** → `klipper-install/klipper-dev/` (complete repo for reference/git workflow)
- **Lean install** → `~/klipper` (production-ready, minimal files only)

This gives you:
- Full Klipper repository for reference and git workflow
- Lean production installation for testing streamlined installs
- Official Klipper documentation for reference
- Custom winder modules
- Development helper scripts
- Testing framework
- Easy build/flash workflow

## Installation

### Development Environment (Recommended)

```bash
cd klipper-install
./install.sh --dev
```

This creates:
- Full Klipper clone at `~/klipper`
- Development branch: `winder-dev`
- Helper scripts: `dev_build.sh`, `dev_flash.sh`, `dev_test.sh`
- Python virtual environment
- Custom winder files installed

### Production/Minimal Install

```bash
cd klipper-install
./install.sh
```

This creates a minimal installation with only essential files.

## Development Workflow

### Quick Commands

```bash
cd ~/klipper

# Build firmware
./dev_build.sh

# Flash to MCU
./dev_flash.sh

# Run tests
./dev_test.sh

# Update from upstream Klipper
./dev_update.sh
```

### Making Changes

1. **Edit custom files:**
   - `klippy/extras/winder.py` - Winder controller
   - `klippy/kinematics/winder.py` - Winder kinematics

2. **Test locally:**
   ```bash
   ./dev_test.sh
   ```

3. **Build and flash:**
   ```bash
   ./dev_build.sh
   ./dev_flash.sh
   ```

4. **Test on hardware:**
   - Connect to CM4
   - Check logs: `tail -f /tmp/klippy.log`
   - Run winder commands

### Git Workflow

**Important:** Git operations use the dev clone, not the lean install!

```bash
cd ~/klipper

# Check git status (uses dev clone)
./dev_git.sh status

# Make changes to lean install
nano klippy/extras/winder.py

# Copy changes to dev clone for git tracking
cp klippy/extras/winder.py ../klipper-install/klipper-dev/klippy/extras/

# Commit changes (uses dev clone)
./dev_git.sh add klippy/extras/winder.py
./dev_git.sh commit -m "Add feature X"

# Update from upstream
./dev_update.sh  # Updates dev clone AND syncs to lean install
```

**Why this approach?**
- Lean install (`~/klipper`) stays minimal for testing production installs
- Dev clone (`klipper-install/klipper-dev`) has full git history for reference
- Changes flow: Edit lean → Copy to dev → Git commit in dev → Update syncs both

## Project Structure

```
klipper-install/
├── klipper-dev/               ← FULL Klipper clone (for reference/git)
│   ├── docs/                  ← Official Klipper docs
│   ├── klippy/                ← Full Python runtime
│   ├── src/                   ← Full firmware source
│   └── ...                    ← Everything else
│
├── docs-klipper/              ← Official docs (standalone copy)
│   ├── Overview.md
│   ├── Config_Reference.md
│   └── ...
│
└── ...

~/klipper/                     ← LEAN installation (production-ready)
├── klippy/                    ← Essential Python runtime only
│   ├── extras/
│   │   └── winder.py          ← Custom winder controller
│   └── kinematics/
│       └── winder.py          ← Custom winder kinematics
├── scripts/                   ← Essential scripts only
│   ├── test_winder.py         ← Winder tests
│   └── klipper_interface.py   ← API interface
├── src/                       ← Essential firmware source
├── .config.winder-minimal     ← Build config
├── dev_build.sh               ← Quick build
├── dev_flash.sh               ← Quick flash
├── dev_test.sh                ← Run tests
├── dev_git.sh                 ← Git workflow (uses dev clone)
├── dev_update.sh              ← Update from upstream & sync
└── DEV_README.md              ← Development guide
```

## Custom Files

### Winder Controller (`klippy/extras/winder.py`)

Main winder module handling:
- BLDC motor control (PWM, DIR, Brake)
- Hall sensor RPM measurement
- Angle sensor ADC reading
- Traverse stepper control
- Winding sequence coordination

### Winder Kinematics (`klippy/kinematics/winder.py`)

Kinematics module:
- Single-axis (Y-axis traverse)
- Homing logic
- Movement validation

## Testing

### Unit Tests

```bash
cd ~/klipper
./dev_test.sh
```

### Hardware Testing

1. **Flash firmware:**
   ```bash
   ./dev_flash.sh
   ```

2. **Start Klipper service:**
   ```bash
   sudo systemctl start klipper
   ```

3. **Check status:**
   ```bash
   sudo systemctl status klipper
   tail -f /tmp/klippy.log
   ```

4. **Run winder commands:**
   ```bash
   python3 scripts/klipper_interface.py
   ```

## Updating Klipper

To pull latest changes from upstream Klipper:

```bash
cd ~/klipper
./dev_update.sh
```

This will:
- Update the dev clone (`klipper-install/klipper-dev`) from upstream
- Merge changes into your dev branch
- Sync essential files to the lean install (`~/klipper`)
- Preserve your custom files in the lean install

## Troubleshooting

### Build Errors

```bash
# Clean build
cd ~/klipper
make clean
./dev_build.sh
```

### Flash Errors

```bash
# Check MCU connection
ls /dev/serial/by-id/*Klipper*

# Try manual flash
make flash FLASH_DEVICE=/dev/serial/by-id/...
```

### Python Import Errors

```bash
# Rebuild chelper
cd ~/klipper/klippy/chelper
source ../klippy-env/bin/activate
python3 setup.py build_ext --inplace
```

## Configuration

### Build Config

Edit `.config.winder-minimal` or run:
```bash
cd ~/klipper
make menuconfig
```

### Runtime Config

Edit `~/printer.cfg` on CM4:
```bash
nano ~/printer.cfg
sudo systemctl restart klipper
```

## Remote Development on CM4

Most development work happens on the CM4 via SSH. See `REMOTE_DEVELOPMENT.md` for complete guide.

**Quick remote workflow:**
```bash
# On Mac: Edit files
nano extras/winder.py

# Sync to CM4
./scripts/sync_winder_module.sh

# Test remotely
./scripts/remote_test.sh
./scripts/remote_logs.sh
```

## Next Steps

1. Review `DEV_README.md` in `~/klipper`
2. Review `REMOTE_DEVELOPMENT.md` for SSH workflow
3. Set up your MCU config
4. Build and flash firmware
5. Start developing!

