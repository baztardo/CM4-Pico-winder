# Pin Conflict Analysis - MCU Shutdown Issue

## Problem Identified

**All motor control pins are conflicting with I2C bus pins!**

The RP2040 firmware defines I2C buses that use specific GPIO pairs. Even if you're not using I2C, the firmware may try to initialize these pins, causing conflicts and MCU shutdowns.

## Current Pin Usage (CONFLICTING!)

| Pin | Current Use | I2C Conflict | Issue |
|-----|-------------|--------------|-------|
| gpio3 | motor_dir_pin | i2c1a (SDA) | **CONFLICT** |
| gpio4 | motor_hall_pin | i2c0b (SDA) | **CONFLICT** |
| gpio9 | TMC UART | i2c0c (SCL) | **CONFLICT** |
| gpio16 | endstop_pin | i2c0e (SDA) | **CONFLICT** |
| gpio17 | motor_pwm_pin | i2c0e (SCL) | **CONFLICT** |
| gpio18 | motor_brake_pin | i2c1e (SDA) | **CONFLICT** |
| gpio22 | spindle_hall_pin | i2c1f (SDA) | **CONFLICT** |

## I2C Bus Definitions (from RP2040 firmware)

```
BUS_PINS_i2c0a = gpio0,gpio1
BUS_PINS_i2c0b = gpio4,gpio5    ← gpio4 CONFLICT
BUS_PINS_i2c0c = gpio8,gpio9    ← gpio9 CONFLICT
BUS_PINS_i2c0d = gpio12,gpio13
BUS_PINS_i2c0e = gpio16,gpio17  ← gpio16, gpio17 CONFLICT
BUS_PINS_i2c0f = gpio20,gpio21
BUS_PINS_i2c0g = gpio24,gpio25
BUS_PINS_i2c0h = gpio28,gpio29

BUS_PINS_i2c1a = gpio2,gpio3    ← gpio3 CONFLICT
BUS_PINS_i2c1b = gpio6,gpio7
BUS_PINS_i2c1c = gpio10,gpio11
BUS_PINS_i2c1d = gpio14,gpio15
BUS_PINS_i2c1e = gpio18,gpio19  ← gpio18 CONFLICT
BUS_PINS_i2c1f = gpio22,gpio23  ← gpio22 CONFLICT
BUS_PINS_i2c1g = gpio26,gpio27
```

## Safe Pin Recommendations

### Currently Used (Safe):
- gpio5: dir_pin (stepper_y) - **SAFE** (not I2C)
- gpio6: step_pin (stepper_y) - **SAFE** (not I2C)
- gpio7: enable_pin (stepper_y) - **SAFE** (not I2C)

### Available Safe Pins for Motor Control:
- gpio10, gpio11 - **SAFE** (not I2C, not used)
- gpio12, gpio13 - **SAFE** (not I2C, not used)
- gpio14, gpio15 - **SAFE** (not I2C, not used)
- gpio19 - **SAFE** (not I2C, not used)
- gpio20, gpio21 - **SAFE** (not I2C, not used)
- gpio23 - **SAFE** (not I2C, not used)
- gpio26, gpio27 - **SAFE** (not I2C, not used)

## Recommended Pin Reassignment

### Option 1: Minimal Changes (Keep TMC UART on gpio9)
```
motor_pwm_pin: gpio10      (was gpio17)
motor_dir_pin: gpio11      (was gpio3)
motor_brake_pin: gpio12    (was gpio18)
motor_hall_pin: gpio13     (was gpio4)
spindle_hall_pin: gpio14   (was gpio22)
endstop_pin: gpio15        (was gpio16)
uart_pin: gpio9            (keep - but still conflicts!)
```

### Option 2: Move TMC UART Too (Safest)
```
motor_pwm_pin: gpio10
motor_dir_pin: gpio11
motor_brake_pin: gpio12
motor_hall_pin: gpio13
spindle_hall_pin: gpio14
endstop_pin: gpio15
uart_pin: gpio19           (was gpio9 - move to safe pin)
```

### Option 3: Keep Some Pins, Move Others
```
motor_pwm_pin: gpio10      (move from gpio17)
motor_dir_pin: gpio11      (move from gpio3)
motor_brake_pin: gpio12    (move from gpio18)
motor_hall_pin: gpio13     (move from gpio4)
spindle_hall_pin: gpio14   (move from gpio22)
endstop_pin: gpio15        (move from gpio16)
uart_pin: gpio19           (move from gpio9)
```

## Why This Causes MCU Shutdown

1. **Pin Multiplexing**: RP2040 pins can be used for multiple functions (GPIO, I2C, UART, SPI, etc.)
2. **Firmware Initialization**: Even if you don't configure I2C, the firmware may try to initialize I2C buses
3. **Pin Conflicts**: When a pin is configured for GPIO but the firmware expects I2C, it can cause:
   - Pin state conflicts
   - Hardware errors
   - MCU communication failures
   - MCU shutdown

## Solution

**Change all conflicting pins to safe pins that are NOT part of any I2C bus definition.**

This is likely why:
- MCU keeps shutting down
- It only worked when everything was unplugged (no pin conflicts)
- USB connection seems unstable (MCU communication errors)

## Next Steps

1. **Choose a pin reassignment option** (Option 2 is safest)
2. **Update `printer.cfg`** with new pin assignments
3. **Update hardware connections** to match new pins
4. **Test MCU stability** - should no longer shutdown


