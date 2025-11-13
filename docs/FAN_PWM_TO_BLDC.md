# Using Fan PWM Output for BLDC Motor Control

## Your Setup Idea

**Fan PWM Output → Optocoupler → BLDC Motor Controller PWM Input**

This is actually a clever workaround! Fan outputs are often already configured for PWM and might work better than setting up a new PWM pin.

## How It Works

**SKR Pico Fan Output:**
- Already configured for PWM
- Usually on a dedicated fan pin (e.g., gpio17, gpio18, gpio20, gpio21)
- Can be controlled via `SET_FAN_SPEED` or `M106` commands

**Your Circuit:**
```
Fan PWM Output → [Resistor] → Optocoupler LED (Pins 1-2)
Optocoupler Output (Pin 4) → BLDC Motor Controller PWM Input
Optocoupler Pin 3 → GND
Motor Controller 5V → [Pull-up resistor] → Optocoupler Pin 4
```

## Advantages

✅ **Fan PWM is already working** (no pin initialization issues)
✅ **Simple to test** (just set fan speed)
✅ **Isolated** (optocoupler protects SKR Pico)
✅ **Works with existing fan control commands**

## Configuration

**Option 1: Use existing fan pin**
```ini
[fan]
pin: gpio17  # or whatever fan pin you're using
```

**Option 2: Create dedicated fan for motor**
```ini
[fan motor_pwm]
pin: gpio17  # or available fan pin
```

## Control Commands

**Set motor speed via fan:**
```gcode
M106 S255    # Full speed (0-255)
M106 S128    # Half speed
M106 S0      # Off
```

**Or via webhook:**
```python
klipper.send_gcode("M106 S255")  # Full speed
```

## Testing

1. **Check if fan PWM works:**
   ```bash
   python3 ~/klipper/scripts/klipper_interface.py -g "M106 S255"
   ```
   - Fan should spin (if connected)
   - Or measure PWM signal on fan pin

2. **Check optocoupler:**
   - Measure voltage on optocoupler LED side (should see PWM)
   - Measure voltage on optocoupler output (should see inverted PWM)
   - Measure voltage on BLDC PWM input (should see signal)

3. **Test motor:**
   - Send `M106 S255` (full speed)
   - Motor should start
   - Send `M106 S0` (off)
   - Motor should stop

## Current Issue

**You removed the optocoupler connection:**
- Need to reconnect it properly
- Fan PWM → Optocoupler → BLDC PWM input
- Make sure optocoupler is wired correctly

## Next Steps

1. **Which fan pin are you using?** (gpio17, gpio18, etc.)
2. **Is the fan PWM working?** (can you control a fan with it?)
3. **Reconnect optocoupler** between fan PWM and BLDC PWM input
4. **Test with M106 commands**

This approach might actually work better than the direct GPIO PWM setup!


