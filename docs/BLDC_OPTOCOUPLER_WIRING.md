# Correct BLDC Optocoupler Wiring

## BLDC Controller Connector

**Connector pins:**
- **+** = 5V power
- **-** = GND
- **signal** = PWM input
- **hal** = Hall sensor
- **-** = GND (second GND pin)

## Correct Wiring

```
Optocoupler Input Side (SKR Pico):
  GPIO4 → [220Ω resistor] → Optocoupler INPUT+
  SKR Pico GND → Optocoupler INPUT-

Optocoupler Output Side (BLDC Controller):
  Optocoupler VCC/OUT → [Pull-up resistor, 1kΩ-10kΩ] → BLDC + (5V)
  Optocoupler VCC/OUT → BLDC signal (PWM input)
  Optocoupler GND → BLDC - (GND)
```

## Current Issue

**VCC/OUT reading 3.3V instead of 5V:**
- Pull-up resistor might be connected to 3.3V instead of 5V
- Or pull-up resistor value is wrong (too high, causing voltage drop)
- Or optocoupler is pulling it down

## Check Wiring

**Verify:**
1. **Pull-up resistor connects VCC/OUT to BLDC + (5V)**
   - NOT to SKR Pico 3.3V
   - NOT to any other voltage
   - Should be: VCC/OUT → [Resistor] → BLDC + pin

2. **VCC/OUT connects to BLDC signal pin**
   - This is the PWM input

3. **Optocoupler GND connects to BLDC - (GND)**
   - Common ground

## Test

**Measure voltage at VCC/OUT pin (relative to GND):**
- With LED OFF (GND disconnected): Should read **5V** (not 3.3V)
- If it reads 3.3V → Pull-up is connected to wrong voltage source

**Measure voltage at BLDC + pin:**
- Should read **5V** (this is your pull-up source)

**Check pull-up resistor connection:**
- One end → VCC/OUT pin
- Other end → BLDC + (5V) pin
- **NOT** to SKR Pico 3.3V!

## Fix

**If pull-up is connected to 3.3V:**
1. Disconnect from 3.3V
2. Connect to BLDC + (5V) pin
3. VCC/OUT should now read 5V
4. Motor should stop when LED is OFF


