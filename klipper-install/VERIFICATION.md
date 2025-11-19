# Pre-Archive Verification

**Date:** $(date)
**Purpose:** Verify all files before archiving and restarting fresh

## Critical Files Check ✅

### Required Python Modules
- [x] `extras/winder.py` - Winder controller (REQUIRED)
- [x] `kinematics/winder.py` - Winder kinematics (REQUIRED)

### Build Configuration
- [x] `.config.winder-minimal` - Minimal build config (RECOMMENDED)

### Configuration Files
- [x] `config/generic-bigtreetech-manta-m8p-V1_1.cfg` - Full MP8 config
- [x] `config/manta-m8p-minimal-test.cfg` - Minimal test config
- [x] Other config files for reference

### Installation Scripts
- [x] `install.sh` - Main installation script
- [x] `scripts/add_custom_files_to_klipper.sh` - Alternative installer
- [x] `scripts/list_custom_files.sh` - List all files

### Helper Scripts
- [x] `scripts/klipper_interface.py` - Python API interface
- [x] `scripts/simple_stepper_test.py` - Basic stepper test
- [x] `scripts/check_traverse_status.py` - Traverse status
- [x] `scripts/diagnose_everything.py` - System diagnostic
- [x] `scripts/test_winder.py` - Comprehensive test
- [x] `scripts/fix_mcu_shutdown.py` - MCU shutdown fix
- [x] `scripts/check_winder_logs.py` - Log filtering
- [x] `scripts/diagnose_endstop.py` - Endstop diagnostic
- [x] `scripts/winder_control.py` - Control interface
- [x] `scripts/winding_sequence.py` - Winding sequence

### Documentation
- [x] `README.md` - Main documentation
- [x] `INSTALL_GUIDE.md` - Installation guide
- [x] `CHECKLIST.md` - Verification checklist
- [x] `VERIFICATION.md` - This file
- [x] `docs/` - Additional documentation

### Bootloader
- [x] `mp8-boot/M8P_bootloader.bin` - Bootloader binary
- [x] `mp8-boot/README.md` - Bootloader docs

## File Count

```bash
# Count files
find . -type f | wc -l
find . -name "*.py" | wc -l
find . -name "*.cfg" | wc -l
find . -name "*.md" | wc -l
find . -name "*.sh" | wc -l
```

## Verification Commands

Run these to verify before archiving:

```bash
cd klipper-install

# Check critical files exist
test -f extras/winder.py && echo "✓ winder.py" || echo "✗ MISSING winder.py"
test -f kinematics/winder.py && echo "✓ kinematics/winder.py" || echo "✗ MISSING kinematics/winder.py"
test -f .config.winder-minimal && echo "✓ .config.winder-minimal" || echo "✗ MISSING .config.winder-minimal"
test -f install.sh && echo "✓ install.sh" || echo "✗ MISSING install.sh"

# Check Python syntax
python3 -m py_compile extras/winder.py && echo "✓ winder.py syntax OK" || echo "✗ winder.py syntax ERROR"
python3 -m py_compile kinematics/winder.py && echo "✓ kinematics/winder.py syntax OK" || echo "✗ kinematics/winder.py syntax ERROR"

# List all files
find . -type f | sort
```

## Archive Checklist

Before moving this folder:

1. ✅ Verify all critical files exist (run commands above)
2. ✅ Test install script: `./install.sh --help` or check syntax
3. ✅ Verify Python files compile without errors
4. ✅ Check file permissions: `chmod +x install.sh`
5. ✅ Create backup: `cp -r klipper-install klipper-install-backup`

## After Archive - Fresh Start

### On Your Mac:

1. **Clone fresh Klipper:**
   ```bash
   cd ~
   git clone https://github.com/Klipper3d/klipper.git
   ```

2. **Copy klipper-install folder back:**
   ```bash
   cp -r /path/to/archive/klipper-install ~/klipper-install
   ```

3. **Install custom files:**
   ```bash
   cd ~/klipper-install
   ./install.sh ~/klipper
   ```

### On CM4:

1. **Clean up:**
   ```bash
   sudo systemctl stop klipper
   rm -rf ~/klipper
   ```

2. **Clone fresh Klipper:**
   ```bash
   cd ~
   git clone https://github.com/Klipper3d/klipper.git
   ```

3. **Copy klipper-install from Mac:**
   ```bash
   # From Mac:
   scp -r klipper-install winder@winder.local:~/klipper-install
   ```

4. **Install custom files:**
   ```bash
   cd ~/klipper-install
   ./install.sh ~/klipper
   ```

5. **Build firmware:**
   ```bash
   cd ~/klipper
   cp .config.winder-minimal .config
   make menuconfig  # Verify settings
   make
   ```

6. **Copy config:**
   ```bash
   cp ~/klipper-install/config/generic-bigtreetech-manta-m8p-V1_1.cfg ~/printer.cfg
   # Edit serial port in printer.cfg
   nano ~/printer.cfg
   ```

## What's NOT Included (By Design)

These are NOT in klipper-install (they're in the main repo):

- Core Klipper source code (clone from GitHub)
- Build outputs (`out/` directory)
- Git history (`.git/` directory)
- Temporary files

## Final Verification

Before archiving, run:

```bash
cd klipper-install
./scripts/list_custom_files.sh
```

This will show all files that need to be added to Klipper.

## Archive Location

Store `klipper-install` folder in:
- External drive
- Cloud storage (GitHub, Dropbox, etc.)
- Safe backup location

**Remember:** This folder contains everything needed to add winder support to a fresh Klipper installation!

