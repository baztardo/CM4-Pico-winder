# Makefile Patching - Why We Don't Need It

## How Klipper Makefiles Work

Klipper's `src/Makefile` uses **conditional compilation**:

```makefile
src-$(CONFIG_WANT_ADXL345) += sensor_adxl345.c
src-$(CONFIG_WANT_NEOPIXEL) += neopixel.c
src-$(CONFIG_WANT_ST7920) += lcd_st7920.c
```

## What This Means

- If `CONFIG_WANT_ADXL345=y` → `src-y += sensor_adxl345.c` (compiles it)
- If `CONFIG_WANT_ADXL345` is not set → `src- += sensor_adxl345.c` (empty, doesn't compile)

**The Makefile only references files when the config option is enabled.**

## So We Don't Need Makefile Patching!

Since `.config.winder-minimal` has:
```
# CONFIG_WANT_ADXL345 is not set
# CONFIG_WANT_NEOPIXEL is not set
# CONFIG_WANT_ST7920 is not set
```

The Makefile will **never try to compile** those files, even if they don't exist.

## What We DO Need to Patch

**Only `src/Kconfig`** - because it unconditionally sources all MCU Kconfig files:
```kconfig
source "src/avr/Kconfig"      # Always sourced, even if MCU not used
source "src/stm32/Kconfig"    # Always sourced
```

## Current Approach

1. ✅ **Cleanup:** Remove unused MCU directories and sensor files
2. ✅ **Patch Kconfig:** Comment out missing MCU Kconfig sources
3. ❌ **Skip Makefile:** Not needed - uses conditional compilation

## If Makefile Fails

If `make` still fails after cleanup, it means:
- A file is referenced unconditionally (not using `src-$(CONFIG_XXX)`)
- Or there's a syntax error from our patching

In that case, restore from backup and we'll investigate:
```bash
cp src/Makefile.backup src/Makefile
```

