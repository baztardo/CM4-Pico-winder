# Cleanup Script Usage

## Where to Run It

The cleanup script can be run from **two locations**:

### Option 1: From `~/klipper` (After Install)

If you're already in `~/klipper` directory:

```bash
cd ~/klipper
./scripts/cleanup_unused_src_files.sh
```

The script will auto-detect it's in `~/klipper` and use the current directory.

### Option 2: From `klipper-install` (Before/During Install)

If you're in `klipper-install` directory:

```bash
cd ~/klipper-install
./scripts/cleanup_unused_src_files.sh ~/klipper ~/klipper/.config.winder-minimal
```

## When It Runs

### Automatic (Recommended)

The cleanup runs **automatically** during install:
- ✅ Development mode: `./install.sh --dev`
- ✅ Minimal install: `./install.sh`

It runs after copying `src/` and uses `.config.winder-minimal` to determine what to remove.

### Manual

If you want to run it manually:

```bash
# From ~/klipper
cd ~/klipper
./scripts/cleanup_unused_src_files.sh

# Or specify paths
./scripts/cleanup_unused_src_files.sh ~/klipper ~/klipper/.config.winder-minimal
```

## What It Does

1. Reads `.config.winder-minimal` (or `.config`)
2. Detects MCU type (`stm32g0b1xx`)
3. Removes:
   - Other MCU directories (`src/avr/`, `src/rp2040/`, etc.)
   - Disabled sensor files
   - Disabled display files
   - Disabled feature files

## Troubleshooting

### "No such file or directory"

**Problem:** Running from wrong directory

**Solution:**
```bash
# Check where you are
pwd

# If in ~/klipper, use:
./scripts/cleanup_unused_src_files.sh

# If in klipper-install, use:
./scripts/cleanup_unused_src_files.sh ~/klipper ~/klipper/.config.winder-minimal
```

### "src/ directory not found"

**Problem:** Klipper not installed yet

**Solution:** Run install first:
```bash
cd ~/klipper-install
./install.sh --dev
```

### "Config file not found"

**Problem:** `.config.winder-minimal` not copied

**Solution:** Copy it manually:
```bash
cp ~/klipper-install/.config.winder-minimal ~/klipper/.config.winder-minimal
```

## Quick Reference

```bash
# From ~/klipper (simplest)
cd ~/klipper
./scripts/cleanup_unused_src_files.sh

# From klipper-install (with paths)
cd ~/klipper-install  
./scripts/cleanup_unused_src_files.sh ~/klipper ~/klipper/.config.winder-minimal
```

