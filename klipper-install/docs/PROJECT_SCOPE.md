# CNC Automated Guitar Pickup Winder - Project Scope

## Overview

Automated CNC guitar pickup winder using Klipper firmware on Manta M4P control board with CM4 host.

## Hardware Specifications

### Spindle System

#### BLDC Motor
- **Type:** Nema 17 size, 3-phase, 24V
- **Poles:** 8
- **Control Interface:**
  - **SC:** Speed pulse output interface
  - **P (PWM):** 2.5-5V, Frequency: 1kHz-20kHz
  - **DIR:** Active when LOW level
  - **BRAKE:** Active HIGH
- **Gear Ratio:** 40:60 (motor:spindle)
  - Motor: 40T timing gear
  - Spindle: 60T timing gear
  - Belt: 6mm x 300mm

#### Hall Sensor (Spindle RPM Tracking)
- **Type:** Magnetic Hall Effect proximity sensor, NPN NO
- **Voltage:** 5-30VDC
- **Effective Distance:** 0-10mm
- **Function:** Track rotation revolution for RPM and turn counts
- **Output:** 1 pulse per revolution

#### Angle Sensor (P3022-V1-CW360)
- **Rotation:** 360°
- **Power:** 5VDC @ 16mA
- **Resolution:** 360°/4096 ≈ 0.088° per step
- **Update Speed:** ~0.6ms
- **Output Signal:** Analog 0-5V (12-bit ADC)
- **Load Resistance:** >10kΩ
- **Gear Ratio:** 20T:20T (1:1 ratio to spindle)
- **Belt:** 6mm x 200mm
- **Function:**
  - Track location of spindle
  - Used for traverse sync
  - Track length of copper wire wound
  - Calibrate length of wire per turn
  - Can be used with Hall sensor for precise position tracking

### Traverse Carriage

#### Carriage
- **Size:** 32mm x 32mm
- **Function:** Guide copper wire onto bobbin
- **Wire:** 43 AWG copper wire (coated)
- **Bobbin Width:** Average 12mm wide
- **Homing:** Must home to 0 location, then move to start position
  - Start position = (start offset + bobbin edge thickness + carriage edge to wire guide)

#### Stepper Motor
- **Type:** Nema 11
- **Holding Torque:** 6N·cm
- **Current:** 0.6A
- **Resistance:** 5.5Ω
- **Inductance:** 3.2mH
- **Speed Range:** 0-120mm/s
- **Step Angle:** 1.8°

#### Linear Slide
- **Lead Screw:** 6mm diameter, 1.0mm pitch
- **Travel:** 102mm
- **Function:** Linear movement for wire layering
- **Sync Requirement:** Must sync to spindle rotation for proper layering

### Control Board

#### Manta M4P
- **Power Supply:** 24V
- **Host:** CM4 (Compute Module 4)
- **MCU:** STM32G0B0RE, 32-bit ARM Cortex-M0+ @ 64MHz

#### Pin Assignments
- **Traverse Carriage [Axis-Y]:**
  - Home Switch: Y-Stop
  - Driver: TMC2209
- **BLDC Motor [Axis-E0]:**
  - Step = PWM
  - Dir = DIR
  - Ena = Brake
- **Angle Sensor [BLTouch Port]:**
  - Pin: PA1
  - GND, 5VCC
- **Display:** 5" Touch Screen (HDMI, SPI, USB)

## Software Architecture

### Klipper Modules

#### Core Modules
- `kinematics/winder.py` - Winder kinematics (Y-axis movement/homing)
- `printer.cfg` - Printer configuration file

#### Control Modules (`extras/`)
- `bldc_motor.py` - BLDC motor control (PWM, DIR, Brake, Power)
- `angle_sensor.py` - ADC angle sensor with saturation handling
- `spindle_hall.py` - Hall sensor for spindle RPM and turn counting
- `traverse.py` - Traverse stepper coordination
- `winder_control.py` - Main coordinator (orchestrates all modules)

#### Installation
- `klipper-install/` - Automated Klipper installation scripts

## Winding Process

### Bobbin Types
- Single coil
- Humbucker
- P90
- Rail
- Custom

### Wire Specifications
- **Primary:** 43 AWG copper wire (coated)
- **Other Options:** Popular gauge choices available

### Turn Count Range
- **Range:** 2,500 to 10,000 turns
- **Selection:** Appropriate to pickup type

### Winding Procedure

1. **Setup:**
   - Select bobbin type
   - Select wire gauge (43 AWG default)
   - Set desired turn count (2,500-10,000)
   - Affix bobbin to turning disc
   - Connect lead wires

2. **Homing:**
   - Home traverse axis (Y-axis)
   - Move to start position:
     - Start offset
     - + Bobbin edge thickness
     - + Carriage edge to wire guide offset

3. **Winding:**
   - Start spindle (ramp up)
   - Begin traverse motion (sync to spindle)
   - Layer wire while counting turns
   - Continue until target turn count reached

4. **Completion:**
   - Stop spindle
   - Disable steppers
   - Display winding info
   - Reset counts
   - Ready for next job

### Future Enhancements
- **Load Sensor:** Track load on copper wire to detect breaks
- **G-code Parsing:** Parse G-code sequence for winding process

## Control Flow

```
User Input (GUI/G-code)
    ↓
[winder_control] - Main Coordinator
    ↓
    ├──→ [bldc_motor] - Motor speed/direction
    ├──→ [spindle_hall] - RPM/turn counting
    ├──→ [angle_sensor] - Position tracking
    └──→ [traverse] - Wire layering sync
```

## Key Requirements

### Traverse Sync
- Traverse speed must sync to spindle RPM
- Formula: `traverse_speed = (spindle_rpm / 60) * wire_diameter`
- Real-time adjustment based on measured RPM

### Turn Counting
- Primary: Hall sensor (1 pulse = 1 revolution)
- Secondary: Angle sensor (for position tracking)
- Blend both sensors for accuracy

### Wire Layering
- Start position: Bobbin edge + offset
- End position: Start + bobbin width (12mm)
- Bidirectional layering (forward/backward)
- Sync to spindle rotation

### Safety
- Emergency stop capability
- Motor brake control
- Power control
- Shutdown handling

## Configuration Example

```cfg
# BLDC Motor (E0 Header)
[bldc_motor]
pwm_pin: PB3      # E0 STEP - PWM
dir_pin: PB4      # E0 DIR - Active LOW
brake_pin: PD5    # E0 ENA - Active HIGH
power_pin: PB7    # Bed heater port
max_rpm: 3000.0   # Motor max RPM
min_rpm: 10.0
pwm_frequency: 1000.0

# Angle Sensor (BLTouch Port)
[angle_sensor]
sensor_pin: PA1   # BLTouch SERVOS port
max_angle: 360.0
saturation_threshold: 0.95
angle_auto_calibrate: True
sensor_vcc: 5.0

# Spindle Hall Sensor
[spindle_hall]
hall_pin: PC15    # Spindle Hall sensor (M4P pin)
pulses_per_revolution: 1
sample_time: 0.01
poll_time: 0.1

# Traverse (Y-Axis)
[traverse]
stepper: stepper_y
max_position: 93.0
home_offset: 2.0

# Winder Control (Main Coordinator)
[winder_control]
bldc_motor: bldc_motor
angle_sensor: angle_sensor
spindle_hall: spindle_hall
traverse: traverse
gear_ratio: 0.667      # 40:60 = 0.667
wire_diameter: 0.056  # 43 AWG = 0.056mm
bobbin_width: 12.0
spindle_edge: 38.0
max_spindle_rpm: 2000.0
min_spindle_rpm: 10.0
```

## TODO

### High Priority
- [ ] Parse G-code sequence for winding process
- [ ] Implement turn counting (Hall sensor + angle sensor blend)
- [ ] Implement traverse sync algorithm
- [ ] Implement wire layering algorithm
- [ ] Bobbin type selection (single coil, humbucker, P90, Rail, Custom)
- [ ] Turn count target (2,500-10,000 range)

### Medium Priority
- [ ] GUI integration (5" touch screen)
- [ ] Winding procedure automation
- [ ] Calibration routines
- [ ] Load sensor integration (future)

### Low Priority
- [ ] Documentation updates
- [ ] Error handling improvements
- [ ] Performance optimization

## Technical Notes

### Gear Ratio Calculation
- Motor: 40T → Spindle: 60T
- Ratio: 40/60 = 0.667 (motor turns faster than spindle)
- Spindle RPM = Motor RPM × 0.667
- Motor RPM = Spindle RPM / 0.667

### Traverse Speed Calculation
- Formula: `traverse_speed (mm/s) = (spindle_rpm / 60) × wire_diameter (mm)`
- Example: 1000 RPM, 0.056mm wire → 0.933 mm/s

### Turn Counting
- Hall sensor: 1 pulse = 1 revolution (primary)
- Angle sensor: 4096 steps = 1 revolution (secondary, for position)
- Blend: Use Hall for counting, Angle for position/sync

### Angle Sensor Saturation
- Sensor outputs 0-5V, but may saturate at high end
- Use Hall sensor to track revolutions during saturation
- Software handles saturation gap automatically

## References

- Manta M4P User Manual
- Manta M4P Schematic
- Klipper Documentation
- Module Documentation:
  - `BLDC_MOTOR_MODULE.md`
  - `CREATING_CUSTOM_MODULES.md`
  - `MODULAR_ARCHITECTURE_SUMMARY.md`
  - `WINDER_ARCHITECTURE_PROPOSAL.md`

