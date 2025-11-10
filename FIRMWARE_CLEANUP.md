# CM4-Pico-Winder Firmware Cleanup Summary

## Source Code Changes (src/)

### Files Removed (8 files)
- ❌ `neopixel.c` - LED strip control (not needed)
- ❌ `thermocouple.c` - Temperature sensing (not needed)
- ❌ `sdiocmds.c/.h` - SD card interface (not needed)
- ❌ `sos_filter.c/.h` - Input shaping filter (3D printing feature)
- ❌ `stm32/sdio.c/.h` - STM32 SDIO driver (not needed)

### Features Kept (Essential for CNC Winder)

**Core Motion:**
- ✅ `stepper.c` - Stepper motor control
- ✅ `endstop.c` - Limit switches
- ✅ `trsync.c` - Multi-axis synchronization
- ✅ `gpiocmds.c` - GPIO control

**Communication:**
- ✅ `spicmds.c` - SPI bus
- ✅ `i2ccmds.c` - I2C bus
- ✅ `spi_software.c` - Software SPI
- ✅ `i2c_software.c` - Software I2C

**Control & Feedback:**
- ✅ `pwmcmds.c` - PWM outputs (motor/tension control)
- ✅ `adccmds.c` - Analog inputs (sensors)
- ✅ `pulse_counter.c` - Encoder support
- ✅ `buttons.c` - Physical button inputs (start/stop/jog)
- ✅ `tmcuart.c` - TMC stepper driver communication

**Core System:**
- ✅ `command.c` - Command processing
- ✅ `sched.c` - Scheduler
- ✅ `basecmd.c` - Base commands

## Kconfig Changes

### Defaults Changed (Optimized for CNC Winder)

**Disabled by Default:**
- `CONFIG_WANT_NEOPIXEL=n` - LED strips not needed
- `CONFIG_WANT_THERMOCOUPLE=n` - Temperature sensing not needed

**Enabled by Default (CNC Winder Essentials):**
- `CONFIG_WANT_ADC=y` - For tension/position sensors
- `CONFIG_WANT_SPI=y` - For TMC drivers and external chips
- `CONFIG_WANT_I2C=y` - For external sensors/displays
- `CONFIG_WANT_HARD_PWM=y` - For motor speed/tension control
- `CONFIG_WANT_BUTTONS=y` - For physical controls
- `CONFIG_WANT_TMCUART=y` - For TMC stepper drivers
- `CONFIG_WANT_PULSE_COUNTER=y` - For encoder feedback

## Build Configuration

The build system (`src/Makefile`) has been updated to:
- Comment out neopixel compilation
- Comment out thermocouple compilation
- Comment out SDIO compilation
- Comment out SOS filter compilation
- Keep all essential CNC winder features

## What This Means for Your Winder

**You Now Have:**
1. ✅ Multi-axis coordinated motion control
2. ✅ TMC stepper driver support (silent, precise)
3. ✅ Encoder feedback support (closed-loop control)
4. ✅ PWM control (for tension/speed regulation)
5. ✅ Button inputs (physical machine controls)
6. ✅ ADC inputs (analog sensors)
7. ✅ SPI/I2C buses (external peripherals)
8. ✅ All core motion planning & G-code

**You Don't Have (Removed Bloat):**
1. ❌ Temperature control
2. ❌ LED strip animations
3. ❌ SD card reading
4. ❌ Input shaping filters
5. ❌ 3D printer-specific features

## Firmware Size Impact

Estimated reduction: **5-10KB** in firmware size by removing:
- Neopixel bit-banging code
- Thermocouple SPI protocols
- SDIO drivers
- SOS filter math

## Next Build

When you run `make clean && make`, the firmware will:
- Only compile CNC winder essentials
- Skip removed features
- Be smaller and faster
- Have cleaner code paths

## Testing Checklist

After flashing new firmware, test:
- [ ] Stepper motors respond
- [ ] Endstops work
- [ ] TMC drivers communicate (if used)
- [ ] PWM outputs work
- [ ] Encoders read correctly (if used)
- [ ] Buttons respond
- [ ] G-code commands accepted

