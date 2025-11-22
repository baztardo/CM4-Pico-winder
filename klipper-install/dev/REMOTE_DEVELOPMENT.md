# Remote Development on CM4

## Overview

Development work for the CNC Guitar Winder happens on the CM4 via SSH. This guide covers the remote development workflow.

## Prerequisites

1. **SSH Access:** CM4 accessible via SSH
   ```bash
   ssh winder@winder.local
   ```

2. **SSH Keys:** Set up passwordless SSH (optional but recommended)
   ```bash
   ./scripts/SETUP_SSH_KEYS.sh winder.local winder
   ```

## Remote Development Workflow

### Initial Setup

**On your Mac:**

```bash
cd klipper-install

# Sync entire klipper-install to CM4
./scripts/sync_to_cm4.sh

# Or setup complete remote dev environment
./scripts/remote_dev_setup.sh
```

**On CM4 (via SSH):**

```bash
ssh winder@winder.local
cd ~/klipper-install
./install.sh --dev
```

### Daily Development Cycle

**1. Edit files locally (on Mac):**
```bash
# Edit winder modules
nano extras/winder.py
nano kinematics/winder.py
```

**2. Sync changes to CM4:**
```bash
# Quick sync (just winder modules)
./scripts/sync_winder_module.sh

# Or full sync (entire klipper-install)
./scripts/sync_to_cm4.sh
```

**3. Test on CM4:**
```bash
# Option A: SSH and run commands
ssh winder@winder.local
cd ~/klipper
./dev_build.sh
./dev_flash.sh
sudo systemctl restart klipper

# Option B: Use remote scripts
./scripts/remote_test.sh
./scripts/remote_logs.sh
```

**4. View logs:**
```bash
# Tail logs remotely
./scripts/remote_logs.sh

# Or SSH and tail
ssh winder@winder.local 'tail -f /tmp/klippy.log'
```

## Helper Scripts

### File Sync

- **`sync_to_cm4.sh`** - Sync entire klipper-install folder
  ```bash
  ./scripts/sync_to_cm4.sh [host] [user]
  ```

- **`sync_winder_module.sh`** - Quick sync of winder modules only
  ```bash
  ./scripts/sync_winder_module.sh [host] [user]
  ```

### Remote Operations

- **`remote_dev_setup.sh`** - Complete remote setup
  ```bash
  ./scripts/remote_dev_setup.sh [host] [user]
  ```

- **`remote_test.sh`** - Run tests remotely
  ```bash
  ./scripts/remote_test.sh [host] [user] [command]
  ```

- **`remote_logs.sh`** - Tail logs remotely
  ```bash
  ./scripts/remote_logs.sh [host] [user] [lines]
  ```

- **`remote_shell.sh`** - Interactive SSH shell
  ```bash
  ./scripts/remote_shell.sh [host] [user]
  ```

## Development Workflow Examples

### Example 1: Quick Iteration

```bash
# 1. Edit locally
nano extras/winder.py

# 2. Sync to CM4
./scripts/sync_winder_module.sh

# 3. Restart Klipper on CM4
ssh winder@winder.local 'sudo systemctl restart klipper'

# 4. Watch logs
./scripts/remote_logs.sh
```

### Example 2: Full Build & Flash

```bash
# 1. Sync everything
./scripts/sync_to_cm4.sh

# 2. SSH to CM4
ssh winder@winder.local

# 3. On CM4:
cd ~/klipper
./dev_build.sh
./dev_flash.sh
sudo systemctl restart klipper

# 4. Test
./dev_test.sh
```

### Example 3: Debugging

```bash
# 1. Open interactive shell
./scripts/remote_shell.sh

# 2. In shell:
cd ~/klipper
tail -f /tmp/klippy.log | grep -i winder

# 3. In another terminal, trigger action
./scripts/remote_test.sh
```

## File Locations

### On Mac
- **klipper-install:** `~/Desktop/klipper-install/` (or wherever you cloned it)
- **Source files:** `klipper-install/extras/winder.py`, `klipper-install/kinematics/winder.py`

### On CM4
- **klipper-install:** `~/klipper-install/`
- **Klipper:** `~/klipper/` (lean install)
- **Dev clone:** `~/klipper-install/klipper-dev/` (full clone)
- **Config:** `~/printer.cfg`
- **Logs:** `/tmp/klippy.log`

## Tips

1. **Use SSH keys** for passwordless access:
   ```bash
   ./scripts/SETUP_SSH_KEYS.sh winder.local winder
   ```

2. **Keep CM4 hostname consistent:**
   - Default: `winder.local`
   - Or use IP: `192.168.x.x`

3. **Quick sync workflow:**
   - Edit locally → `sync_winder_module.sh` → Restart Klipper → Check logs

4. **Full rebuild workflow:**
   - Edit locally → `sync_to_cm4.sh` → SSH → Build → Flash → Test

5. **Watch logs while testing:**
   ```bash
   # Terminal 1: Watch logs
   ./scripts/remote_logs.sh
   
   # Terminal 2: Run test
   ./scripts/remote_test.sh
   ```

## Troubleshooting

### SSH Connection Issues

```bash
# Test connection
ssh winder@winder.local

# Check hostname resolution
ping winder.local

# Use IP instead
./scripts/sync_to_cm4.sh 192.168.1.100 winder
```

### File Sync Issues

```bash
# Check if rsync is installed
which rsync

# Install if needed (on Mac)
brew install rsync

# Manual sync
scp extras/winder.py winder@winder.local:~/klipper/klippy/extras/
```

### Permission Issues

```bash
# Fix permissions on CM4
ssh winder@winder.local 'chmod +x ~/klipper-install/scripts/*.sh'
```

## Next Steps

1. Set up SSH keys for passwordless access
2. Sync klipper-install to CM4
3. Run initial setup on CM4
4. Start developing!

