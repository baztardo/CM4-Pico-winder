# Codebase Cleanup Plan

## Problem
The codebase has duplicate code and temporary debugging files from the AI assistant's work.

## Correct Structure (What to KEEP)

### Core Modules
```
klipper-install/
├── kinematics/
│   └── winder.py              ✓ KEEP - Kinematics only (~107 lines)
├── extras/
│   ├── angle_sensor.py        ✓ KEEP - 12-bit angle sensor module
│   ├── bldc_motor.py          ✓ KEEP - BLDC motor control
│   ├── spindle_hall.py        ✓ KEEP - Spindle Hall sensor
│   ├── traverse.py            ✓ KEEP - Traverse control module
│   ├── winder_control.py      ✓ KEEP - Main coordinator
│   └── winder.py              ✗ DELETE - Monolithic duplicate (1463 lines)
└── scripts/
    ├── klipper_interface.py   ✓ KEEP - API interface
    ├── winding_sequence.py    ✓ KEEP - High-level winding control
    └── winder_control.py      ✗ DELETE - Duplicate script version
```

### Scripts to KEEP (Essential)
- `klipper_interface.py` - Core API interface
- `winding_sequence.py` - High-level winding sequences
- `sync_to_cm4.sh` - File sync utility
- `diagnose_homing.sh` - Useful diagnostic

### Scripts to DELETE (Temporary debugging)
All the test/diagnostic scripts created during troubleshooting:
- `test_*.sh/py` - Temporary hardware tests
- `fix_*.sh/py` - One-time fixes
- `check_*.sh/py` - Debugging checks
- `diagnose_*.sh/py` (except diagnose_homing.sh)
- `measure_*.sh` - Speed measurement scripts
- `apply_*.sh` - Config application scripts
- `patch_*.sh` - Temporary patches

Total: ~90 temporary scripts to remove

## Files to DELETE

###

 1. Duplicate monolithic file
```bash
rm klipper-install/extras/winder.py
```

### 2. Duplicate script
```bash
rm klipper-install/scripts/winder_control.py
```

### 3. Temporary debugging scripts (keep only essential ones)
Create `klipper-install/scripts/archive/` and move old scripts there for reference.

## Action Items

1. **Verify modular files are complete** - Check that the split modules have all functionality
2. **Delete duplicates** - Remove winder.py from extras/
3. **Clean scripts folder** - Archive ~90 temporary test scripts
4. **Update documentation** - Document the modular architecture
5. **Test on CM4** - Ensure everything still works after cleanup

## File Comparison

### extras/winder.py (TO DELETE)
- 1463 lines total
- Lines 1-100: Kinematics (DUPLICATE of kinematics/winder.py)
- Lines 101-1463: Monolithic controller (DUPLICATE of modular extras/ files)
- Contains combined code for angle sensor, BLDC, hall, traverse, control

### Modular files (TO KEEP)
- `kinematics/winder.py` (~107 lines) - Clean kinematics only
- `extras/winder_control.py` (~330 lines) - Coordinator
- `extras/angle_sensor.py` (~306 lines) - Angle sensor
- `extras/bldc_motor.py` (~350 lines) - BLDC motor
- `extras/spindle_hall.py` (~150 lines) - Hall sensor
- `extras/traverse.py` (~161 lines) - Traverse control

Total modular: ~1404 lines (cleaner, more maintainable)



