# Testing GPIO17 PWM Pin

## What You're Seeing

**2.5kΩ resistance on GPIO17:**
- This could be:
  1. **Internal pull-up/pull-down resistor** (RP2040 has ~50kΩ pull-ups, but 2.5kΩ suggests external circuit)
  2. **Optocoupler LED circuit** (LED + current-limiting resistor)
  3. **Pin not configured as output** (floating/high impedance)

## Proper Testing Method

**Don't measure resistance - measure VOLTAGE!**

### Test 1: Check if Pin is Outputting PWM

**With multimeter in VOLTAGE mode (DC):**
1. **Black probe** → GND
2. **Red probe** → GPIO17 pin
3. **Send motor command:** `SET_SPINDLE_SPEED RPM=100`
4. **Expected reading:**
   - **If PWM working:** Should see ~1.5-2.5V average (PWM duty cycle)
   - **If pin HIGH:** Should see ~3.3V
   - **If pin LOW:** Should see ~0V
   - **If floating:** Unpredictable voltage

### Test 2: Check Optocoupler Input Side

**Measure voltage across optocoupler LED (Pins 1-2):**
1. **Black probe** → Pin 2 (Cathode/GND)
2. **Red probe** → Pin 1 (Anode, connected to GPIO17 via resistor)
3. **Send motor command**
4. **Expected:**
   - **If working:** Should see ~1.2-2.0V (LED forward voltage)
   - **If not working:** 0V or very low

### Test 3: Check Optocoupler Output Side

**Measure voltage at motor controller PWM input:**
1. **Black probe** → GND
2. **Red probe** → Motor controller PWM input pin
3. **Send motor command**
4. **Expected:**
   - **If optocoupler working:** Should see voltage change (0V when LED on, 5V when LED off, or vice versa)
   - **If not working:** No change or floating

## Why 2.5kΩ Resistance?

**Possible causes:**
1. **Optocoupler LED + resistor:**
   - If you have 220Ω-1kΩ resistor + LED, total resistance could be ~2.5kΩ
   - This is NORMAL if optocoupler is connected

2. **Internal pull-up:**
   - RP2040 internal pull-ups are ~50kΩ, not 2.5kΩ
   - So this is likely external circuit

3. **Pin configuration:**
   - If pin is input (not output), you're measuring input impedance
   - PWM pin should be configured as OUTPUT

## Next Steps

1. **Measure VOLTAGE, not resistance:**
   - Set multimeter to DC voltage mode
   - Measure GPIO17 voltage when motor command sent
   - Should see PWM signal (varying voltage)

2. **Check if pin is configured:**
   - The "Motor PWM pin not ready" error suggests pin might not be initialized
   - Check Klipper log for pin setup errors

3. **Verify optocoupler wiring:**
   - Check if LED side (Pins 1-2) is connected correctly
   - Check if current-limiting resistor is present (220Ω-1kΩ)
   - Verify LED polarity (anode to GPIO, cathode to GND)

4. **Check motor controller:**
   - Is motor controller powered?
   - Is enable/brake pin (gpio18) configured correctly?
   - Some controllers need enable LOW to run

## Quick Test

**Try this:**
1. Measure GPIO17 voltage (DC mode)
2. Send `SET_SPINDLE_SPEED RPM=100`
3. Voltage should change (not stay at 0V or 3.3V)
4. If voltage doesn't change, pin isn't outputting PWM


