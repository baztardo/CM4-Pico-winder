# Optocoupler Wiring Guide for Motor Control

## Purpose

Optocouplers isolate the 3.3V GPIO signals from the motor controller (which may use 5V, 12V, or 24V logic).

## Typical Optocoupler Configuration

**4-Pin Optocoupler (e.g., PC817, 4N25, TLP281):**
```
Pin 1: Anode (LED +) → GPIO pin via current-limiting resistor (220Ω-1kΩ)
Pin 2: Cathode (LED -) → GND
Pin 3: Emitter (Output -) → GND
Pin 4: Collector (Output +) → Motor controller input via pull-up resistor
```

**6-Pin Optocoupler (e.g., PC817 with base):**
```
Pin 1: Anode → GPIO via resistor
Pin 2: Cathode → GND
Pin 3: Emitter → GND
Pin 4: Collector → Motor controller input
Pin 5: Base (if present) → Usually not connected
Pin 6: (if present) → Usually not connected
```

## Your Setup

**GPIO17 (PWM) → Optocoupler → Motor Controller PWM Input**

**Wiring:**
1. **GPIO17** → [220Ω-1kΩ resistor] → **Optocoupler Pin 1 (Anode)**
2. **GND** → **Optocoupler Pin 2 (Cathode)**
3. **Optocoupler Pin 4 (Collector)** → **Motor Controller PWM Input**
4. **Motor Controller VCC (5V/12V)** → [Pull-up resistor 1kΩ-10kΩ] → **Optocoupler Pin 4**
5. **Optocoupler Pin 3 (Emitter)** → **GND** (common ground)

## Testing Optocoupler

**With Multimeter:**
1. **Power off everything**
2. **Measure resistance:**
   - Pins 1-2: Should be high resistance (LED not lit)
   - Pins 3-4: Should be high resistance (transistor off)
3. **Apply 3.3V to Pin 1 (via resistor), GND to Pin 2:**
   - Pins 3-4: Should show low resistance (transistor on)
   - LED should glow (if visible)

**With GPIO:**
1. **Set GPIO17 HIGH (3.3V):**
   - Optocoupler LED should turn on
   - Output (Pin 4) should go LOW (transistor conducts)
2. **Set GPIO17 LOW (0V):**
   - Optocoupler LED should turn off
   - Output (Pin 4) should go HIGH (via pull-up)

## Common Issues

**Motor not turning:**
1. **Optocoupler not working:**
   - Check LED side (Pins 1-2) - should glow when GPIO HIGH
   - Check transistor side (Pins 3-4) - should conduct when LED on
   - Verify current-limiting resistor (220Ω-1kΩ)

2. **Wrong polarity:**
   - LED won't work if anode/cathode reversed
   - Transistor won't conduct if emitter/collector reversed

3. **Missing pull-up:**
   - Output needs pull-up resistor to motor controller VCC
   - Without pull-up, output floats (unpredictable)

4. **Wrong voltage:**
   - Motor controller might expect 5V logic, optocoupler outputs 0V/5V
   - Some controllers need inverted signal (LOW = ON, HIGH = OFF)

## Motor Controller Input Types

**Active HIGH (most common):**
- HIGH (5V) = Motor ON
- LOW (0V) = Motor OFF
- **Optocoupler output:** LOW = ON, HIGH = OFF (inverted!)
- **Solution:** May need inverter or configure controller for active LOW

**Active LOW:**
- LOW (0V) = Motor ON
- HIGH (5V) = Motor OFF
- **Optocoupler output:** LOW = ON, HIGH = OFF (matches!)

## Current Issue

**"Motor PWM pin not ready"** suggests:
1. GPIO17 might not be configured correctly
2. Or optocoupler wiring is wrong
3. Or motor controller isn't receiving signal

**Next Steps:**
1. Verify GPIO17 is actually outputting PWM
2. Check optocoupler LED lights when PWM active
3. Measure voltage at motor controller PWM input
4. Check motor controller enable/brake pin (gpio18)


