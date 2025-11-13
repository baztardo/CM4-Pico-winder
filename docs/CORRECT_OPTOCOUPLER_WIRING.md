# Correct Optocoupler Wiring for BLDC

## Your Setup Description

You mentioned:
- PWM wire → INPUT+ (correct!)
- GND → INPUT- (correct!)
- Signal (OUT) → BLDC + (5V) - **This might be wrong!**

## Correct Wiring

### Input Side (SKR Pico):
```
GPIO4 (PWM) → [220Ω resistor] → Optocoupler INPUT+
SKR Pico GND → Optocoupler INPUT-
```

### Output Side (BLDC Controller):
```
Optocoupler VCC/OUT → [Pull-up resistor, 1kΩ-10kΩ] → BLDC + (5V)
Optocoupler VCC/OUT → BLDC signal (PWM input) ← THIS IS THE KEY!
Optocoupler GND → BLDC - (GND)
```

## Important!

**The optocoupler OUT should connect to BLDC signal (PWM input), NOT to BLDC + (5V)!**

**The pull-up resistor connects VCC/OUT to BLDC + (5V) to provide the HIGH level.**

## Your Wiring Should Be:

1. **GPIO4** → [220Ω] → **Optocoupler INPUT+**
2. **GND** → **Optocoupler INPUT-**
3. **Optocoupler VCC/OUT** → **[Pull-up resistor]** → **BLDC + (5V)**
4. **Optocoupler VCC/OUT** → **BLDC signal (PWM input)** ← Motor control signal
5. **Optocoupler GND** → **BLDC - (GND)**

## The LED and Resistor

**If you have an LED between INPUT+ and INPUT-:**
- That's the optocoupler's internal LED
- The 220Ω resistor limits current to the LED
- This is correct!

**If you have something between VCC/OUT and BLDC +:**
- That should be a pull-up resistor (1kΩ-10kΩ)
- NOT an LED
- This provides the HIGH level when transistor is OFF

## Test the Motor

**Once wired correctly:**
1. **LED OFF** (GPIO LOW) → VCC/OUT = 5V → BLDC signal = 5V → Motor OFF
2. **LED ON** (GPIO HIGH) → VCC/OUT = 0V → BLDC signal = 0V → Motor ON

**Try running the motor now and see if it responds to commands!**


