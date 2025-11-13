# Voltage Divider Check for Hall Sensor

## Your Setup

**BLDC Internal Hall Sensor → Optocoupler → Voltage Divider → GPIO4**

**Voltage Divider Options:**
- Option 1: 1kΩ / 10kΩ
- Option 2: 1kΩ / 2.2kΩ

## Voltage Divider Calculations

**Formula:** `Vout = Vin × (R2 / (R1 + R2))`

Where:
- R1 = Top resistor (between Vin and Vout)
- R2 = Bottom resistor (between Vout and GND)
- Vin = 5V (from optocoupler output)

### Option 1: 1kΩ / 10kΩ
```
Vout = 5V × (10kΩ / (1kΩ + 10kΩ))
Vout = 5V × (10/11)
Vout = 4.55V  ❌ TOO HIGH for 3.3V GPIO!
```

### Option 2: 1kΩ / 2.2kΩ
```
Vout = 5V × (2.2kΩ / (1kΩ + 2.2kΩ))
Vout = 5V × (2.2/3.2)
Vout = 3.44V  ⚠️ Still above 3.3V max!
```

## Safe Voltage Levels

**RP2040 GPIO (SKR Pico):**
- **Absolute Maximum:** 3.6V
- **Recommended Max:** 3.3V
- **Logic HIGH threshold:** ~2.0V
- **Logic LOW threshold:** ~0.8V

## Correct Divider Ratios

**Target: ~2.5V (safe HIGH, well above threshold)**

### Recommended: 1kΩ / 1.5kΩ
```
Vout = 5V × (1.5kΩ / (1kΩ + 1.5kΩ))
Vout = 5V × (1.5/2.5)
Vout = 3.0V  ✅ Safe, but still high
```

### Better: 2.2kΩ / 3.3kΩ
```
Vout = 5V × (3.3kΩ / (2.2kΩ + 3.3kΩ))
Vout = 5V × (3.3/5.5)
Vout = 3.0V  ✅ Safe
```

### Best: 1kΩ / 1kΩ (50% divider)
```
Vout = 5V × (1kΩ / (1kΩ + 1kΩ))
Vout = 5V × (1/2)
Vout = 2.5V  ✅ Perfect! Safe and reliable
```

## Current Issue

**If you're using 1k/10k:**
- Output = 4.55V → **DAMAGES 3.3V GPIO!** ❌
- This would cause MCU shutdown

**If you're using 1k/2.2k:**
- Output = 3.44V → **Above 3.3V max, risky!** ⚠️
- Might work but could cause issues

## Fix Options

### Option 1: Fix Voltage Divider (Hardware)
**Change to 1kΩ / 1kΩ:**
- Simple 50% divider
- Output = 2.5V (safe and reliable)
- Easy to implement

### Option 2: Use Different Resistors
**2.2kΩ / 3.3kΩ:**
- Output = 3.0V (safe)
- Common resistor values

### Option 3: Use Level Shifter
- 5V → 3.3V level shifter IC
- More reliable but more complex

## Testing

**Check your current divider:**
1. Measure voltage at GPIO4 pin (with sensor connected)
2. Should be < 3.3V when HIGH
3. Should be < 0.8V when LOW

**If voltage > 3.3V:**
- ❌ This is causing MCU shutdown!
- Fix the divider immediately

## Recommendation

**Use 1kΩ / 1kΩ divider:**
- Simple
- Safe (2.5V output)
- Reliable
- Easy to implement

**Wiring:**
```
Optocoupler Output (5V) → [1kΩ] → GPIO4 → [1kΩ] → GND
```


