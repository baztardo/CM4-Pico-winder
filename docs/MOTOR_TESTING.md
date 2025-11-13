# BLDC Motor Testing Guide

## Current Status

✅ **Winder module is loaded and responding**
✅ **Commands are registered** (SET_SPINDLE_SPEED, WINDER_START, WINDER_STOP, etc.)
✅ **Status queries work** (can read winder status)

⚠️ **MCU shutdown issue** - MCU needs to be running for motor commands to work

## Testing Steps

### 1. Ensure MCU is Running

```bash
# Check Klipper state
python3 ~/klipper/scripts/klipper_interface.py --info

# If MCU is shutdown, restart it
python3 ~/klipper/scripts/klipper_interface.py -g "FIRMWARE_RESTART"

# Wait 10 seconds, then check again
python3 ~/klipper/scripts/klipper_interface.py --info
```

**If MCU keeps shutting down:**
- Physically unplug and replug the SKR Pico USB cable
- Or power cycle the SKR Pico
- Check USB connection
- Check Klipper log: `tail -50 /tmp/klippy.log`

### 2. Test Motor Commands (Once MCU is Ready)

```bash
# Check status
python3 ~/klipper/scripts/test_bldc_spindle.py --status

# Test motor control (WILL START MOTOR!)
python3 ~/klipper/scripts/test_bldc_spindle.py --motor
```

### 3. Verify Hardware Connections

Before testing motor, ensure:
- [ ] Motor controller connected to SKR Pico
- [ ] PWM connected to `gpio17`
- [ ] DIR connected to `gpio3`
- [ ] Brake (if used) connected to `gpio18`
- [ ] Motor Hall sensor connected to `gpio4`
- [ ] Spindle Hall sensor connected to `gpio22`
- [ ] All grounds/common connected
- [ ] Motor controller powered

## Expected Behavior

### When Motor is NOT Connected:
- Commands will send successfully
- `motor_rpm_measured` will stay at 0
- `spindle_rpm_measured` will stay at 0
- No errors (motor just won't move)

### When Motor IS Connected:
- Commands will send successfully
- `motor_rpm_measured` should show actual RPM
- `spindle_rpm_measured` should show actual RPM
- Motor should physically rotate

## Troubleshooting

### "MCU is shutdown" Error
- **Cause**: MCU communication lost
- **Fix**: Restart MCU (FIRMWARE_RESTART or physical reset)
- **Prevention**: Check USB connection, power supply

### Motor Doesn't Start
- Check PWM pin connection (gpio17)
- Check motor controller power
- Check motor controller enable/brake pin
- Check Klipper log for errors

### No Hall Sensor Reading
- Check Hall sensor connections (gpio4, gpio22)
- Check Hall sensor power supply
- Verify sensors are working (test with multimeter)
- Check if sensors are in correct position

### Wrong RPM Reading
- Verify Hall sensor PPR setting (currently 1 in config)
- Check gear ratio (currently 0.667 in config)
- Verify motor poles (currently 8 in config)
- Check if sensors are reading correctly

## Next Steps

1. **Fix MCU shutdown issue** (if persistent)
2. **Connect motor hardware** (when ready)
3. **Test at low RPM** (50-100 RPM first)
4. **Verify Hall sensors** (check RPM readings)
5. **Test RPM range** (50, 100, 200, 500, 1000 RPM)
6. **Start winding sequences** (once verified)

## Safety Reminders

⚠️ **Always test at low RPM first!**
- Start with 50-100 RPM
- Gradually increase if needed
- Keep emergency stop accessible
- Never leave motor running unattended
- Ensure motor is securely mounted
- Clear area of obstructions


