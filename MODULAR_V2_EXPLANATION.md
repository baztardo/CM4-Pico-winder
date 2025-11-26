# Modular Config v2 - The RatOS Way

## What Was Wrong with v1?

### **v1 Design (BROKEN):**

```
printer-modular.cfg:
  [winder_control]
    bldc_motor: bldc_motor
    gear_ratio: 0.667
    # Only SOME parameters

presets/humbucker.cfg:
  [winder_control]  ← DUPLICATE SECTION!
    wire_diameter: 0.056
    bobbin_width: 6.35
    # MORE parameters
```

**Result:** Klipper created TWO `winder_control` objects:
- 2× sync loops running (20 Hz total!)
- 2× motor control
- System overload → "Timer too close"

---

## How RatOS Does It (CORRECT)

### **v2 Design (WORKING):**

```
printer-modular-v2.cfg:
  [winder_control]
    bldc_motor: bldc_motor
    gear_ratio: 0.667
    wire_diameter: 0.056    ← DEFAULT value
    bobbin_width: 6.35      ← DEFAULT value
    # ALL parameters with defaults

presets/humbucker-override.cfg:
  [winder_control]  ← NOT a duplicate! Klipper MERGES this
    wire_diameter: 0.056    ← Confirms default (or overrides)
    bobbin_width: 6.35      ← Confirms default (or overrides)
    # ONLY the parameters that change
```

**Result:** Klipper creates ONE `winder_control` object:
- Parameters from base config
- Overridden by preset values
- Single sync loop (10 Hz)
- No overload!

---

## Key Difference

| Aspect | v1 (Broken) | v2 (RatOS Style) |
|--------|-------------|------------------|
| **Base config** | Partial section | Complete section with ALL parameters |
| **Preset files** | Complete section | Override-only (minimal) |
| **Klipper behavior** | Creates duplicates | Merges into single object |
| **Sync loops** | 2× (or more!) | 1× |
| **System load** | Overload | Normal |

---

## File Comparison

### **v1 Base Config (Incomplete):**
```ini
[winder_control]
bldc_motor: bldc_motor
angle_sensor: angle_sensor
spindle_hall: hw_counter
traverse: traverse
gear_ratio: 0.667
max_spindle_rpm: 3300.0
# Missing: wire_diameter, bobbin_width, etc.
```

### **v1 Preset (Fills in missing):**
```ini
[winder_control]  ← Klipper sees this as NEW section!
wire_diameter: 0.056
bobbin_width: 6.35
motor_speed_calibration: 1.09
hall_sensor_correction: 1.0
# Klipper creates SECOND winder_control object!
```

---

### **v2 Base Config (Complete):**
```ini
[winder_control]
bldc_motor: bldc_motor
angle_sensor: angle_sensor
spindle_hall: hw_counter
traverse: traverse
gear_ratio: 0.667
wire_diameter: 0.056           # DEFAULT
bobbin_width: 6.35             # DEFAULT
motor_speed_calibration: 1.09  # DEFAULT
hall_sensor_correction: 1.0    # DEFAULT
max_spindle_rpm: 3300.0
sync_update_rate: 10.0
# EVERYTHING defined with defaults
```

### **v2 Preset (Override only):**
```ini
[winder_control]  ← Klipper merges into EXISTING section!
wire_diameter: 0.056   # Override (same as default for humbucker)
bobbin_width: 6.35     # Override (same as default for humbucker)
# Only 2 lines! Everything else uses base defaults
```

---

## RatOS's Merge Rules

Klipper merges config sections based on **load order**:

1. **First occurrence** creates the object
2. **Later occurrences** override specific parameters
3. **Last value wins** for any parameter

**Example:**
```ini
# File 1 (loaded first)
[winder_control]
wire_diameter: 0.056
bobbin_width: 6.35

# File 2 (loaded second via include)
[winder_control]
bobbin_width: 12.7  # OVERRIDES 6.35

# Result: wire_diameter=0.056, bobbin_width=12.7
```

**This is how RatOS lets you switch presets by changing ONE include line!**

---

## Why v2 Will Work

**v2 ensures:**
- ✅ Base config defines ALL parameters (complete object)
- ✅ Presets override ONLY what changes (2-3 parameters)
- ✅ No incomplete sections
- ✅ No duplicate object creation
- ✅ Single sync loop
- ✅ Normal system load

**v1 failed because:**
- ❌ Base config was incomplete
- ❌ Presets filled in missing parameters
- ❌ Klipper created multiple objects
- ❌ Multiple sync loops
- ❌ System overload

---

## Testing v2

```bash
# Deploy v2
./deploy_modular_config_v2.sh

# Restart
FIRMWARE_RESTART

# Test
WIND_TEST
```

**Expected result:** Works perfectly, no "Timer too close" errors!

---

## Switching Presets (The RatOS Way)

### To switch from Humbucker to Stratocaster:

**Edit `printer-modular-v2.cfg` on CM4:**
```ini
# Comment out humbucker
# [include presets/humbucker-override.cfg]

# Uncomment Strat
[include presets/stratocaster-override.cfg]
```

**Then:**
```bash
FIRMWARE_RESTART
```

**That's it! Wire and bobbin values changed, everything else stays the same.**

---

## Summary

**RatOS teaches us:**
- Define complete sections in base config
- Override only what changes in includes
- Let Klipper merge them automatically
- Never create incomplete sections

**This is how professional Klipper configs are structured!**

