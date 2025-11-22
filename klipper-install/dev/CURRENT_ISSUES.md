# Current Hardware Testing Issues

## Status: MCU Connected ✓

Good news: MCU is now connected and working!

## Issues Found

### 1. TMC2209 Communication Failure ⚠️

**Error:**
```
TMC stepper_y failed to init: Unable to read tmc uart 'stepper_y' register IFCNT
Unable to obtain tmc stepper_y phase
```

**Impact:**
- Traverse stepper cannot use TMC2209 features (microstepping, current control, etc.)
- Stepper may still work in basic mode, but without TMC2209 benefits

**Possible Causes:**
1. UART pin (PF13) wiring issue
2. TMC2209 not powered
3. TMC2209 UART address mismatch
4. TMC2209 driver board faulty

**Troubleshooting:**
```bash
# Check TMC2209 communication
python3 ~/klipper-install/scripts/diagnose_tmc2209.py

# Test stepper without TMC2209 (comment out [tmc2209 stepper_y] section)
# Edit printer.cfg and restart Klipper
```

**Fix:**
- Check wiring: PF13 → TMC2209 UART pin
- Verify TMC2209 power (should have LED if powered)
- Check TMC2209 UART address (default should work)
- Try different UART pin if available

---

### 2. Log Spam (Fixed in Local Code, Needs Sync) ⚠️

**Issue:**
- "Winder: ADC debug" messages every few seconds
- "Winder: Angle sensor - angle=" messages flooding logs
- "Winder: Spindle Hall - freq=" messages every few seconds

**Status:**
- ✅ Fixed in local `klipper-install/extras/winder.py` (logging disabled)
- ⚠️ CM4 still has old version with logging enabled

**Fix:**
```bash
# On CM4:
cd ~/klipper-install/scripts
./fix_log_spam_and_tmc.sh

# Or manually sync:
cp ~/klipper-install/extras/winder.py ~/klipper/klippy/extras/winder.py
sudo systemctl restart klipper
```

**Note:**
- The `analog_in_state` messages are normal MCU messages (not Python logs)
- Filter them: `tail -f /tmp/klippy.log | grep -v analog_in_state`

---

### 3. Angle Sensor Saturation (Expected) ℹ️

**Status:**
- Angle sensor is saturated (reading 0.9996-1.0000, all showing 360°)
- This is expected with current voltage setup
- Software handles saturation using Hall sensor

**Message:**
```
Winder: Angle sensor auto-calibrated - ADC range: 0.9996 to 1.0000 (span: 0.0004, VCC: 3.85V) (SATURATED at max - consider voltage divider to use full range)
```

**Impact:**
- Angle sensor cannot measure precise angle (stuck at 360°)
- Hall sensor is used for RPM tracking (works fine)
- For precise angle measurement, voltage divider needed

**Action:**
- Can continue testing with Hall sensor only
- Voltage divider can be added later for full angle range

---

## Testing Priority

### High Priority (Blocking)
1. ✅ **MCU Connection** - FIXED
2. ⚠️ **TMC2209 Communication** - NEEDS FIXING
   - Blocks proper stepper control
   - Test without TMC2209 first if needed

### Medium Priority (Annoying but not blocking)
3. ⚠️ **Log Spam** - NEEDS SYNC
   - Makes debugging harder
   - Fix by syncing updated winder.py

### Low Priority (Expected behavior)
4. ℹ️ **Angle Sensor Saturation** - EXPECTED
   - Software handles it
   - Can add voltage divider later

---

## Next Steps

1. **Fix TMC2209:**
   ```bash
   # Check wiring and power
   # Test communication
   python3 ~/klipper-install/scripts/diagnose_tmc2209.py
   ```

2. **Sync Updated Code:**
   ```bash
   # On CM4:
   cd ~/klipper-install/scripts
   ./fix_log_spam_and_tmc.sh
   ```

3. **Test Traverse (with or without TMC2209):**
   ```bash
   # Test homing
   python3 ~/klipper-install/scripts/klipper_interface.py -g "G28 Y"
   
   # Test movement
   python3 ~/klipper-install/scripts/klipper_interface.py -g "G91"
   python3 ~/klipper-install/scripts/klipper_interface.py -g "G1 Y10 F100"
   ```

4. **Test BLDC Motor:**
   ```bash
   # Start motor
   python3 ~/klipper-install/scripts/klipper_interface.py -g "WINDER_START RPM=100"
   
   # Check status
   python3 ~/klipper-install/scripts/klipper_interface.py -g "WINDER_STATUS"
   ```

---

## Quick Reference

### Check MCU Status
```bash
python3 ~/klipper-install/scripts/klipper_interface.py --info
```

### Check Logs (filter spam)
```bash
tail -f /tmp/klippy.log | grep -v analog_in_state
```

### Restart Klipper
```bash
sudo systemctl restart klipper
```

### Test TMC2209
```bash
python3 ~/klipper-install/scripts/diagnose_tmc2209.py
```

