# Klipper Patching Summary

## Quick Reference

All Klipper core code modifications are documented and automated via patch scripts.

### Apply All Patches

```bash
cd klipper-install
./scripts/patch_kin_winder.sh ~/klipper
```

Or let the install script handle it automatically:
```bash
./install.sh
```

### What Gets Patched

1. **`kin_winder.c` C Helper** - Adds winder kinematics C helper
   - File: `klippy/chelper/kin_winder.c` (new file)
   - Modifies: `klippy/chelper/__init__.py` (3 changes)
   - Script: `scripts/patch_kin_winder.sh`

### Chelper Compilation

**Important**: The C helper (`c_helper.so`) compiles **automatically** when Klipper starts. No manual compilation needed!

- Python detects missing/outdated `c_helper.so`
- Automatically compiles all C files including `kin_winder.c`
- Happens on first Klipper start after patching
- See logs: `Building C code module c_helper.so`

### Documentation

- **Full Details**: `dev/KLIPPER_PATCHES.md` - Complete patch documentation
- **C Helper Details**: `dev/KIN_WINDER_C_HELPER.md` - Winder C helper explanation

### Verification

Check if patches are applied:
```bash
# Check kin_winder.c exists
ls ~/klipper/klippy/chelper/kin_winder.c

# Check __init__.py is patched
grep -n "kin_winder" ~/klipper/klippy/chelper/__init__.py
```

Expected output:
- Line with `'kin_winder.c'` in SOURCE_FILES
- Line with `defs_kin_winder = """`
- Line with `defs_kin_winder` in defs_all list

