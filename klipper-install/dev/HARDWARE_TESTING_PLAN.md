# Hardware Testing Plan

## Overview

This document outlines a systematic approach to testing all hardware components before GUI development. Test each component independently, then test integration.

## Testing Checklist

### ✅ Completed Tests
- [ ] MCU communication (Klipper API working)
- [ ] Basic pin control (SET_PIN commands)
- [ ] Klipper service running

### 🔄 In Progress
- [ ] Traverse stepper movement
- [ ] BLDC motor control
- [ ] Angle sensor reading
- [ ] Hall sensor reading

### ⏳ Pending Tests
- [ ] Endstop functionality
- [ ] Traverse homing
- [ ] BLDC motor startup/stop
- [ ] Sensor calibration
- [ ] Integration tests

---

## Component Testing

### 1. Traverse Stepper (Y-Axis)

**Hardware:**
- Stepper: Nema 11, TMC2209 driver
- Pins: PF12 (STEP), PF11 (DIR), PB3 (EN), PF13 (UART)
- Endstop: PF3 (Y-Stop)

**Test Scripts Available:**
- `test_home_and_move.sh` - Basic homing and movement
- `test_traverse_step_by_step.sh` - Step-by-step testing
- `diagnose_traverse.sh` - Comprehensive diagnostic
- `check_traverse_status.py` - Status checking

**Test Sequence:**

#### 1.1 Basic Pin Control
```bash
# Test enable pin
python3 klipper_interface.py -g "SET_STEPPER_ENABLE STEPPER=stepper_y ENABLE=1"
python3 klipper_interface.py -g "SET_STEPPER_ENABLE STEPPER=stepper_y ENABLE=0"

# Test direction pin (if using output_pin)
python3 klipper_interface.py -g "SET_PIN PIN=stepper_y_dir VALUE=1"
python3 klipper_interface.py -g "SET_PIN PIN=stepper_y_dir VALUE=0"
```

#### 1.2 TMC2209 Communication
```bash
python3 scripts/diagnose_tmc2209.py
```

**Expected:**
- TMC2209 responds to UART queries
- Driver status shows enabled
- No communication errors

#### 1.3 Endstop Test
```bash
python3 scripts/check_endstop.sh
# Or manually:
python3 klipper_interface.py --query toolhead
# Check endstop state in response
```

**Expected:**
- Endstop reads correctly (HIGH when not pressed, LOW when pressed)
- Inversion correct (`^PF3` for NO switch)

#### 1.4 Homing Test
```bash
python3 klipper_interface.py -g "G28 Y"
```

**Expected:**
- Motor moves toward endstop
- Stops when endstop triggered
- Retracts 5mm
- Position set to 0

#### 1.5 Movement Test
```bash
python3 klipper_interface.py -g "G91"  # Relative mode
python3 klipper_interface.py -g "G1 Y10 F100"  # Move 10mm
python3 klipper_interface.py -g "G1 Y-10 F100"  # Move back
```

**Expected:**
- Smooth movement
- Correct direction
- Accurate distance (10mm = 10mm)
- No stalling or skipping

**Success Criteria:**
- ✅ TMC2209 communication works
- ✅ Endstop reads correctly
- ✅ Homing completes successfully
- ✅ Movement is smooth and accurate
- ✅ Direction control works

---

### 2. BLDC Motor

**Hardware:**
- Motor: Nema 17, 3-phase 24V, 8 poles
- Control: E0 header (PB3=PWM, PB4=DIR, PD5=Brake)
- Power: PB7 (bed heater port, optional)

**Test Scripts Available:**
- `test_pins_simple.py` - Basic pin control
- `direct_hardware_test.py` - Direct MCU control

**Test Sequence:**

#### 2.1 Pin Control Test
```bash
# Test power pin (if configured)
python3 klipper_interface.py -g "SET_PIN PIN=bldc_motor_power VALUE=1"
python3 klipper_interface.py -g "SET_PIN PIN=bldc_motor_power VALUE=0"

# Test direction pin
python3 klipper_interface.py -g "SET_PIN PIN=bldc_motor_dir VALUE=0"  # Forward
python3 klipper_interface.py -g "SET_PIN PIN=bldc_motor_dir VALUE=1"  # Reverse

# Test brake pin
python3 klipper_interface.py -g "SET_PIN PIN=bldc_motor_brake VALUE=1"  # Brake ON
python3 klipper_interface.py -g "SET_PIN PIN=bldc_motor_brake VALUE=0"  # Brake OFF
```

**Expected:**
- Pins respond correctly
- Direction changes when DIR pin toggled
- Brake engages/disengages

#### 2.2 PWM Test
```bash
# Test PWM pin (should be configured as output_pin with pwm=True)
python3 klipper_interface.py -g "SET_PIN PIN=bldc_motor_pwm VALUE=0.1"  # 10% duty
python3 klipper_interface.py -g "SET_PIN PIN=bldc_motor_pwm VALUE=0.5"  # 50% duty
python3 klipper_interface.py -g "SET_PIN PIN=bldc_motor_pwm VALUE=0.0"  # Stop
```

**Expected:**
- PWM output visible on oscilloscope/multimeter
- Frequency correct (1kHz default)
- Duty cycle matches command

#### 2.3 BLDC Module Test
```bash
# Start motor
python3 klipper_interface.py -g "BLDC_START RPM=100 DIRECTION=forward POWER=1"

# Check status
python3 klipper_interface.py -g "QUERY_BLDC"

# Set RPM
python3 klipper_interface.py -g "BLDC_SET_RPM RPM=500"

# Stop motor
python3 klipper_interface.py -g "BLDC_STOP"
```

**Expected:**
- Motor starts smoothly
- RPM increases with duty cycle
- Direction control works
- Brake engages on stop
- Status reports correctly

**Success Criteria:**
- ✅ Power pin controls motor power
- ✅ PWM output correct frequency/duty
- ✅ Direction control works
- ✅ Brake engages/disengages
- ✅ Motor starts/stops smoothly
- ✅ RPM control works

---

### 3. Angle Sensor (PA1)

**Hardware:**
- Sensor: P3022-V1-CW360
- Pin: PA1 (BLTouch SERVOS port)
- Voltage: 5V (with voltage divider to 3.3V)

**Test Scripts Available:**
- `test_pins_simple.py` - Can query ADC
- Custom test needed

**Test Sequence:**

#### 3.1 ADC Reading Test
```bash
# Query ADC directly
python3 klipper_interface.py --query query_adc

# Or use angle_sensor module
python3 klipper_interface.py -g "QUERY_ANGLE_SENSOR"
```

**Expected:**
- ADC reads values (0.0-1.0 range)
- Values change when sensor rotates
- No saturation (unless voltage too high)

#### 3.2 Rotation Test
```python
# Manual rotation test
# Rotate sensor manually and watch ADC values
python3 <<EOF
import time
from klipper_interface import KlipperInterface

klipper = KlipperInterface()
klipper.connect()

for i in range(20):
    status = klipper.query_objects({"angle_sensor": None})
    if status and "angle_sensor" in status:
        angle = status["angle_sensor"]
        print(f"Angle: {angle.get('current_angle_deg', 0):.2f}° "
              f"ADC: {angle.get('adc_min', 0):.4f}-{angle.get('adc_max', 0):.4f}")
    time.sleep(0.5)

klipper.disconnect()
EOF
```

**Expected:**
- ADC values change smoothly with rotation
- Full 360° rotation maps to full ADC range
- No dead zones or saturation (after calibration)

#### 3.3 Calibration Test
```bash
# Auto-calibration
python3 klipper_interface.py -g "ANGLE_SENSOR_CALIBRATE ACTION=RESET"
# Rotate sensor through full range
python3 klipper_interface.py -g "QUERY_ANGLE_SENSOR"

# Manual calibration (if needed)
python3 klipper_interface.py -g "ANGLE_SENSOR_CALIBRATE ACTION=MANUAL MIN=0.04 MAX=1.0"
```

**Expected:**
- Auto-calibration detects min/max
- Manual calibration works
- Calibration persists

**Success Criteria:**
- ✅ ADC reads correctly
- ✅ Values change with rotation
- ✅ Full range coverage (no saturation)
- ✅ Calibration works
- ✅ Angle calculation correct

---

### 4. Spindle Hall Sensor (PC15)

**Hardware:**
- Sensor: NPN NO Hall sensor
- Pin: PC15
- Pulses: 1 per revolution

**Test Scripts Available:**
- Custom test needed

**Test Sequence:**

#### 4.1 Pulse Detection Test
```bash
# Query Hall sensor
python3 klipper_interface.py -g "QUERY_SPINDLE_HALL"

# Rotate spindle manually and watch count increase
```

**Expected:**
- Count increments with each revolution
- Frequency/RPM calculated correctly
- No false triggers

#### 4.2 RPM Calculation Test
```python
# Test RPM calculation during rotation
python3 <<EOF
import time
from klipper_interface import KlipperInterface

klipper = KlipperInterface()
klipper.connect()

print("Rotate spindle and watch RPM...")
for i in range(10):
    status = klipper.query_objects({"spindle_hall": None})
    if status and "spindle_hall" in status:
        hall = status["spindle_hall"]
        print(f"RPM: {hall.get('measured_rpm', 0):.1f} "
              f"Count: {hall.get('current_count', 0)} "
              f"Freq: {hall.get('frequency', 0):.3f} Hz")
    time.sleep(1)

klipper.disconnect()
EOF
```

**Expected:**
- RPM matches manual rotation speed
- Count increases correctly
- Frequency calculation accurate

**Success Criteria:**
- ✅ Pulses detected correctly
- ✅ Count increments properly
- ✅ RPM calculation accurate
- ✅ No false triggers

---

### 5. Integration Tests

#### 5.1 Traverse + BLDC Synchronization
```bash
# Start BLDC motor
python3 klipper_interface.py -g "BLDC_START RPM=500"

# Move traverse while motor running
python3 klipper_interface.py -g "G91"
python3 klipper_interface.py -g "G1 Y10 F10"  # Slow traverse

# Stop motor
python3 klipper_interface.py -g "BLDC_STOP"
```

**Expected:**
- Both systems work simultaneously
- No interference
- Smooth operation

#### 5.2 Winder Control Module Test
```bash
# Start full winding operation
python3 klipper_interface.py -g "WINDER_START RPM=1000 LAYERS=1"

# Monitor status
python3 klipper_interface.py -g "QUERY_WINDER"

# Stop winding
python3 klipper_interface.py -g "WINDER_STOP"
```

**Expected:**
- BLDC motor starts
- Traverse moves in sync
- Sensors report correctly
- All modules coordinate

#### 5.3 Sensor Fusion Test
```bash
# Query all sensors simultaneously
python3 klipper_interface.py --query winder_control,bldc_motor,angle_sensor,spindle_hall,traverse
```

**Expected:**
- All sensors report
- Values are consistent
- No conflicts

---

## Test Execution Order

### Phase 1: Individual Components (Do First)
1. ✅ Traverse Stepper
   - [ ] TMC2209 communication
   - [ ] Endstop functionality
   - [ ] Homing
   - [ ] Movement

2. ✅ BLDC Motor
   - [ ] Pin control
   - [ ] PWM output
   - [ ] Motor startup
   - [ ] RPM control

3. ✅ Angle Sensor
   - [ ] ADC reading
   - [ ] Rotation detection
   - [ ] Calibration

4. ✅ Hall Sensor
   - [ ] Pulse detection
   - [ ] RPM calculation

### Phase 2: Integration (After Individual Tests Pass)
5. ✅ Traverse + BLDC
6. ✅ All Sensors Together
7. ✅ Winder Control Module
8. ✅ Full Winding Operation

---

## Test Scripts Summary

| Component | Test Script | Purpose |
|-----------|-------------|---------|
| **Traverse** | `test_home_and_move.sh` | Basic homing/movement |
| **Traverse** | `diagnose_tmc2209.py` | TMC2209 communication |
| **Traverse** | `check_endstop.sh` | Endstop functionality |
| **BLDC** | `test_pins_simple.py` | Pin control |
| **BLDC** | `direct_hardware_test.py` | Direct MCU control |
| **Angle Sensor** | `QUERY_ANGLE_SENSOR` | Sensor reading |
| **Hall Sensor** | `QUERY_SPINDLE_HALL` | Hall sensor reading |
| **Integration** | `test_winder.py` | Full system test |

---

## Quick Test Commands

### Check Everything is Working
```bash
# 1. Check Klipper is running
sudo systemctl status klipper

# 2. Check API socket exists
ls -l /tmp/klippy_uds

# 3. Test connection
python3 klipper_interface.py --info

# 4. Query all winder objects
python3 klipper_interface.py --query winder_control,bldc_motor,angle_sensor,spindle_hall,traverse
```

### Test Traverse
```bash
# Home traverse
python3 klipper_interface.py -g "G28 Y"

# Move 10mm
python3 klipper_interface.py -g "G91"
python3 klipper_interface.py -g "G1 Y10 F100"
```

### Test BLDC Motor
```bash
# Start motor at 500 RPM
python3 klipper_interface.py -g "BLDC_START RPM=500"

# Check status
python3 klipper_interface.py -g "QUERY_BLDC"

# Stop motor
python3 klipper_interface.py -g "BLDC_STOP"
```

### Test Sensors
```bash
# Angle sensor
python3 klipper_interface.py -g "QUERY_ANGLE_SENSOR"

# Hall sensor
python3 klipper_interface.py -g "QUERY_SPINDLE_HALL"

# All together
python3 klipper_interface.py --query angle_sensor,spindle_hall
```

---

## Troubleshooting Guide

### Traverse Not Moving
1. Check TMC2209 communication: `python3 scripts/diagnose_tmc2209.py`
2. Check endstop: `python3 scripts/check_endstop.sh`
3. Check stepper enable: `python3 klipper_interface.py -g "SET_STEPPER_ENABLE STEPPER=stepper_y ENABLE=1"`
4. Check logs: `tail -50 /tmp/klippy.log`

### BLDC Motor Not Starting
1. Check power pin: `python3 klipper_interface.py -g "SET_PIN PIN=bldc_motor_power VALUE=1"`
2. Check PWM pin: `python3 klipper_interface.py -g "SET_PIN PIN=bldc_motor_pwm VALUE=0.1"`
3. Check brake: `python3 klipper_interface.py -g "SET_PIN PIN=bldc_motor_brake VALUE=0"`
4. Check BLDC module status: `python3 klipper_interface.py -g "QUERY_BLDC"`

### Sensors Not Reading
1. Check ADC: `python3 klipper_interface.py --query query_adc`
2. Check pin configuration in `printer.cfg`
3. Check voltage levels (multimeter)
4. Check calibration: `python3 klipper_interface.py -g "QUERY_ANGLE_SENSOR"`

---

## Next Steps

1. **Run Phase 1 tests** (individual components)
2. **Fix any issues** found
3. **Run Phase 2 tests** (integration)
4. **Document results** in test log
5. **Proceed to GUI** once hardware is verified

---

## Test Results Log

Create a test log file to track results:

```bash
# Create test log
cat > ~/hardware_test_log.txt <<EOF
Hardware Testing Log
Date: $(date)
Board: Manta M4P
MCU: STM32G0B1RE

=== Traverse Stepper ===
TMC2209 Communication: [ ]
Endstop: [ ]
Homing: [ ]
Movement: [ ]

=== BLDC Motor ===
Pin Control: [ ]
PWM Output: [ ]
Motor Startup: [ ]
RPM Control: [ ]

=== Angle Sensor ===
ADC Reading: [ ]
Rotation Detection: [ ]
Calibration: [ ]

=== Hall Sensor ===
Pulse Detection: [ ]
RPM Calculation: [ ]

=== Integration ===
Traverse + BLDC: [ ]
All Sensors: [ ]
Winder Control: [ ]
EOF
```

