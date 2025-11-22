# Final Pre-Archive Checklist

**⚠️ CRITICAL: Verify these before archiving!**

## Absolute Requirements (Must Have)

Run these commands to verify:

```bash
cd klipper-install

# Check critical files exist
test -f extras/winder.py && echo "✅ extras/winder.py" || echo "❌ MISSING extras/winder.py"
test -f kinematics/winder.py && echo "✅ kinematics/winder.py" || echo "❌ MISSING kinematics/winder.py"
test -f .config.winder-minimal && echo "✅ .config.winder-minimal" || echo "❌ MISSING .config.winder-minimal"
test -f install.sh && echo "✅ install.sh" || echo "❌ MISSING install.sh"
test -f SETUP_CM4_COMPLETE.sh && echo "✅ SETUP_CM4_COMPLETE.sh" || echo "❌ MISSING SETUP_CM4_COMPLETE.sh"

# Check Python syntax
python3 -m py_compile extras/winder.py && echo "✅ winder.py syntax OK" || echo "❌ winder.py syntax ERROR"
python3 -m py_compile kinematics/winder.py && echo "✅ kinematics/winder.py syntax OK" || echo "❌ kinematics/winder.py syntax ERROR"

# Check script syntax
bash -n install.sh && echo "✅ install.sh syntax OK" || echo "❌ install.sh syntax ERROR"
bash -n SETUP_CM4_COMPLETE.sh && echo "✅ SETUP_CM4_COMPLETE.sh syntax OK" || echo "❌ SETUP_CM4_COMPLETE.sh syntax ERROR"
```

## File Structure

```
klipper-install/
├── extras/
│   └── winder.py              ← REQUIRED
├── kinematics/
│   └── winder.py              ← REQUIRED
├── scripts/
│   ├── klipper_interface.py
│   ├── simple_stepper_test.py
│   └── ... (other scripts)
├── config/
│   ├── generic-bigtreetech-manta-m8p-V1_1.cfg
│   └── ... (other configs)
├── docs/
│   └── ... (documentation)
├── mp8-boot/
│   └── M8P_bootloader.bin
├── .config.winder-minimal     ← RECOMMENDED
├── install.sh                 ← REQUIRED
├── README.md
├── INSTALL_GUIDE.md
├── FRESH_START_GUIDE.md
├── CHECKLIST.md
├── VERIFICATION.md
└── FINAL_CHECKLIST.md         ← This file
```

## What This Package Contains

### Required for Winder to Work:
1. ✅ `extras/winder.py` - Winder controller module
2. ✅ `kinematics/winder.py` - Winder kinematics module

### Recommended:
3. ✅ `.config.winder-minimal` - Minimal build configuration
4. ✅ `config/generic-bigtreetech-manta-m8p-V1_1.cfg` - Full MP8 config

### Helpful:
5. ✅ `install.sh` - Installation script
6. ✅ `scripts/*.py` - Helper scripts for testing/debugging
7. ✅ `docs/` - Documentation and schematics
8. ✅ `mp8-boot/` - Bootloader files

## Archive Instructions

### 1. Verify Everything

```bash
cd klipper-install
./scripts/list_custom_files.sh  # If script exists
# OR manually verify files above
```

### 2. Create Backup

```bash
# Create timestamped backup
cp -r klipper-install klipper-install-backup-$(date +%Y%m%d-%H%M%S)
```

### 3. Move to Archive Location

```bash
# Move to safe location
mv klipper-install ~/Documents/Archive/klipper-install-$(date +%Y%m%d)

# Or to external drive
mv klipper-install /Volumes/Backup/klipper-install

# Or compress for storage
tar -czf klipper-install-$(date +%Y%m%d).tar.gz klipper-install
```

## After Archive - Testing

When you're ready to test:

1. **Clone fresh Klipper:**
   ```bash
   git clone https://github.com/Klipper3d/klipper.git ~/klipper
   ```

2. **Copy klipper-install back:**
   ```bash
   cp -r ~/Documents/Archive/klipper-install-* ~/klipper-install
   ```

3. **Install:**
   ```bash
   cd ~/klipper-install
   ./install.sh ~/klipper
   ```

4. **Build:**
   ```bash
   cd ~/klipper
   cp .config.winder-minimal .config
   make
   ```

## If Something is Missing

If verification fails:

1. **Check if files exist in main repo:**
   ```bash
   ls -la klippy/extras/winder.py
   ls -la klippy/kinematics/winder.py
   ls -la .config.winder-minimal
   ```

2. **Copy missing files:**
   ```bash
   cp klippy/extras/winder.py klipper-install/extras/
   cp klippy/kinematics/winder.py klipper-install/kinematics/
   cp .config.winder-minimal klipper-install/
   ```

3. **Re-verify:**
   ```bash
   cd klipper-install
   # Run verification commands again
   ```

## Final Notes

- ✅ This package is **self-contained** - everything needed is here
- ✅ Can be used with **any fresh Klipper clone**
- ✅ **No dependencies** on the main repo
- ✅ **Documentation included** for reference
- ✅ **Installation script** automates the process

## Ready to Archive?

If all checks pass:
- ✅ All critical files present
- ✅ Python syntax valid
- ✅ Script syntax valid
- ✅ Documentation complete

**Then you're ready to archive!**

Move `klipper-install` to a safe location and delete the main repo.

