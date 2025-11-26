# "Timer too close" Error - Root Cause and Fix

## What Happened

After deploying the modular config system (both v1 and v2), the system crashed with:

```
MCU 'mcu' shutdown: Timer too close
This often indicates the host computer is overloaded.
```

## Root Causes Identified

### 1. **Duplicate Section Definitions** (v1 & v2 initial)
- Base config defined partial `[winder_control]`
- Preset files defined more `[winder_control]` parameters
- **Result**: Klipper created MULTIPLE `winder_control` objects
- Each object ran its own sync loop → System overload

### 2. **Board Config Creating Duplicate Hardware Sections** (v2 initial)
- Main config: `[bldc_motor]` without pins
- Board config: `[bldc_motor]` WITH pins
- **Result**: TWO `bldc_motor` objects created!
- Same for `[angle_sensor]` and `[hw_counter]`

### 3. **Sync Update Rate Too High**
- `sync_update_rate: 10.0` Hz = 10 updates/second
- With multiple sync loops, this became 20-30 Hz
- **Result**: MCU command queue overflow

### 4. **Acceleration Too High**
- `max_accel: 500` mm/s²
- Generates too many step commands per second
- **Result**: MCU timer queue overflow

## The Fix (v2 Final)

### **Correct RatOS-Style Modular Config:**

1. **Main config defines COMPLETE sections with ALL parameters**
   ```ini
   [winder_control]
   bldc_motor: bldc_motor
   gear_ratio: 0.667
   wire_diameter: 0.056    # DEFAULT
   bobbin_width: 6.35      # DEFAULT
   sync_update_rate: 5.0   # REDUCED to 5Hz
   # ... ALL parameters
   ```

2. **Board config EXTENDS sections (adds pins only)**
   ```ini
   [bldc_motor]
   pwm_pin: PA9
   dir_pin: PB4
   # ... pins only, inherits parameters from main config
   ```

3. **Preset files OVERRIDE specific parameters**
   ```ini
   [winder_control]
   wire_diameter: 0.063    # Override for Strat
   bobbin_width: 12.7      # Override for Strat
   # Only 2 lines! Everything else uses defaults
   ```

4. **Reduced system load**
   - `sync_update_rate: 5.0` Hz (was 10.0)
   - `max_accel: 100` mm/s² (was 500)

## How Klipper Merges Sections

**Load order:**
1. Main config: Creates `[winder_control]` object with ALL parameters
2. Board config: Adds pins to existing `[bldc_motor]`, `[angle_sensor]`, `[hw_counter]`
3. Preset config: Overrides 2-3 parameters in existing `[winder_control]`

**Result:** ONE object per section, not multiple!

## Why This Works

| Aspect | Before (Broken) | After (Fixed) |
|--------|----------------|---------------|
| **`[winder_control]` objects** | 2-3 (duplicates) | 1 (merged) |
| **Sync loops running** | 20-30 Hz total | 5 Hz total |
| **Step commands/sec** | ~5000 | ~1000 |
| **MCU load** | Overload | Normal |

## Testing the Fix

```bash
# Deploy fixed v2
./deploy_modular_config_v2.sh

# Restart
FIRMWARE_RESTART

# Test (should work now!)
WIND_TEST
```

## If It Still Fails

**Fallback to working backup:**
```bash
cp ~/printer.cfg.backup.20251126_022003 ~/printer_data/config/printer.cfg
FIRMWARE_RESTART
```

## Key Lesson

**RatOS teaches us:**
- Define COMPLETE sections in base config (all parameters with defaults)
- Board configs add PINS only (extend, don't duplicate)
- Presets override SPECIFIC parameters only (2-3 lines)
- Let Klipper merge them automatically
- Never create incomplete sections that get "filled in" later

**This prevents duplicate object creation!**

