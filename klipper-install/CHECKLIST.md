# Installation Checklist

Use this checklist to verify all files are present before installing.

## Required Files ✅

- [x] `extras/winder.py` - Winder controller module
- [x] `kinematics/winder.py` - Winder kinematics module

## Recommended Files ✅

- [x] `.config.winder-minimal` - Minimal build configuration
- [x] `config/generic-bigtreetech-manta-m8p-V1_1.cfg` - Full MP8 config

## Optional Files ✅

- [x] `scripts/klipper_interface.py` - Python interface to Klipper API
- [x] `scripts/simple_stepper_test.py` - Basic stepper test
- [x] `scripts/check_traverse_status.py` - Traverse status check
- [x] `scripts/diagnose_everything.py` - System diagnostic
- [x] `scripts/test_winder.py` - Comprehensive winder test
- [x] `scripts/fix_mcu_shutdown.py` - Fix MCU shutdown
- [x] `scripts/check_winder_logs.py` - Filter winder logs
- [x] `scripts/diagnose_endstop.py` - Endstop diagnostic
- [x] `scripts/winder_control.py` - Winder control interface
- [x] `scripts/winding_sequence.py` - Winding sequence

## Documentation ✅

- [x] `README.md` - Main documentation
- [x] `INSTALL_GUIDE.md` - Installation guide
- [x] `CHECKLIST.md` - This file

## Installation Scripts ✅

- [x] `install.sh` - Main installation script

## Other Files ✅

- [x] `docs/` - Documentation and schematics
- [x] `mp8-boot/` - Bootloader files
- [x] `.gitignore` - Git ignore file

## Verification

After installation, verify:

```bash
# Check required files exist in Klipper
ls -la ~/klipper/klippy/extras/winder.py
ls -la ~/klipper/klippy/kinematics/winder.py

# Test import
cd ~/klipper
python3 -c "from extras import winder; print('OK')"
```

## File Count

- **Required:** 2 files
- **Recommended:** 2 files
- **Optional:** ~10 scripts
- **Documentation:** 3 files
- **Total:** ~17 files

