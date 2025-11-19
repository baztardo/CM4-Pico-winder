# Apply Minimal Klipper Configuration for Winder

This preset disables all unused features, keeping only what's needed for the CNC winder project.

## What's Enabled

✅ **Essential Features:**
- STM32G0B1 MCU support
- USB serial communication
- Stepper motor control
- Hardware PWM (for BLDC motor)
- ADC (for angle sensor)
- Pulse counter (for Hall sensors)
- GPIO control
- TMC2209 UART support
- Endstop support

## What's Disabled

❌ **Unused Features (reduces firmware size):**
- LCD displays (ST7920, HD44780)
- Neopixel LED strips
- Accelerometers (ADXL345, LIS2DW, MPU9250, ICM20948)
- Thermocouples
- Load cells (HX711)
- ADS1220 ADC chip
- LDC1612 sensor
- Input shaping (SOS filter)
- SD card support

## How to Apply

### On CM4:

```bash
cd ~/klipper

# Copy the minimal config preset
scp user@mac:~/path/to/.config.winder-minimal .config

# Or manually copy the file content:
nano .config
# Paste the content from .config.winder-minimal

# Build firmware
make clean
make

# Flash firmware
make flash FLASH_DEVICE=/dev/serial/by-id/usb-Klipper_stm32g0b1xx_*-if00
```

### From Your Mac:

```bash
# Copy preset to CM4
scp .config.winder-minimal winder@winder.local:~/klipper/.config

# SSH to CM4 and build
ssh winder@winder.local
cd ~/klipper
make clean
make
make flash FLASH_DEVICE=/dev/serial/by-id/usb-Klipper_stm32g0b1xx_*-if00
```

## Verify Configuration

After building, check the firmware size:

```bash
ls -lh out/klipper.bin
```

The minimal config should produce a smaller firmware file (~50-70KB vs ~100KB+ with all features).

## Customize Further

If you want to disable more features (e.g., buttons, I2C), edit `.config`:

```bash
cd ~/klipper
make menuconfig

# Navigate to "Optional features" and disable what you don't need
# Save and exit
make clean
make
```

## Benefits

- **Smaller firmware binary** - Faster flashing, less MCU flash memory usage (~50-70KB vs ~100-120KB)
- **Faster compilation** - Less code to compile (~15-30s vs ~30-60s)
- **Easier debugging** - Fewer features to troubleshoot
- **Lower risk** - Less code = fewer potential bugs

**Note:** This reduces the **compiled firmware size**, NOT the Klipper repository size. You still need to clone the full Klipper repo (~50-100MB). See `docs/MINIMAL_CONFIG_EXPLAINED.md` for details.

## Troubleshooting

If you get build errors after applying the minimal config:

1. **Check MCU selection:**
   ```bash
   grep CONFIG_MCU .config
   # Should show: CONFIG_MCU="stm32g0b1xx"
   ```

2. **Verify essential features are enabled:**
   ```bash
   grep CONFIG_WANT .config | grep "=y"
   # Should show: ADC, SPI, PWM, PULSE_COUNTER, TMCUART
   ```

3. **If TMC2209 doesn't work:**
   - Make sure `CONFIG_WANT_TMCUART=y` is set
   - Make sure `CONFIG_WANT_SPI=y` is set

4. **If ADC doesn't work:**
   - Make sure `CONFIG_WANT_ADC=y` is set
   - Make sure `CONFIG_HAVE_GPIO_ADC=y` is set

## Reverting to Full Config

If you need to go back to the full configuration:

```bash
cd ~/klipper
make menuconfig
# Enable all features you need
make clean
make
```

