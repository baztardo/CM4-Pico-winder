# Hall Sensor 5V Voltage Issue - Fix Guide

## Problem

Hall sensors outputting **5V** can damage SKR Pico GPIO pins which are **3.3V tolerant**.

## Solutions

### Option 1: Hardware Fix (Recommended)
**Add voltage divider or level shifter between Hall sensor and GPIO pin**

**Voltage Divider (Simple):**
```
Hall Sensor (5V) → [10kΩ] → GPIO Pin
                         ↓
                      [20kΩ] → GND
```
This divides 5V to ~1.67V (safe for 3.3V GPIO)

**Or use a level shifter module:**
- 5V → 3.3V level shifter (bidirectional)
- Connect Hall sensor to 5V side
- Connect GPIO pin to 3.3V side

### Option 2: Configure Pull-Down (May Help)
Change Hall sensor pins in `printer.cfg` to use pull-down (`~`) instead of default pull-up:

```ini
[winder]
motor_hall_pin: ~gpio4      # ~ = pull-down
spindle_hall_pin: ~gpio22   # ~ = pull-down
```

**Note:** This doesn't fix 5V issue, but may help if sensor is open-drain.

### Option 3: Check Hall Sensor Specs
- Some Hall sensors can be configured for 3.3V output
- Check if your sensor has a VCC/VDD pin that can run on 3.3V instead of 5V
- If sensor supports it, power it from 3.3V instead of 5V

## Current Pin Configuration

From `printer.cfg`:
- `motor_hall_pin: gpio4` (no pull config - uses default pull-up)
- `spindle_hall_pin: gpio22` (no pull config - uses default pull-up)

## Testing

After applying fix:
1. Restart Klipper: `FIRMWARE_RESTART`
2. Check MCU doesn't shutdown
3. Test Hall sensor reading: `python3 ~/klipper/scripts/test_bldc_spindle.py --hall`

## Safety

⚠️ **DO NOT connect 5V directly to 3.3V GPIO pins!**
- Can permanently damage MCU
- Can cause MCU shutdowns
- Can cause erratic behavior


