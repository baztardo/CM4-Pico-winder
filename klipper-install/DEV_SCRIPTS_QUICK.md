# Dev Scripts Quick Explanation

## TL;DR

**`dev_*.sh` scripts are ONLY created in `--dev` mode, NOT in production installs.**

## The Scripts

Created in `~/klipper/` when you run `./install.sh --dev`:

1. **`dev_build.sh`** - Quick build: `source venv && make`
2. **`dev_flash.sh`** - Quick flash: Auto-detect MCU and flash
3. **`dev_test.sh`** - Run tests: Execute `test_winder.py`
4. **`dev_git.sh`** - Git helper: Run git commands in dev clone
5. **`dev_update.sh`** - Update helper: Pull upstream & sync to lean install

## When Are They Created?

| Mode | Command | Dev Scripts Created? |
|------|---------|---------------------|
| **Development** | `./install.sh --dev` | ✅ YES |
| **Production** | `./install.sh` | ❌ NO |

## Production Install

When you run `./install.sh` (without `--dev`):
- ✅ Creates lean `~/klipper/` installation
- ✅ Installs custom winder files
- ✅ Sets up Python environment
- ❌ **NO `dev_*.sh` scripts**
- ❌ **NO dev helper files**

## Why They Exist

They're **convenience shortcuts** for development:
- Faster workflow (no typing long commands)
- Auto-detection (MCU, paths, etc.)
- Git workflow bridge (dev clone ↔ lean install)

You can always use standard Klipper commands instead:
```bash
# Instead of ./dev_build.sh
source klippy-env/bin/activate && make

# Instead of ./dev_flash.sh
make flash FLASH_DEVICE=/dev/serial/by-id/...
```

## Summary

- ✅ **Safe:** Only created in dev mode
- ✅ **Optional:** Just convenience scripts
- ✅ **Production clean:** No dev files in production installs
- ✅ **Can delete:** If you don't need them

