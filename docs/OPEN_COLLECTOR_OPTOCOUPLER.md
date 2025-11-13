# Open-Collector Optocoupler Wiring

## Your Optocoupler Type

**VCC and OUT are the same pin** (open-collector output):
- This is a common optocoupler design
- Needs external pull-up resistor
- VCC/OUT pin → [Pull-up resistor] → 5V
- VCC/OUT pin → BLDC PWM input

## Correct Wiring

```
Input Side:
  GPIO4 → [220Ω] → INPUT+ (Anode)
  GND → INPUT- (Cathode)

Output Side:
  VCC/OUT pin → [Pull-up resistor, e.g., 1kΩ-10kΩ] → 5V
  VCC/OUT pin → BLDC PWM Input
  GND → GND (common)
```

## How It Works

**When LED is OFF (GPIO LOW):**
- Transistor is OFF
- VCC/OUT pin is pulled HIGH (5V via pull-up resistor)
- BLDC sees HIGH → Motor OFF

**When LED is ON (GPIO HIGH):**
- Transistor is ON
- VCC/OUT pin is pulled LOW (0V, transistor conducts to GND)
- BLDC sees LOW → Motor ON

## Current Problem

**Motor running full blast even with LED GND disconnected:**
- This means transistor is stuck ON
- VCC/OUT is stuck LOW
- Motor controller sees LOW → Full speed

## Possible Causes

### 1. Pull-Up Resistor Missing or Wrong Value
**If pull-up resistor is missing:**
- VCC/OUT floats
- Might float LOW
- Motor runs

**Check:**
- Is there a resistor between VCC/OUT and 5V?
- What value is it? (Should be 1kΩ-10kΩ)

### 2. Optocoupler Damaged
**If transistor is stuck ON:**
- Always conducts
- Output always LOW
- **Fix:** Replace optocoupler

### 3. Wiring Issue
**If VCC/OUT is shorted to GND:**
- Always LOW
- Motor always runs
- **Check:** Measure resistance between VCC/OUT and GND

## Diagnosis

**Measure voltage at VCC/OUT pin (with LED GND disconnected):**
- Should be HIGH (5V) if pull-up is working
- If LOW (0V) → Transistor stuck ON or short to GND

**Measure resistance between VCC/OUT and GND:**
- Should be high (>10kΩ) when transistor OFF
- If low (<100Ω) → Short or transistor stuck ON

**Check pull-up resistor:**
- Is it connected between VCC/OUT and 5V?
- What value? (measure with multimeter)

## Quick Test

**Disconnect VCC/OUT wire from BLDC PWM input:**
- Measure voltage at VCC/OUT pin
- Should be HIGH (5V) if pull-up working
- If LOW → Optocoupler is stuck or damaged


