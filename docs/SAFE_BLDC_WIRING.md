# Safe BLDC Motor Controller Wiring Guide

## The Problem

- **SKR Pico GPIO:** Outputs 3.3V (max 3.6V)
- **BLDC Controller PWM Input:** Expects 5V logic, has 5V pull-up
- **Direct connection = DANGEROUS** (5V will damage SKR Pico)

## Safe Solution: Use Optocoupler

**Optocoupler isolates signals and protects SKR Pico from 5V.**

## Parts Needed

- **Optocoupler** (PC817, 4N25, TLP281, or similar)
- **220Ω-1kΩ resistor** (for LED current limiting)
- **1kΩ-10kΩ resistor** (pull-up on output side, optional if controller has pull-up)

## Wiring Diagram

```
SKR Pico Side (3.3V):
  GPIO17 (PWM) → [220Ω resistor] → Optocoupler Pin 1 (Anode/LED+)
  GND → Optocoupler Pin 2 (Cathode/LED-)

Optocoupler:
  Pin 1: Anode (LED +)
  Pin 2: Cathode (LED -)
  Pin 3: Emitter (Output -)
  Pin 4: Collector (Output +)

BLDC Controller Side (5V):
  Optocoupler Pin 4 (Collector) → BLDC Controller PWM Input
  Optocoupler Pin 3 (Emitter) → GND (common ground)
  [Optional: 1kΩ-10kΩ pull-up from 5V to Pin 4 if controller doesn't have one]
```

## Step-by-Step Wiring

### Step 1: Identify Optocoupler Pins

**4-Pin Optocoupler (most common):**
- **Pin 1:** Anode (LED +) - usually marked with dot or "1"
- **Pin 2:** Cathode (LED -)
- **Pin 3:** Emitter (Output -)
- **Pin 4:** Collector (Output +)

**Check datasheet for your specific optocoupler!**

### Step 2: Connect SKR Pico Side

1. **GPIO17** → [220Ω resistor] → **Optocoupler Pin 1**
2. **GND** → **Optocoupler Pin 2**

**Test:** When GPIO17 is HIGH, LED should glow (if visible)

### Step 3: Connect BLDC Controller Side

1. **Optocoupler Pin 4** → **BLDC Controller PWM Input**
2. **Optocoupler Pin 3** → **GND** (common ground with SKR Pico)
3. **[Optional] BLDC 5V** → [1kΩ resistor] → **Optocoupler Pin 4** (if controller doesn't have pull-up)

### Step 4: Verify Connections

**With multimeter (power OFF):**
- Check continuity: GPIO17 → Resistor → Pin 1
- Check continuity: GND → Pin 2
- Check continuity: Pin 4 → BLDC PWM input
- Check continuity: Pin 3 → GND

## How It Works

**When GPIO17 is HIGH (3.3V):**
- Current flows through LED (Pins 1-2)
- LED turns on
- Transistor conducts (Pins 3-4 short together)
- BLDC PWM input sees LOW (0V) → **Motor ON**

**When GPIO17 is LOW (0V):**
- LED turns off
- Transistor is OFF (Pins 3-4 open)
- BLDC PWM input sees HIGH (5V via pull-up) → **Motor OFF**

## Testing

### Test 1: Check Optocoupler LED
1. Set GPIO17 HIGH (send PWM command)
2. LED should glow (if visible)
3. If no glow, check wiring or resistor value

### Test 2: Check Output Voltage
1. Measure voltage at BLDC PWM input
2. When GPIO HIGH: Should read LOW (0V)
3. When GPIO LOW: Should read HIGH (5V)

### Test 3: Test Motor
1. Send motor command: `SET_SPINDLE_SPEED RPM=100`
2. Motor should start
3. If not, check all connections

## Safety Checklist

✅ **Optocoupler isolates 3.3V from 5V**
✅ **No direct connection between SKR Pico and BLDC controller**
✅ **Common ground connected** (Pin 3 to GND)
✅ **Resistor limits LED current** (220Ω-1kΩ)
✅ **5V cannot reach SKR Pico GPIO** (isolated)

## Common Mistakes

❌ **Reversed LED polarity** (Pin 1-2 swapped) → LED won't work
❌ **Reversed transistor** (Pin 3-4 swapped) → Output inverted
❌ **Missing resistor** → LED might burn out or GPIO damaged
❌ **No common ground** → Optocoupler won't work
❌ **Direct connection** → 5V damages SKR Pico

## Current Setup

**Your config:**
- `motor_pwm_pin: gpio17` → Connect to optocoupler Pin 1 (via resistor)
- `motor_dir_pin: gpio3` → Can connect directly (if controller accepts 3.3V) or use another optocoupler
- `motor_brake_pin: gpio18` → Can connect directly (if controller accepts 3.3V) or use another optocoupler

## Next Steps

1. **Wire optocoupler as shown above**
2. **Test with multimeter** (verify connections)
3. **Test with motor command** (see if motor responds)
4. **If motor doesn't work, check:**
   - Optocoupler wiring
   - Motor controller power
   - Motor controller enable/brake pin


