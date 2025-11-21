# Quick Start - Development Environment

## Setup Development Environment

```bash
cd klipper-install
./install.sh --dev
```

This creates a **full Klipper development environment** at `~/klipper` with:
- Complete git repository
- Development branch: `winder-dev`
- Helper scripts for build/flash/test
- Custom winder files installed
- Python virtual environment

## Daily Development Workflow

```bash
cd ~/klipper

# 1. Make your changes
nano klippy/extras/winder.py

# 2. Build firmware
./dev_build.sh

# 3. Flash to MCU
./dev_flash.sh

# 4. Test
./dev_test.sh
```

## Helper Scripts

- `./dev_build.sh` - Build firmware (lean install)
- `./dev_flash.sh` - Flash to MCU (auto-detects)
- `./dev_test.sh` - Run tests
- `./dev_git.sh` - Git workflow (uses dev clone)
- `./dev_update.sh` - Update from upstream & sync to lean install

## Git Workflow

**Note:** Git operations use the dev clone, not the lean install!

```bash
# Check status (uses dev clone)
./dev_git.sh status

# After editing files in ~/klipper, copy to dev clone:
cp klippy/extras/winder.py ../klipper-install/klipper-dev/klippy/extras/

# Commit changes (uses dev clone)
./dev_git.sh add klippy/extras/winder.py
./dev_git.sh commit -m "Add feature X"

# Update from upstream (syncs both)
./dev_update.sh
```

## File Locations

- **Klipper:** `~/klipper`
- **Custom files:** `~/klipper/klippy/extras/winder.py`, `~/klipper/klippy/kinematics/winder.py`
- **Config:** `~/printer.cfg` (on CM4)
- **Logs:** `/tmp/klippy.log` (on CM4)

## Full Documentation

See `DEVELOPMENT.md` for complete guide.

