# Development Helper Scripts Explained

## Overview

The `dev_*.sh` scripts are **development helper scripts** created in `~/klipper/` to make development workflow easier. They are **ONLY created in development mode** (`--dev` flag), **NOT in production/minimal installs**.

## When Are They Created?

- ✅ **Created:** When running `./install.sh --dev`
- ❌ **NOT created:** When running `./install.sh` (minimal/production install)

## Scripts Created

### `dev_build.sh`
**Purpose:** Quick firmware build script

**What it does:**
- Activates Python virtual environment
- Runs `make` to build firmware

**Usage:**
```bash
cd ~/klipper
./dev_build.sh
```

**Equivalent to:**
```bash
cd ~/klipper
source klippy-env/bin/activate
make
```

---

### `dev_flash.sh`
**Purpose:** Quick firmware flash script with auto-detection

**What it does:**
- Auto-detects MCU from `/dev/serial/by-id/`
- Activates Python virtual environment
- Runs `make flash` with detected device

**Usage:**
```bash
cd ~/klipper
./dev_flash.sh
```

**Equivalent to:**
```bash
cd ~/klipper
MCU=$(ls /dev/serial/by-id/*Klipper* | head -1)
make flash FLASH_DEVICE="$MCU"
```

---

### `dev_test.sh`
**Purpose:** Run winder tests

**What it does:**
- Activates Python virtual environment
- Runs `scripts/test_winder.py` if available

**Usage:**
```bash
cd ~/klipper
./dev_test.sh
```

**Equivalent to:**
```bash
cd ~/klipper
source klippy-env/bin/activate
python3 scripts/test_winder.py
```

---

### `dev_git.sh`
**Purpose:** Git workflow helper (uses dev clone, not lean install)

**What it does:**
- Runs git commands in `klipper-install/klipper-dev/` (full clone)
- Allows git operations without navigating to dev clone

**Usage:**
```bash
cd ~/klipper
./dev_git.sh status
./dev_git.sh commit -m "Add feature"
./dev_git.sh push
```

**Why needed:**
- Lean install (`~/klipper`) is NOT a git repo (just copied files)
- Dev clone (`klipper-install/klipper-dev/`) IS a git repo
- This script bridges the gap

---

### `dev_update.sh`
**Purpose:** Update from upstream Klipper and sync to lean install

**What it does:**
1. Updates `klipper-install/klipper-dev/` from upstream
2. Syncs essential files to `~/klipper/` (lean install)

**Usage:**
```bash
cd ~/klipper
./dev_update.sh
```

**What happens:**
- Fetches latest Klipper from upstream
- Merges into dev clone
- Copies updated essential files to lean install
- Preserves your custom files

---

## Production vs Development

### Development Mode (`--dev`)
```bash
./install.sh --dev
```

**Creates:**
- `~/klipper/` - Lean install
- `klipper-install/klipper-dev/` - Full clone
- `~/klipper/dev_*.sh` - Helper scripts ✅
- `~/klipper/DEV_README.md` - Dev guide

**Use case:** Active development, testing, git workflow

---

### Production/Minimal Mode (no `--dev`)
```bash
./install.sh
```

**Creates:**
- `~/klipper/` - Lean install only
- `klipper-install/tmp-klipper/` - Temp clone (can be deleted)
- **NO `dev_*.sh` scripts** ❌
- **NO dev helper files**

**Use case:** Production deployment, minimal footprint

---

## File Locations

### Development Mode
```
~/klipper/
├── dev_build.sh          ← Created
├── dev_flash.sh          ← Created
├── dev_test.sh           ← Created
├── dev_git.sh            ← Created
├── dev_update.sh         ← Created
├── DEV_README.md         ← Created
└── ... (Klipper files)
```

### Production Mode
```
~/klipper/
├── (NO dev_*.sh scripts) ← NOT created
└── ... (Klipper files only)
```

---

## Summary

- **`dev_*.sh` scripts:** Development convenience scripts
- **Only created:** In `--dev` mode
- **NOT created:** In production/minimal installs
- **Purpose:** Faster development workflow
- **Safe to delete:** If you don't need them (they're just shortcuts)

These scripts are **optional helpers** - you can always use the standard Klipper commands (`make`, `make flash`, etc.) instead.

