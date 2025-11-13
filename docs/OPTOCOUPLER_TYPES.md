# Optocoupler Types - Which One to Use

## Your Current Optocoupler (Needs Power)

**This type needs external power/pull-up:**
- Open-collector output
- Needs pull-up resistor to 5V on output side
- More complex wiring

## Optocoupler with Signal Output (Better!)

**This type has built-in signal output:**
- Usually has internal pull-up or active output
- Easier to wire
- More reliable

## Common Types

### Type 1: Basic Optocoupler (PC817, 4N25, TLP281)
**4 pins:**
- Pin 1: Anode (LED +)
- Pin 2: Cathode (LED -)
- Pin 3: Emitter (Output -)
- Pin 4: Collector (Output +) - **Needs pull-up resistor**

**Wiring:**
- GPIO → Resistor → Pin 1
- GND → Pin 2
- Pin 4 → BLDC PWM (needs pull-up to 5V)
- Pin 3 → GND

### Type 2: Optocoupler with Built-in Output (Some TLP series)
**May have:**
- Internal pull-up
- Active output stage
- Different pin configuration

### Type 3: Logic-Level Optocoupler
**Has:**
- Built-in output buffer
- No external pull-up needed
- Direct signal output

## How to Identify Your Optocoupler

**Check the part number:**
- Look for markings on the optocoupler
- Common types: PC817, 4N25, TLP281, TLP521, 6N137, etc.

**Check the datasheet:**
- Look for "output type" or "output configuration"
- "Open collector" = needs pull-up
- "Push-pull" or "active output" = has signal output

## Which One Do You Have?

**If you have one with signal output:**
- ✅ Easier to wire
- ✅ More reliable
- ✅ Use that one!

**Tell me:**
1. **Part number** (if visible)
2. **Number of pins** (4, 6, 8?)
3. **Pin markings** (if any)

Then I can give you the exact wiring!


