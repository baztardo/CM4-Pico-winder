# Why Kconfig Files Must Be Kept

## The Problem

Klipper's `src/Kconfig` file **unconditionally sources** all MCU Kconfig files:

```kconfig
source "src/avr/Kconfig"
source "src/atsam/Kconfig"
source "src/atsamd/Kconfig"
source "src/lpc176x/Kconfig"
source "src/stm32/Kconfig"
source "src/hc32f460/Kconfig"
source "src/rp2040/Kconfig"
source "src/pru/Kconfig"
source "src/ar100/Kconfig"
source "src/linux/Kconfig"
source "src/simulator/Kconfig"
```

This means `make menuconfig` **requires** all these Kconfig files to exist, even if you're only using STM32G0B1.

## The Solution

**Keep Kconfig files, remove source code:**

1. ✅ **Keep:** `src/avr/Kconfig` (small, ~few KB)
2. ❌ **Remove:** `src/avr/*.c`, `src/avr/*.h`, `src/avr/Makefile` (large, ~MB)

This way:
- ✅ `make menuconfig` still works (Kconfig files exist)
- ✅ Space saved (source code removed)
- ✅ Build still works (only STM32 code compiled)

## What Gets Removed

For each unused MCU directory (e.g., `src/avr/`):

**Removed:**
- All `.c` source files
- All `.h` header files  
- `Makefile` (not needed if MCU not selected)
- Subdirectories with source code

**Kept:**
- `Kconfig` file (required by `src/Kconfig`)

## Space Savings

- **Kconfig files:** ~1-5KB each (10 files = ~50KB)
- **Source code:** ~100KB-1MB per MCU (10 MCUs = ~1-10MB)
- **Net savings:** ~1-10MB (keeping only ~50KB of Kconfig files)

## Updated Cleanup Strategy

The cleanup script now:
1. Detects unused MCU directories
2. Removes all source code files (`*.c`, `*.h`, `Makefile`)
3. **Keeps** `Kconfig` files
4. Removes empty subdirectories
5. Ensures `Kconfig` still exists (recreates minimal version if needed)

This gives you the best of both worlds:
- ✅ Minimal install (source code removed)
- ✅ `make menuconfig` works (Kconfig files kept)
- ✅ Maximum space savings

