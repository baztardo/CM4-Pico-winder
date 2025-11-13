# Logic-Level Optocoupler Wiring (VCC/OUT/GND)

## Your Optocoupler Type

**Input side:** +/- (LED)
**Output side:** VCC, OUT, GND (built-in output stage)

This is a **logic-level optocoupler** - much easier to use!

## Wiring Diagram

```
SKR Pico Side (3.3V):
  GPIO17 → [220Ω-1kΩ resistor] → Optocoupler INPUT + (Anode)
  GND → Optocoupler INPUT - (Cathode)

Optocoupler:
  INPUT +: Anode (LED +)
  INPUT -: Cathode (LED -)
  VCC: Power supply for output stage (5V)
  OUT: Signal output
  GND: Ground

BLDC Controller Side:
  Optocoupler OUT → BLDC Controller PWM Input
  Optocoupler GND → GND (common ground)
  Optocoupler VCC → 5V (from BLDC controller or separate 5V supply)
```

## Step-by-Step Wiring

### Step 1: Connect Input Side (SKR Pico)

1. **GPIO17** → [220Ω-1kΩ resistor] → **Optocoupler INPUT +**
2. **GND** → **Optocoupler INPUT -**

**Resistor value:**
- 220Ω = brighter LED, more current
- 1kΩ = dimmer LED, less current
- Either works, 220Ω-470Ω is typical

### Step 2: Connect Output Side (BLDC Controller)

1. **Optocoupler VCC** → **5V** (from BLDC controller or separate 5V supply)
2. **Optocoupler OUT** → **BLDC Controller PWM Input**
3. **Optocoupler GND** → **GND** (common ground)

**Where to get 5V:**
- From BLDC controller 5V output (if it has one)
- From SKR Pico 5V pin (if available)
- From separate 5V power supply
- **Important:** Must be 5V, not 3.3V!

### Step 3: Verify Connections

**With multimeter (power OFF):**
- Check continuity: GPIO17 → Resistor → INPUT +
- Check continuity: GND → INPUT -
- Check continuity: OUT → BLDC PWM input
- Check continuity: VCC → 5V source
- Check continuity: GND → GND

## How It Works

**When GPIO17 is HIGH (3.3V):**
- LED turns ON (current flows INPUT+ to INPUT-)
- Output stage activates
- **OUT pin goes HIGH (5V)** → BLDC sees HIGH → **Motor behavior depends on controller logic**

**When GPIO17 is LOW (0V):**
- LED turns OFF
- Output stage deactivates
- **OUT pin goes LOW (0V)** → BLDC sees LOW → **Motor behavior depends on controller logic**

**Note:** The actual motor ON/OFF depends on whether your BLDC controller uses active-HIGH or active-LOW logic. You may need to test or check controller specs.

## Testing

### Test 1: Check Input Side
1. Measure voltage at INPUT + (relative to INPUT -)
2. When GPIO HIGH: Should see ~1.2-2.0V (LED forward voltage)
3. When GPIO LOW: Should see 0V

### Test 2: Check Output Side
1. **Power on 5V to VCC** (important!)
2. Measure voltage at OUT pin (relative to GND)
3. When GPIO HIGH: Should see HIGH (5V or 0V depending on logic)
4. When GPIO LOW: Should see LOW (0V or 5V depending on logic)

### Test 3: Test Motor
1. **Make sure VCC has 5V power!**
2. Send motor command: `SET_SPINDLE_SPEED RPM=100`
3. Measure OUT pin voltage
4. Motor should respond

## Important Notes

⚠️ **VCC MUST have 5V power!**
- Without 5V on VCC, the output won't work
- Check VCC voltage with multimeter
- Make sure it's 5V, not 3.3V

⚠️ **Common ground is required:**
- Optocoupler GND must connect to same ground as SKR Pico and BLDC controller
- Without common ground, signals won't work

⚠️ **Output logic:**
- Some optocouplers invert (HIGH in = LOW out)
- Some don't invert (HIGH in = HIGH out)
- Test to see which yours does

## Quick Wiring Summary

```
GPIO17 → [220Ω] → INPUT+
GND → INPUT-
VCC → 5V
OUT → BLDC PWM Input
GND → GND (common)
```

## Troubleshooting

**No output signal:**
- Check VCC has 5V power
- Check LED is lighting (INPUT+ to INPUT- voltage)
- Check all ground connections

**Wrong output level:**
- May need to invert logic in software
- Or optocoupler inverts signal (check datasheet)

**Motor doesn't respond:**
- Check BLDC controller power
- Check BLDC controller enable/brake pin
- Verify OUT signal reaches BLDC PWM input


