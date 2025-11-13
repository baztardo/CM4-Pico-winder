# BLDC Motor Connection Guide

## Required Connections to SKR Pico

Based on `printer.cfg`, connect the BLDC motor controller to these pins:

### Motor Control Pins
- **PWM Signal**: `gpio17` → Motor controller PWM input
- **Direction**: `gpio3` → Motor controller DIR input  
- **Brake**: `gpio18` → Motor controller brake/enable (optional)

### Hall Sensor Pins
- **Motor Hall**: `gpio4` → Motor Hall sensor output
- **Spindle Hall**: `gpio22` → Spindle Hall sensor output

## Connection Checklist

### Before Testing:
- [ ] Motor controller power connected
- [ ] Motor controller PWM connected to gpio17
- [ ] Motor controller DIR connected to gpio3
- [ ] Motor controller brake (if used) connected to gpio18
- [ ] Motor Hall sensor connected to gpio4
- [ ] Spindle Hall sensor connected to gpio22
- [ ] All grounds/common connected
- [ ] Motor physically connected to controller

## Testing Steps

### 1. Check Status (No Motor Movement)
```bash
python3 ~/klipper/scripts/test_bldc_spindle.py --status
```
This should show winder status even if motor isn't connected.

### 2. Test Motor Control (Motor Will Move!)
```bash
python3 ~/klipper/scripts/test_bldc_spindle.py --motor
```
**WARNING**: This will start the motor! Make sure:
- Motor is securely mounted
- Nothing can get caught in moving parts
- You can stop it quickly (Ctrl+C or emergency stop)

### 3. Test Hall Sensors
```bash
python3 ~/klipper/scripts/test_bldc_spindle.py --hall
```
This runs the motor at 50 RPM for 10 seconds and monitors Hall feedback.

## Troubleshooting

### Motor Doesn't Start
- Check PWM pin connection (gpio17)
- Check motor controller power
- Check motor controller enable/brake pin (gpio18)
- Check Klipper log: `tail -f /tmp/klippy.log | grep -i motor`

### No Hall Sensor Reading
- Check Hall sensor connections (gpio4 for motor, gpio22 for spindle)
- Check Hall sensor power (usually 5V or 12V)
- Verify Hall sensors are working (test with multimeter)
- Check Klipper log: `tail -f /tmp/klippy.log | grep -i hall`

### Wrong RPM Reading
- Verify Hall sensor PPR (pulses per revolution) in config
- Check gear ratio setting (0.667 in config)
- Verify motor poles setting (8 in config)

## Safety Notes

⚠️ **Always test at low RPM first!**
- Start with 50-100 RPM
- Gradually increase if needed
- Keep emergency stop accessible
- Never leave motor running unattended during testing

## Next Steps After Connection

1. Run `--status` to verify connections
2. Run `--motor` to test basic control
3. Run `--hall` to verify sensor feedback
4. Run `--rpm-range` to test across speed range
5. Once verified, use `winding_sequence.py` for actual winding


