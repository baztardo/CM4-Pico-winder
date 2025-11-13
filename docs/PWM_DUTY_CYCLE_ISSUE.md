# PWM Duty Cycle Issue - Motor Not Starting

## Your Measurements

- **Logic side (GPIO):** 2.7V (PWM average voltage)
- **BLDC side (optocoupler output):** 4.9V (good!)

## The Problem

**Motor controller might need:**
1. **Higher duty cycle** to start (some controllers need >10% to start)
2. **Different signal type** (continuous HIGH vs PWM)
3. **Enable/brake pin** configured correctly

## Current PWM Calculation

**From winder.py:**
```python
pwm_duty = min(motor_rpm / self.max_motor_rpm, 1.0)
```

**For 100 RPM spindle speed:**
- Motor RPM = 100 / 0.667 = 149.9 RPM
- PWM duty = 149.9 / 3000 = **5.0%** (very low!)

**For 500 RPM spindle speed:**
- Motor RPM = 500 / 0.667 = 749.5 RPM
- PWM duty = 749.5 / 3000 = **25.0%** (better)

**For 1000 RPM spindle speed:**
- Motor RPM = 1000 / 0.667 = 1499.5 RPM
- PWM duty = 1499.5 / 3000 = **50.0%** (good)

## Possible Solutions

### Option 1: Increase Minimum Duty Cycle

Some motor controllers need a minimum duty cycle (e.g., 10-20%) to start. We could add a minimum:

```python
pwm_duty = min(motor_rpm / self.max_motor_rpm, 1.0)
if pwm_duty > 0 and pwm_duty < 0.1:  # Less than 10%
    pwm_duty = 0.1  # Force minimum 10%
```

### Option 2: Check Motor Controller Enable/Brake Pin

**Your config:**
- `motor_brake_pin: gpio18`

**Some controllers:**
- Brake LOW = Motor enabled
- Brake HIGH = Motor disabled

**Check if gpio18 is configured correctly!**

### Option 3: Test with Higher RPM

Try higher RPM to get higher duty cycle:
- 500 RPM = 25% duty cycle
- 1000 RPM = 50% duty cycle

## Testing

**Test 1: Check if motor controller needs minimum duty cycle**
1. Try `SET_SPINDLE_SPEED RPM=500` (25% duty)
2. Try `SET_SPINDLE_SPEED RPM=1000` (50% duty)
3. See if motor starts at higher duty cycles

**Test 2: Check brake/enable pin**
1. Measure voltage on gpio18
2. Should be LOW (0V) when motor should run
3. If HIGH, motor is disabled

**Test 3: Check optocoupler output**
1. Measure voltage at BLDC PWM input
2. Should see PWM signal (varying voltage)
3. Higher RPM = higher average voltage

## Next Steps

1. **Try higher RPM** (500-1000 RPM) to test if duty cycle is the issue
2. **Check brake pin (gpio18)** - make sure it's LOW
3. **Verify motor controller power** - is it actually powered?
4. **Check motor controller specs** - what minimum duty cycle does it need?


