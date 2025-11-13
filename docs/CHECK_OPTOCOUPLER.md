# How to Check Optocoupler

## What to Measure

### Test 1: Check Input Side (GPIO to Optocoupler)

**Measure voltage on gpio4:**
1. **Black probe** → GND
2. **Red probe** → gpio4 pin
3. **Expected:**
   - When motor should be OFF: Should read **LOW (0V or close to 0V)**
   - When motor should be ON: Should read **HIGH (3.3V or PWM signal)**

**Measure voltage across optocoupler LED (INPUT+ to INPUT-):**
1. **Black probe** → INPUT- (Cathode)
2. **Red probe** → INPUT+ (Anode, connected to gpio4 via resistor)
3. **Expected:**
   - When motor should be OFF: Should read **0V** (LED off)
   - When motor should be ON: Should read **~1.2-2.0V** (LED forward voltage)

**If LED is always on:**
- GPIO is stuck HIGH
- Or resistor is wrong value
- Or optocoupler LED is damaged

### Test 2: Check Output Side (Optocoupler to BLDC)

**Measure voltage at BLDC PWM input:**
1. **Black probe** → GND
2. **Red probe** → BLDC PWM input pin
3. **Expected:**
   - When motor should be OFF: Should read **HIGH (5V or close to 5V)**
   - When motor should be ON: Should read **LOW (0V or close to 0V)**

**If BLDC PWM input is always LOW:**
- Optocoupler transistor is stuck ON
- Or optocoupler is damaged
- Or VCC isn't connected (but you said 4.9V, so that's good)

### Test 3: Check Optocoupler VCC

**Measure voltage on optocoupler VCC pin:**
1. **Black probe** → GND
2. **Red probe** → Optocoupler VCC pin
3. **Expected:** Should read **5V** (you measured 4.9V, which is good)

## Quick Diagnosis

**If motor is always running at full speed:**

**Scenario 1: GPIO stuck HIGH**
- gpio4 reads 3.3V all the time
- LED is always on
- **Fix:** Check PWM pin initialization

**Scenario 2: Optocoupler stuck ON**
- gpio4 is LOW (correct)
- But BLDC PWM input is LOW (wrong - should be HIGH)
- **Fix:** Optocoupler might be damaged, or wiring wrong

**Scenario 3: Missing pull-up**
- BLDC PWM input floats LOW
- Motor controller sees LOW = full speed
- **Fix:** Add pull-up resistor or check if controller has internal pull-up

## What to Check

1. **Measure gpio4 voltage** - Is it LOW when motor should be off?
2. **Measure optocoupler LED voltage** - Is LED off when motor should be off?
3. **Measure BLDC PWM input** - Is it HIGH (5V) when motor should be off?
4. **Check optocoupler wiring** - Are all connections correct?

## Common Issues

**Optocoupler LED always on:**
- GPIO stuck HIGH
- Wrong resistor value (too low)
- LED damaged

**Optocoupler output always LOW:**
- Transistor stuck ON
- VCC not connected
- Optocoupler damaged

**BLDC PWM input always LOW:**
- Optocoupler output stuck LOW
- Missing pull-up resistor
- Controller has pull-down (unlikely)


