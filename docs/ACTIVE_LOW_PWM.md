# Active LOW PWM - Motor Controller Configuration

## Your Motor Controller

**PWM input "meant to read 5V":**
- This means the controller uses **active-LOW logic**
- **HIGH (5V) = Motor OFF**
- **LOW (0V) = Motor ON**
- Has internal pull-up to 5V

## How Optocoupler Works with Active-LOW

**When GPIO17 is HIGH (3.3V):**
- Optocoupler LED turns ON
- Optocoupler transistor conducts
- Output (Pin 4) goes LOW (0V)
- **Motor controller sees LOW → Motor ON** ✅

**When GPIO17 is LOW (0V):**
- Optocoupler LED turns OFF
- Optocoupler transistor is OFF
- Output (Pin 4) goes HIGH (5V via pull-up)
- **Motor controller sees HIGH → Motor OFF** ✅

## This is CORRECT!

**The optocoupler inverts the signal, which is perfect for active-LOW:**
- GPIO HIGH → Motor ON
- GPIO LOW → Motor OFF

## Testing

**To verify optocoupler is working:**

1. **Measure GPIO17 voltage:**
   - Should see PWM signal (varying 0-3.3V)

2. **Measure optocoupler LED side (Pins 1-2):**
   - Should see ~1.2-2.0V when GPIO HIGH
   - Should see 0V when GPIO LOW

3. **Measure motor controller PWM input:**
   - Should see LOW (0V) when GPIO HIGH (motor ON)
   - Should see HIGH (5V) when GPIO LOW (motor OFF)

## Current Issue

**"Motor PWM pin not ready"** means:
- GPIO17 isn't outputting PWM yet
- Need to fix the pin initialization first
- Once PWM is working, optocoupler should work correctly

## Next Steps

1. **Fix PWM pin initialization** (software issue)
2. **Verify optocoupler wiring** (hardware check)
3. **Test with multimeter** (measure voltages)
4. **Motor should turn on** when PWM is active


