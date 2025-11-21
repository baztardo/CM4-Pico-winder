# Temporary Klipper Clone

## Overview

The installation script clones Klipper to `tmp-klipper/` within `klipper-install`, then copies only essential files to `~/klipper`. This keeps the installation minimal while allowing you to add missing files during development.

## Essential Files Copied

The install script automatically copies these essential directories/files:

- `klippy/` - Python runtime (required)
- `lib/` - Libraries (chelper, rp2040_flash, etc.)
- `scripts/` - Build/flash scripts
- `src/` - Firmware source (needed for build)
- `.github/` - GitHub config (for version info)
- `Makefile` - Build system
- `.gitignore` - Git ignore
- `COPYING` - License
- `README.md` - Documentation
- `scripts/klippy-requirements.txt` - Python requirements

## Adding Missing Files

If you discover a missing file during development, use the helper script:

```bash
cd klipper-install
./scripts/add_missing_file.sh <relative_path>
```

**Examples:**
```bash
# Add a config file
./scripts/add_missing_file.sh config/example.cfg

# Add documentation
./scripts/add_missing_file.sh docs/Code_Overview.md

# Add a directory
./scripts/add_missing_file.sh test/
```

## Cleaning Up

Once you've identified all needed files and updated the install script, clean up the temp clone:

```bash
cd klipper-install
./scripts/cleanup_temp_clone.sh
```

Or manually:
```bash
rm -rf klipper-install/tmp-klipper
```

## Updating Essential Files List

If you find a file that should always be copied, edit `install.sh` and add it to the `ESSENTIAL_DIRS` or `ESSENTIAL_FILES` arrays in the `clone_klipper()` function.

