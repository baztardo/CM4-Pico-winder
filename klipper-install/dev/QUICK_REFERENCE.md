# Quick Reference - Remote Development

## Common Tasks

### Sync Files to CM4
```bash
# Quick sync (winder modules only)
./scripts/sync_winder_module.sh

# Full sync (entire klipper-install)
./scripts/sync_to_cm4.sh
```

### Remote Operations
```bash
# Run tests on CM4
./scripts/remote_test.sh

# Watch logs
./scripts/remote_logs.sh

# Interactive shell
./scripts/remote_shell.sh
```

### On CM4 (via SSH)
```bash
# Connect
ssh winder@winder.local

# Build firmware
cd ~/klipper && ./dev_build.sh

# Flash firmware
./dev_flash.sh

# Restart Klipper
sudo systemctl restart klipper

# View logs
tail -f /tmp/klippy.log
```

## File Locations

**Mac:**
- `~/Desktop/klipper-install/extras/winder.py`
- `~/Desktop/klipper-install/kinematics/winder.py`

**CM4:**
- `~/klipper/klippy/extras/winder.py`
- `~/klipper/klippy/kinematics/winder.py`
- `~/printer.cfg`
- `/tmp/klippy.log`

## Quick Iteration Workflow

```bash
# 1. Edit locally
nano extras/winder.py

# 2. Sync to CM4
./scripts/sync_winder_module.sh

# 3. Restart Klipper
ssh winder@winder.local 'sudo systemctl restart klipper'

# 4. Watch logs
./scripts/remote_logs.sh
```

## Default Settings

- **CM4 Host:** `winder.local`
- **CM4 User:** `winder`
- **Override:** Pass as arguments to scripts

