# Klipper Core Code Patches

This document tracks all modifications made to Klipper's core codebase. These patches must be applied to a fresh Klipper clone for the winder project to work correctly.

## Overview

The winder project requires modifications to Klipper's core code in addition to custom modules. This document lists all patches and provides scripts to apply them automatically.

## Patches Required

### 1. Winder Kinematics C Helper (`kin_winder.c`)

**Purpose**: Adds a custom C helper for winder kinematics to enable optimized position calculations and future real-time spindle synchronization.

**Files Modified**:
- `klippy/chelper/__init__.py` - Adds `kin_winder.c` to compilation
- `klippy/chelper/kin_winder.c` - New file (added)

**Changes**:
1. **SOURCE_FILES list** (line ~25): Add `'kin_winder.c'`
2. **Function definitions** (after `defs_kin_generic_cartesian`): Add `defs_kin_winder`
3. **defs_all list** (line ~242): Add `defs_kin_winder`

**Patch Script**: `scripts/patch_kin_winder.sh`

**Manual Application**:

```bash
# 1. Copy kin_winder.c to Klipper chelper directory
cp klipper-install/klippy/chelper/kin_winder.c ~/klipper/klippy/chelper/

# 2. Edit ~/klipper/klippy/chelper/__init__.py:

# Add to SOURCE_FILES list (around line 25):
SOURCE_FILES = [
    ...
    'kin_generic.c',
    'kin_winder.c'  # <-- ADD THIS LINE
]

# Add function definitions (after defs_kin_generic_cartesian, around line 123):
defs_kin_winder = """
    struct stepper_kinematics *winder_stepper_alloc(char axis);
"""

# Add to defs_all list (around line 242):
defs_all = [
    ...
    defs_kin_generic_cartesian,
    defs_kin_winder,  # <-- ADD THIS LINE
]
```

**Verification**:
```bash
# Check if patch was applied
grep -n "kin_winder" ~/klipper/klippy/chelper/__init__.py

# Should show:
# - Line with 'kin_winder.c' in SOURCE_FILES
# - Line with defs_kin_winder = """
# - Line with defs_kin_winder in defs_all
```

**Compilation**:
The C helper (`c_helper.so`) is **automatically compiled** when Klipper starts. This happens in Python via `klippy/chelper/__init__.py`:

1. **First Klipper Start**: When Klipper starts for the first time after patching, Python detects that `c_helper.so` doesn't exist or is outdated
2. **Automatic Build**: Python calls `check_build_c_library()` which:
   - Checks if any source files changed
   - Compiles all C files (including `kin_winder.c`) into `c_helper.so`
   - Uses GCC with optimization flags (`-O2`, `-flto`, etc.)
3. **Log Output**: You'll see in Klipper logs:
   ```
   Building C code module c_helper.so
   ```

**Manual Compilation** (for testing):
```bash
cd ~/klipper/klippy/chelper
python3 -c "from chelper import get_ffi; get_ffi()"
```

**Note**: The chelper compilation happens **automatically** - no manual steps needed! The patch script just modifies the Python code that handles compilation.

---

## Applying All Patches

### Automated Method (Recommended)

Run the patch script:
```bash
cd klipper-install
./scripts/patch_kin_winder.sh [KLIPPER_DIR]
```

Where `KLIPPER_DIR` is the path to your Klipper installation (default: `~/klipper`).

### Manual Method

1. Follow the manual application steps for each patch above
2. Verify each patch was applied correctly
3. Restart Klipper to trigger C helper compilation

---

## Patch Status Tracking

| Patch | Status | Applied By | Date | Notes |
|-------|--------|-----------|------|-------|
| `kin_winder.c` | Required | `patch_kin_winder.sh` | 2024-11-21 | Adds winder kinematics C helper |

---

## Troubleshooting

### C Helper Won't Compile

If `c_helper.so` fails to compile after patching:

1. **Check GCC is installed**:
   ```bash
   gcc --version
   ```

2. **Check Python CFFI is installed**:
   ```bash
   python3 -c "import cffi; print(cffi.__version__)"
   ```

3. **Check for syntax errors in kin_winder.c**:
   ```bash
   cd ~/klipper/klippy/chelper
   gcc -Wall -c kin_winder.c -o /tmp/test.o
   ```

4. **Check __init__.py syntax**:
   ```bash
   python3 -m py_compile ~/klipper/klippy/chelper/__init__.py
   ```

### Patch Already Applied

If you see "already patched" warnings:
- The patch script detected existing modifications
- You can safely re-run the patch script (it will ask for confirmation)
- Or manually verify the changes match the expected patch

### Reverting Patches

To revert a patch:
1. Restore from backup (patch script creates `.backup.YYYYMMDD_HHMMSS` files)
2. Or manually undo the changes listed in the "Manual Application" section
3. Delete `kin_winder.c` if it was added

---

## Future Patches

When adding new patches to Klipper core code:

1. **Document the patch** in this file:
   - Purpose
   - Files modified
   - Specific changes
   - Verification steps

2. **Create a patch script** in `scripts/`:
   - Name: `patch_<feature>.sh`
   - Make it idempotent (safe to run multiple times)
   - Include backup creation
   - Include verification

3. **Update install scripts** to call the patch script automatically

4. **Test** on a fresh Klipper clone

---

## Related Documentation

- `dev/KIN_WINDER_C_HELPER.md` - Detailed explanation of the winder C helper
- `scripts/patch_kin_winder.sh` - Automated patch script
- `scripts/patch_kconfig_conditional.sh` - Example of another patch script
- `scripts/patch_makefile_conditional.sh` - Example of another patch script

