# BLDC Motor Module

## Overview

The `[bldc_motor]` module provides complete control over a BLDC (Brushless DC) motor, including PWM speed control, direction control, brake control, and optional power control.

## Features

- **PWM Speed Control**: Variable speed control via PWM pin
- **Direction Control**: Forward/reverse direction control
- **Brake Control**: Electronic brake control
- **Power Control**: Optional power supply control
- **Safety**: Automatic shutdown on Klipper shutdown
- **G-code Commands**: Full G-code interface for control

## Configuration

### Basic Configuration

```cfg
[bldc_motor]
pwm_pin: PC9        # PWM pin for speed control (must be PWM-capable)
dir_pin: PB4        # Direction pin (digital output)
brake_pin: PD5      # Brake pin (digital output, optional)
power_pin: PB7      # Power pin (digital output, optional)
```

### Full Configuration

```cfg
[bldc_motor]
# Required pins
pwm_pin: PC9
dir_pin: PB4

# Optional pins
brake_pin: PD5
power_pin: PB7

# Motor parameters
max_rpm: 3000.0        # Maximum RPM
min_rpm: 10.0          # Minimum RPM
pwm_frequency: 1000.0  # PWM frequency in Hz
min_pwm_duty: 0.05     # Minimum PWM duty cycle (5%)

# Pin inversion (if level shifter inverts)
dir_inverted: False
brake_inverted: False
```

### Pin Behavior

**PWM Pin:**
- Controls motor speed
- Duty cycle maps linearly: 0% = 0 RPM, 100% = max_rpm
- Minimum duty cycle enforced to prevent stalling

**DIR Pin:**
- BLDC controller: LOW = change direction, HIGH = normal
- `dir_inverted=False`: MCU LOW → direction change
- `dir_inverted=True`: MCU HIGH → direction change

**Brake Pin:**
- BLDC controller: HIGH = brake ON, LOW = brake OFF
- `brake_inverted=False`: MCU HIGH → brake ON
- `brake_inverted=True`: MCU LOW → brake ON

**Power Pin:**
- Controls motor power supply
- HIGH = power ON, LOW = power OFF
- Optional - motor can run without this if always powered

## G-code Commands

### BLDC_START

Start the motor with specified RPM and direction.

**Parameters:**
- `RPM` (float): Target RPM (default: current target RPM)
- `DIRECTION` (string): "forward" or "reverse" (default: "forward")

**Example:**
```gcode
BLDC_START RPM=1000 DIRECTION=forward
BLDC_START RPM=500 DIRECTION=reverse
```

### BLDC_STOP

Stop the motor (sets RPM to 0).

**Example:**
```gcode
BLDC_STOP
```

### BLDC_SET_RPM

Set motor RPM without changing direction.

**Parameters:**
- `RPM` (float): Target RPM (0 to max_rpm)

**Example:**
```gcode
BLDC_SET_RPM RPM=1500
BLDC_SET_RPM RPM=0  # Stop motor
```

### BLDC_SET_DIR

Set motor direction without changing RPM.

**Parameters:**
- `DIRECTION` (string): "forward" or "reverse"

**Example:**
```gcode
BLDC_SET_DIR DIRECTION=forward
BLDC_SET_DIR DIRECTION=reverse
```

### BLDC_SET_BRAKE

Engage or release brake.

**Parameters:**
- `ENGAGE` (string): "1" or "0" (or "true"/"false", "yes"/"no", "on"/"off")

**Example:**
```gcode
BLDC_SET_BRAKE ENGAGE=1  # Engage brake
BLDC_SET_BRAKE ENGAGE=0  # Release brake
```

### BLDC_SET_POWER

Enable or disable motor power supply.

**Parameters:**
- `ENABLE` (string): "1" or "0" (or "true"/"false", "yes"/"no", "on"/"off")

**Example:**
```gcode
BLDC_SET_POWER ENABLE=1  # Power ON
BLDC_SET_POWER ENABLE=0  # Power OFF
```

### QUERY_BLDC

Query motor status.

**Example:**
```gcode
QUERY_BLDC
```

**Response:**
```
BLDC Motor Status:
  RPM: 1000.0 / 1000.0 (target)
  Running: True
  Direction: forward
  Brake: released
  Power: ON
  Pins: PWM=PC9, DIR=PB4, Brake=PD5, Power=PB7
```

## Python API

Other modules can control the BLDC motor:

```python
# Get BLDC motor module
bldc = self.printer.lookup_object('bldc_motor')

# Start motor
bldc.start_motor(rpm=1000, forward=True)

# Set RPM
bldc.set_rpm(1500)

# Set direction
bldc.set_direction(forward=False)

# Set brake
bldc.set_brake(engage=True)

# Set power
bldc.set_power(enable=True)

# Stop motor
bldc.stop_motor()

# Get status
status = bldc.get_status(None)
rpm = status['rpm']
is_running = status['is_running']
```

## Integration with Winder Module

The BLDC motor module can be used independently or integrated with the winder module:

```python
# In winder.py
class WinderController:
    def __init__(self, config):
        # Get BLDC motor
        self.bldc_motor = self.printer.lookup_object('bldc_motor', None)
        
        if self.bldc_motor:
            # Use BLDC motor module
            self.bldc_motor.start_motor(rpm=1000, forward=True)
        else:
            # Fall back to direct pin control
            # ... existing code ...
```

## Safety Features

1. **Automatic Shutdown**: Motor stops automatically on Klipper shutdown
2. **RPM Limits**: RPM clamped to valid range (0 to max_rpm)
3. **Minimum Duty Cycle**: Prevents motor stalling at low speeds
4. **Power Control**: Optional power supply control for safety

## Troubleshooting

### Motor doesn't start
- Check power pin is enabled: `BLDC_SET_POWER ENABLE=1`
- Check brake is released: `BLDC_SET_BRAKE ENGAGE=0`
- Check RPM is above minimum: `BLDC_SET_RPM RPM=20`

### Motor runs in wrong direction
- Check `dir_inverted` setting in config
- Try: `BLDC_SET_DIR DIRECTION=reverse`

### Motor doesn't respond to PWM
- Verify PWM pin is PWM-capable (check `hard_pwm.c`)
- Check PWM frequency is reasonable (100-10000 Hz)
- Verify minimum duty cycle isn't too high

### Brake doesn't work
- Check `brake_inverted` setting in config
- Verify brake pin is configured: `brake_pin: PD5`
- Test with: `BLDC_SET_BRAKE ENGAGE=1`

## Example Usage Sequence

```gcode
# 1. Enable power
BLDC_SET_POWER ENABLE=1

# 2. Release brake
BLDC_SET_BRAKE ENGAGE=0

# 3. Set direction
BLDC_SET_DIR DIRECTION=forward

# 4. Start motor
BLDC_START RPM=1000

# 5. Adjust speed
BLDC_SET_RPM RPM=1500

# 6. Change direction while running
BLDC_SET_DIR DIRECTION=reverse

# 7. Stop motor
BLDC_STOP

# 8. Engage brake
BLDC_SET_BRAKE ENGAGE=1

# 9. Disable power
BLDC_SET_POWER ENABLE=0
```

## Configuration Examples

### M4P Board (E0 Header)

```cfg
[bldc_motor]
# Using E0 header pins
pwm_pin: PB3    # E0 STEP - PWM-capable
dir_pin: PB4    # E0 DIR
brake_pin: PD5  # E0 ENA
power_pin: PB7  # Bed heater port

max_rpm: 3000.0
min_rpm: 10.0
pwm_frequency: 1000.0
min_pwm_duty: 0.05

# Non-inverting level shifter (MC74HCT125ADTR2G)
dir_inverted: False
brake_inverted: False
```

### Motor 5 (Extruder Header)

```cfg
[bldc_motor]
# Using Motor 5 header
pwm_pin: PC9    # Motor 5 STEP - PWM-capable
dir_pin: PD1    # Motor 5 DIR
brake_pin: PD2  # Motor 5 ENA
power_pin: PB7  # Bed heater port

max_rpm: 3000.0
min_rpm: 10.0
pwm_frequency: 1000.0
min_pwm_duty: 0.05
```

## See Also

- `CREATING_CUSTOM_MODULES.md` - How to create custom modules
- `MODULE_QUICK_REFERENCE.md` - Quick reference for module development
- `klippy/extras/output_pin.py` - Simple output pin control
- `klippy/extras/pwm_tool.py` - PWM tool module

