# Stop Ports Are Output-Only - Hall Sensor Pin Selection

## Critical Finding

**All stop ports (endstop connectors) on SKR Pico are OUTPUT-ONLY:**
- They are always HIGH (3.3V)
- They **CANNOT** be set LOW
- They **CANNOT** be used as inputs for Hall sensors
- Even when not being used, they still show 3.3V

## Stop Ports to AVOID for Hall Sensors

Based on SKR Pico board design, these pins are typically stop ports (output-only):
- **gpio3** - Y-axis endstop (in generic config)
- **gpio4** - X-axis endstop (in generic config)
- **gpio16** - Y-axis endstop (currently used in your config)
- **gpio25** - Z-axis endstop (in generic config)

**DO NOT use these pins for Hall sensors!**

## Current Configuration Status

**Your current Hall sensor pins:**
- `motor_hall_pin: gpio24` ✅ **Should be OK** (not a stop port)
- `spindle_hall_pin: ^gpio29` ✅ **Should be OK** (not a stop port)

**Your endstop pin:**
- `endstop_pin: ^!gpio16` ⚠️ **This is a stop port** (output-only, can't be used as input)

## Safe Input Pins for Hall Sensors

**Pins that can be used as inputs (not stop ports):**
- gpio24 ✅ (currently used for motor Hall)
- gpio29 ✅ (currently used for spindle Hall)
- gpio22 (currently used for emergency stop button - but can be input)
- gpio26 (if not used for bed thermistor)
- gpio27 (if not used for extruder thermistor)
- gpio28 (if not used for Z dir pin)

**Other available GPIO pins (check for conflicts):**
- gpio0, gpio1 (usually UART, avoid)
- gpio2 (if not used)
- gpio10, gpio11, gpio12, gpio13, gpio14, gpio15 (if not used for steppers)
- gpio21 (if not used for bed heater)

## How to Verify a Pin Can Be Used as Input

**Test procedure:**
1. **Power off Klipper** (or disconnect from MCU)
2. **Measure pin voltage with multimeter:**
   - Connect black probe to GND
   - Connect red probe to GPIO pin
   - **If it reads 3.3V and won't change** → It's output-only (stop port)
   - **If it reads 0V or floating** → It can be used as input
3. **Try to pull it LOW:**
   - Connect pin to GND via 1kΩ resistor
   - **If voltage stays 3.3V** → Output-only (stop port)
   - **If voltage goes to 0V** → Can be used as input

## If You Need to Change Hall Sensor Pins

**If gpio24 or gpio29 are also stop ports on your board:**

1. **Choose a safe input pin** from the list above
2. **Update `printer.cfg`:**
   ```ini
   [winder]
   motor_hall_pin: gpio26      # Example: use gpio26 if available
   spindle_hall_pin: ^gpio27    # Example: use gpio27 if available
   ```
3. **Restart Klipper:** `FIRMWARE_RESTART`
4. **Test Hall sensor readings**

## Testing Your Current Pins

**To verify gpio24 and gpio29 are NOT stop ports:**

1. **Power off Klipper**
2. **Measure gpio24:**
   - Should read 0V or floating (not 3.3V stuck)
   - If it reads 3.3V stuck → It's a stop port, need to change
3. **Measure gpio29:**
   - Should read 0V or floating (not 3.3V stuck)
   - If it reads 3.3V stuck → It's a stop port, need to change

## Summary

- ✅ **gpio24** and **gpio29** should be safe for Hall sensors (not stop ports)
- ❌ **gpio16** (and gpio3, gpio4, gpio25) are stop ports - output-only
- 🔍 **Test your pins** to confirm they can be used as inputs
- 📝 **If needed**, change to safe input pins from the list above

