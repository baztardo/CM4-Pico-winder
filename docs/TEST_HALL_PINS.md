# Testing Hall Sensor Pins - Voltage Check

## What to Test

**With multimeter, measure voltage at:**
1. **GPIO4** (motor Hall sensor) - when sensor active and inactive
2. **GPIO22** (spindle Hall sensor) - when sensor active and inactive

## Expected Voltages

### For NPN NO Sensors (NJK-5002C):
- **No magnet (inactive):** GPIO should read **~3.3V** (pulled HIGH by internal pull-up)
- **Magnet present (active):** GPIO should read **~0V** (sensor pulls LOW to GND)

### For BLDC Hall (via optocoupler + voltage divider):
- **Inactive:** Should read **< 3.3V** (ideally 2.5V if 1k/1k divider, or 3.0V if 2.2k/3.3k)
- **Active:** Should read **< 0.8V** (LOW)

## Safety Thresholds

**RP2040 GPIO (SKR Pico):**
- ✅ **Safe HIGH:** 2.0V to 3.3V
- ✅ **Safe LOW:** 0V to 0.8V
- ⚠️ **Risky:** 3.4V to 3.6V (absolute max, but not recommended)
- ❌ **DANGEROUS:** > 3.6V (will damage MCU)

## Test Procedure

1. **Power off Klipper** (or disconnect sensors temporarily)
2. **Measure GPIO4 voltage:**
   - Connect multimeter black to GND
   - Connect multimeter red to GPIO4 pin
   - Note voltage when sensor inactive
   - Note voltage when sensor active (if possible)
3. **Measure GPIO22 voltage:**
   - Same procedure
4. **Check if voltages are safe:**
   - All readings should be **< 3.3V**
   - If any reading > 3.3V, that's the problem!

## What to Look For

**If GPIO4 reads > 3.3V:**
- ❌ Voltage divider is wrong (1k/10k = 4.55V)
- Fix: Change to 1k/1k or 2.2k/3.3k

**If GPIO4 reads ~2.5V to 3.0V:**
- ✅ Voltage divider is correct
- Should be safe

**If GPIO4 reads ~3.3V:**
- ✅ Using internal pull-up (NPN sensor floating)
- Should be safe

**If GPIO22 reads > 3.3V:**
- ❌ Something wrong with NJK-5002C sensor
- Check wiring, check for external pull-up to 5V

## Current Status

- ✅ BLDC Hall (GPIO4) is connected and MCU is stable
- ✅ This suggests voltage divider is working correctly
- ⚠️ Still good to verify with multimeter to be sure

## Next Steps

1. Test GPIO4 voltage (BLDC Hall)
2. Test GPIO22 voltage (spindle Hall - NJK-5002C)
3. If both are < 3.3V, you're good!
4. If any > 3.3V, fix that pin's voltage divider/wiring


