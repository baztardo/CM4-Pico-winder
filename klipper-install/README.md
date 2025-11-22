# CNC Automated Guitar Pickup Winder

Automated CNC guitar pickup winder using Klipper firmware on Manta M4P control board with CM4 host.

## Project Overview

This project implements a complete automated winding system for guitar pickup coils, supporting various bobbin types (single coil, humbucker, P90, Rail, Custom) with turn counts ranging from 2,500 to 10,000 turns.

### Key Features

- **BLDC Motor Control:** Variable speed control with PWM, direction, and brake
- **Precise RPM Tracking:** Dual sensor system (Hall + Angle) for accurate RPM measurement
- **Traverse Sync:** Real-time synchronization of traverse speed to spindle RPM
- **Turn Counting:** Accurate turn counting using Hall sensor (1 pulse = 1 revolution)
- **Wire Layering:** Automated bidirectional wire layering on bobbin
- **Modular Architecture:** Clean, maintainable code structure

## Quick Start

### Installation

```bash
# On CM4
cd ~
git clone <repo-url> klipper-install
cd klipper-install
./SETUP_CM4_COMPLETE.sh --mcu=auto
```

### Configuration

Copy the example config:
```bash
cp config/printer-manta-m4p-winder.cfg ~/printer.cfg
```

Edit `printer.cfg` with your specific hardware settings.

### Basic Usage

```gcode
# Home traverse
G28 Y

# Start winding
WINDER_START RPM=1000 LAYERS=5

# Query status
QUERY_WINDER

# Stop winding
WINDER_STOP
```

## Hardware

- **Control Board:** Manta M4P (STM32G0B0RE MCU)
- **Host:** CM4 (Compute Module 4)
- **BLDC Motor:** Nema 17, 3-phase 24V, 8 poles
- **Gear Ratio:** 40:60 (motor:spindle) = 0.667
- **Hall Sensor:** NPN NO, 1 pulse/revolution
- **Angle Sensor:** P3022-V1-CW360, 0-5V analog, 12-bit
- **Traverse:** Nema 11 stepper, TMC2209 driver
- **Wire:** 43 AWG copper (0.056mm diameter)

See [HARDWARE_SPECIFICATIONS.md](docs/HARDWARE_SPECIFICATIONS.md) for complete details.

## Software Architecture

### Module Structure

```
klippy/
├── kinematics/
│   └── winder.py              # Movement/homing
│
└── extras/
    ├── bldc_motor.py          # BLDC motor control
    ├── angle_sensor.py         # ADC angle sensor
    ├── spindle_hall.py         # Hall sensor RPM
    ├── traverse.py             # Traverse control
    └── winder_control.py      # Main coordinator
```

### Module Responsibilities

- **`bldc_motor.py`** - Motor speed, direction, brake, power control
- **`angle_sensor.py`** - Angle position tracking, saturation handling
- **`spindle_hall.py`** - RPM measurement, turn counting
- **`traverse.py`** - Traverse stepper coordination
- **`winder_control.py`** - Coordinates all modules, high-level operations

See [MODULAR_ARCHITECTURE_SUMMARY.md](docs/MODULAR_ARCHITECTURE_SUMMARY.md) for details.

## Documentation

### Project Documentation
- **[PROJECT_SCOPE.md](docs/PROJECT_SCOPE.md)** - Complete project scope and requirements
- **[HARDWARE_SPECIFICATIONS.md](docs/HARDWARE_SPECIFICATIONS.md)** - Detailed hardware specs
- **[WINDING_PROCEDURE.md](docs/WINDING_PROCEDURE.md)** - Winding procedure implementation

### Architecture Documentation
- **[MODULAR_ARCHITECTURE_SUMMARY.md](docs/MODULAR_ARCHITECTURE_SUMMARY.md)** - Module architecture overview
- **[WINDER_ARCHITECTURE_PROPOSAL.md](docs/WINDER_ARCHITECTURE_PROPOSAL.md)** - Architecture design decisions
- **[KLIPPER_CONFIG_SYSTEM.md](docs/KLIPPER_CONFIG_SYSTEM.md)** - How Klipper config system works

### Module Documentation
- **[BLDC_MOTOR_MODULE.md](docs/BLDC_MOTOR_MODULE.md)** - BLDC motor module guide
- **[CREATING_CUSTOM_MODULES.md](docs/CREATING_CUSTOM_MODULES.md)** - How to create custom modules
- **[MODULE_QUICK_REFERENCE.md](docs/MODULE_QUICK_REFERENCE.md)** - Quick reference for module development

### Installation Documentation
- **[QUICK_START.md](dev/QUICK_START.md)** - Quick start guide
- **[INSTALL_GUIDE.md](dev/INSTALL_GUIDE.md)** - Detailed installation guide
- **[DEVELOPMENT.md](dev/DEVELOPMENT.md)** - Development setup

## Configuration Files

### Example Configs
- **`config/printer-manta-m4p-winder.cfg`** - Complete M4P winder configuration
- **`config/bldc_motor_example.cfg`** - BLDC motor configuration example

### Pin Assignments (M4P)

#### BLDC Motor (E0 Header)
- PWM: PB3 (E0 STEP)
- DIR: PB4 (E0 DIR)
- Brake: PD5 (E0 ENA)
- Power: PB7 (Bed heater port)

#### Sensors
- Angle Sensor: PA1 (BLTouch SERVOS port)
- Hall Sensor: PC15 (Spindle Hall - M4P pin)

#### Traverse (Y-Axis)
- Step: PF12
- Dir: PF11
- Enable: PB3 (inverted)
- Endstop: PF3
- TMC2209 UART: PF13

## G-code Commands

### Winder Control
- `WINDER_START RPM=<rpm> LAYERS=<layers> DIRECTION=<forward|reverse>`
- `WINDER_STOP`
- `WINDER_SET_RPM RPM=<rpm>`
- `QUERY_WINDER`

### BLDC Motor
- `BLDC_START RPM=<rpm> DIRECTION=<forward|reverse>`
- `BLDC_STOP`
- `BLDC_SET_RPM RPM=<rpm>`
- `BLDC_SET_DIR DIRECTION=<forward|reverse>`
- `BLDC_SET_BRAKE ENGAGE=<0|1>`
- `QUERY_BLDC`

### Sensors
- `QUERY_ANGLE_SENSOR`
- `ANGLE_SENSOR_CALIBRATE ACTION=<RESET|MANUAL> MIN=<min> MAX=<max>`
- `QUERY_SPINDLE_HALL`

### Traverse
- `TRAVERSE_MOVE POSITION=<pos> SPEED=<speed>`
- `TRAVERSE_HOME`
- `QUERY_TRAVERSE`

## Winding Process

### Supported Bobbin Types
- Single coil
- Humbucker
- P90
- Rail
- Custom

### Turn Count Range
- **Range:** 2,500 to 10,000 turns
- **Typical:**
  - Single coil: 5,000-8,000
  - Humbucker: 5,000-7,000 per coil
  - P90: 10,000+

### Winding Procedure

1. **Setup:** Select bobbin type, wire gauge, turn count
2. **Homing:** Home traverse, move to start position
3. **Winding:** Start spindle, sync traverse, count turns
4. **Completion:** Stop motor, disable steppers, display info

See [WINDING_PROCEDURE.md](docs/WINDING_PROCEDURE.md) for implementation details.

## Development

### Module Development
See [CREATING_CUSTOM_MODULES.md](docs/CREATING_CUSTOM_MODULES.md) for how to create custom modules.

### Testing
```bash
# Test individual modules
python3 ~/klipper/scripts/klipper_interface.py -g "QUERY_BLDC"
python3 ~/klipper/scripts/klipper_interface.py -g "QUERY_ANGLE_SENSOR"
python3 ~/klipper/scripts/klipper_interface.py -g "QUERY_SPINDLE_HALL"

# Test coordinator
python3 ~/klipper/scripts/klipper_interface.py -g "QUERY_WINDER"
```

### File Sync
```bash
# Sync to CM4
./scripts/sync_cm4_files.sh winder@winder.local push

# Sync from CM4
./scripts/sync_cm4_files.sh winder@winder.local pull
```

## Status

### ✅ Completed
- Modular architecture
- BLDC motor control
- Angle sensor handling
- Hall sensor handling
- Traverse control
- Winder coordinator

### ⏳ In Progress
- G-code parsing for winding process
- Turn counting implementation
- Traverse sync algorithm
- Wire layering algorithm

### 🔮 Future
- GUI integration (5" touch screen)
- Load sensor integration
- Advanced layering patterns

## License

This project uses Klipper firmware, licensed under GPLv3.

## References

- [Klipper Documentation](https://www.klipper3d.org/)
- [Manta M4P Manual](docs/BIGTREETECH_MANTA_M4P_User_Manual-2.pdf)
- [Manta M4P Schematic](docs/BIGTREETECH_Manta_M4P_V2.1_220608%20PINOUT.pdf)
