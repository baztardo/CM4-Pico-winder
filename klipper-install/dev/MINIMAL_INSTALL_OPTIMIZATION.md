# Minimal Install Optimization

## Problem

The current "minimal" install still includes many files that aren't needed:
- Sensor files (`sensor_adxl345.c`, `sensor_mpu9250.c`, etc.) - not used
- Neopixel files - not used
- LCD display files - not used
- MCU files for other MCUs - not needed if using STM32G0B1
- Other unused features

## Current State

Even with `.config.winder-minimal` disabling features, Klipper's build system may still:
1. **Require files to exist** (even if not compiled)
2. **Include them in dependency checks**
3. **Reference them in Makefiles**

## Analysis

Run the analysis script to see what's actually needed:

```bash
# On CM4 or with dev clone
cd klipper-install
./scripts/analyze_klipper_dependencies.sh ~/klipper-install/klipper-dev
```

This will show:
- What files are in `src/`
- What's actually compiled (if `.config` exists)
- File sizes
- Conditional compilation patterns

## Solution Approaches

### Option 1: Selective File Copying (Current)

**Pros:**
- Simple
- Works with existing Klipper build system
- No patches needed

**Cons:**
- Still copies some unused files
- Need to maintain list of "essential" files

**Current essential files:**
```bash
ESSENTIAL_DIRS=(
    "klippy"      # Python runtime (required)
    "lib"         # Libraries (chelper, etc.)
    "scripts"     # Build scripts
    "src"         # Firmware source (ALL of it currently)
    ".github"     # Version info
)
```

### Option 2: Patch Makefile to Skip Unused Files

**Pros:**
- Truly minimal
- Only compiles what's needed
- Smaller binary

**Cons:**
- Requires maintaining Klipper patches
- May break on Klipper updates
- More complex

**Example patch:**
```makefile
# Skip sensor files if not enabled
ifeq ($(CONFIG_SENSOR_ADXL345),)
  # Don't include sensor_adxl345.c
endif
```

### Option 3: Post-Copy Cleanup

**Pros:**
- Simple
- No patches needed
- Can be automated

**Cons:**
- Files copied then deleted (wasteful)
- Need to know what's safe to delete

**Example:**
```bash
# After copying src/, remove unused MCU dirs
rm -rf src/atmega* src/sam* src/lpc176x*  # Keep only STM32
rm -rf src/sensor_*  # Remove sensors if not enabled
```

### Option 4: Build-Time Analysis

**Pros:**
- Most accurate
- Based on actual build needs

**Cons:**
- Requires running build first
- Complex to implement

**Process:**
1. Run `make -n` (dry-run) to see what would be compiled
2. Parse output to find actual source files
3. Copy only those files

## Recommended Approach

**Hybrid: Option 1 + Option 3**

1. **Copy essential structure** (current approach)
2. **Post-copy cleanup** based on `.config`:
   - Remove unused MCU directories
   - Remove disabled sensor files
   - Remove disabled display files
   - Keep only what's enabled in `.config`

## Implementation Plan

### Step 1: Analyze Dependencies

```bash
./scripts/analyze_klipper_dependencies.sh
```

### Step 2: Create Cleanup Script

```bash
# scripts/cleanup_unused_files.sh
# Reads .config and removes unused files
```

### Step 3: Integrate into Install

```bash
# After copying src/, run cleanup
cleanup_unused_files.sh ~/klipper .config.winder-minimal
```

## Files That Can Likely Be Removed

Based on `.config.winder-minimal` (disabled features):

- `src/sensor_*.c` - All sensors disabled
- `src/lcd_*.c` - LCD displays disabled  
- `src/neopixel.c` - Neopixel disabled
- `src/atmega*` - Not using AVR MCUs
- `src/sam*` - Not using SAM MCUs
- `src/lpc176x*` - Not using LPC MCUs
- `src/rp2040*` - Only if using STM32 (or vice versa)

## Testing

After cleanup, verify:
1. `make menuconfig` still works
2. `make` builds successfully
3. Firmware flashes correctly
4. Klipper runs without errors

## Next Steps

1. Run analysis script on actual install
2. Identify safe-to-remove files
3. Create cleanup script
4. Test minimal install
5. Document what was removed and why

