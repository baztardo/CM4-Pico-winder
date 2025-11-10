# Rebuild Summary - Clean Klipper Installation

## Files Created

All necessary custom files have been recreated for the CNC Winder:

### 1. **klippy/kinematics/winder.py**
   - Winder kinematics module
   - Only uses Y-axis (traverse stepper)
   - Implements `home()` method for traverse homing
   - Requires homing before moves
   - Uses cartesian kinematics for Y-axis

### 2. **klippy/extras/winder.py**
   - Winder controller module
   - Handles motor control, Hall sensors, and coordinated motion
   - Implements G-code commands: `WINDER_START`, `WINDER_STOP`, `WINDER_STATUS`, etc.
   - Timer-based RPM updates and sync adjustments
   - Error handling for pin operations

### 3. **config/printer.cfg**
   - Complete printer configuration for SKR Pico
   - MCU serial port configuration
   - Traverse stepper (Y-axis) configuration
   - TMC2209 settings
   - Winder module parameters
   - G-code macros for homing and winding

## Installation Steps

### On CM4:

1. **Copy files to CM4:**
   ```bash
   # From your Mac, copy files to CM4:
   scp klippy/kinematics/winder.py winder@<CM4_IP>:~/klipper/klippy/kinematics/
   scp klippy/extras/winder.py winder@<CM4_IP>:~/klipper/klippy/extras/
   scp config/printer.cfg winder@<CM4_IP>:~/klipper/config/
   ```

2. **Update serial port in printer.cfg:**
   ```bash
   # On CM4, check actual serial port:
   ls -la /dev/serial/by-id/usb-Klipper_rp2040_*
   
   # Edit printer.cfg and update the serial: line
   nano ~/klipper/config/printer.cfg
   ```

3. **Restart Klipper:**
   ```bash
   sudo systemctl restart klipper
   tail -f /tmp/klippy.log
   ```

## GitHub Conflicts Resolution

Your branch has diverged from origin/main. To resolve:

### Option 1: Keep your local changes (recommended)
```bash
# Add the new files
git add klippy/kinematics/winder.py klippy/extras/winder.py config/printer.cfg

# Commit
git commit -m "Rebuild: Add winder kinematics, controller, and config"

# Force push (if you want to overwrite remote)
git push --force-with-lease origin main
```

### Option 2: Merge with remote
```bash
# Pull and merge
git pull origin main

# Resolve any conflicts manually
# Then commit and push
git add .
git commit -m "Merge: Rebuild winder files"
git push origin main
```

### Option 3: Start fresh branch
```bash
# Create new branch from current state
git checkout -b winder-rebuild
git add klippy/kinematics/winder.py klippy/extras/winder.py config/printer.cfg
git commit -m "Rebuild: Add winder files"
git push origin winder-rebuild
```

## Testing

After installation, test with:

```bash
# Check Klipper status
python3 ~/klipper/scripts/test_commands.py /tmp/klippy_uds "STATUS"

# Test winder status
python3 ~/klipper/scripts/test_commands.py /tmp/klippy_uds "WINDER_STATUS"

# Home traverse
python3 ~/klipper/scripts/test_commands.py /tmp/klippy_uds "G28 Y"
```

## Notes

- The `Coord` API uses tuple format: `toolhead.Coord((x, y, z, e))`
- Pin operations have error handling to prevent crashes if pins aren't ready
- Timer registration is deferred to `_handle_connect()` to avoid timing issues
- All winder parameters are configurable in `printer.cfg`

