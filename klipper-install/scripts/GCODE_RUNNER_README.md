# G-code Runner for Klipper Winder

## Overview

The G-code runner allows you to execute winding sequences from G-code files, enabling:
- **Automated production workflows**
- **Repeatable winding sequences**
- **Test scripts for system verification**
- **Progress tracking and error handling**

## Features

- ✅ Line-by-line G-code parsing and execution
- ✅ Comment handling (`;` prefix and inline)
- ✅ Progress tracking with callbacks
- ✅ Error handling with pause-on-error
- ✅ Dry-run mode for testing
- ✅ Automatic winding sequence generation
- ✅ Production-ready logging

## Installation

```bash
# Copy files to CM4
scp ~/Documents/GitHub/CM4-Pico-winder/klipper-install/scripts/gcode_runner.py winder@winder.local:~/
scp -r ~/Documents/GitHub/CM4-Pico-winder/klipper-install/scripts/examples winder@winder.local:~/

# Make executable
ssh winder@winder.local "chmod +x ~/gcode_runner.py"
```

## Usage

### Execute a G-code File

```bash
# Run a G-code file
python3 ~/gcode_runner.py ~/examples/test_sequence.gcode

# Dry run (parse but don't execute)
python3 ~/gcode_runner.py ~/examples/test_sequence.gcode --dry-run

# Continue on errors (don't pause)
python3 ~/gcode_runner.py ~/examples/production_humbucker.gcode --no-pause-on-error
```

### Generate and Run Winding Sequence

```bash
# Quick winding sequence
python3 ~/gcode_runner.py --winding --rpm 300 --layers 10

# Production winding (skip homing if already homed)
python3 ~/gcode_runner.py --winding --rpm 400 --layers 57 --no-home

# Fast winding (skip calibration)
python3 ~/gcode_runner.py --winding --rpm 500 --layers 20 --no-calibrate
```

## G-code File Format

### Basic Structure

```gcode
; Comment lines start with semicolon
; Empty lines are ignored

; Home and calibrate
HOME_TRAVERSE

; Start winding
WINDER_START RPM=300 LAYERS=10

; Display message
M117 Winding complete
```

### Supported Commands

All standard Klipper G-code commands are supported, including:

#### Winder-Specific Commands
- `HOME_TRAVERSE` - Home traverse and calibrate spindle
- `WINDER_START RPM=<rpm> LAYERS=<layers>` - Start winding
- `WINDER_STOP` - Stop winding
- `BLDC_START RPM=<rpm>` - Start spindle motor
- `BLDC_STOP` - Stop spindle motor

#### Query Commands
- `QUERY_ANGLE_SENSOR` - Get angle sensor status
- `QUERY_HW_COUNTER` - Get hall counter status
- `CALIBRATE_ANGLE_SENSOR ACTION=<START|STOP>` - Calibration mode

#### Standard G-code
- `G28 Y` - Home Y axis (traverse)
- `G1 Y<pos> F<speed>` - Move traverse
- `M117 <message>` - Display message
- `G4 P<ms>` - Dwell (pause)

### Comment Styles

```gcode
; Full line comment

G28 Y  ; Inline comment after command

; Multi-line comments
; can span multiple lines
; like this
```

## Example Files

### Test Sequence (`examples/test_sequence.gcode`)

Simple test to verify system operation:
- Homes and calibrates
- Queries sensor status
- Runs 1 layer at low speed

```bash
python3 ~/gcode_runner.py ~/examples/test_sequence.gcode
```

### Production Humbucker (`examples/production_humbucker.gcode`)

Complete production sequence for 5000-turn humbucker:
- Full setup and calibration
- 57 layers at 300 RPM
- Status queries and completion messages

```bash
python3 ~/gcode_runner.py ~/examples/production_humbucker.gcode
```

## Creating Custom G-code Files

### Template for Production Winding

```gcode
; ========================================
; PRODUCTION WINDING SEQUENCE
; ========================================
; Product: <product_name>
; Wire: <wire_spec>
; Target turns: <total_turns>
; Date: <date>

; Setup
M117 Initializing...
HOME_TRAVERSE

; Winding
M117 Winding <layers> layers...
WINDER_START RPM=<rpm> LAYERS=<layers>

; Complete
M117 Production complete
```

### Calculating Layers

```python
# Formula:
# turns_per_layer = bobbin_width / (wire_diameter + coating)
# layers_needed = total_turns / turns_per_layer

# Example for 43 AWG on 6.35mm bobbin:
bobbin_width = 6.35  # mm
wire_diameter = 0.056  # mm bare
coating = 0.016  # mm (single build)
total_wire = wire_diameter + coating  # 0.072mm

turns_per_layer = bobbin_width / total_wire  # 88.2 turns
layers_for_5000 = 5000 / turns_per_layer  # 56.7 layers (round up to 57)
```

## Progress Tracking

The runner provides real-time progress updates:

```
[1] HOME_TRAVERSE
[2] QUERY_ANGLE_SENSOR
[3] WINDER_START RPM=300 LAYERS=10
Progress: 10/15 (66.7%)
[15] M117 Complete

============================================================
EXECUTION COMPLETE
============================================================
File: /tmp/winding_1234567890.gcode
Commands executed: 15/15
Errors: 0
Duration: 45.3s
Status: SUCCESS
============================================================
```

## Error Handling

### Pause on Error (Default)

When an error occurs, execution pauses:

```
Error on line 5: WINDER_START RPM=9999 LAYERS=10
Error: RPM too high (max: 3300.0)
Paused. Type 'resume' to continue, 'abort' to stop.
```

### Continue on Error

Use `--no-pause-on-error` to continue execution despite errors:

```bash
python3 ~/gcode_runner.py file.gcode --no-pause-on-error
```

## Python API

### Basic Usage

```python
from klipper_interface import KlipperInterface
from gcode_runner import GCodeRunner

# Connect
klipper = KlipperInterface()
klipper.connect()

# Create runner
runner = GCodeRunner(klipper)

# Execute file
stats = runner.execute_file("winding.gcode")
print(f"Success: {stats['success']}")
print(f"Executed: {stats['executed']} commands")
```

### With Callbacks

```python
def on_line(line_num, cmd):
    print(f"Executing line {line_num}: {cmd}")

def on_progress(executed, total, pct):
    print(f"Progress: {pct:.1f}%")

def on_error(cmd, error):
    print(f"ERROR: {cmd} - {error}")

def on_complete(stats):
    print(f"Complete! Duration: {stats['duration']:.1f}s")

runner.on_line_execute = on_line
runner.on_progress = on_progress
runner.on_error = on_error
runner.on_complete = on_complete

runner.execute_file("winding.gcode")
```

### Winding Sequence Generator

```python
from gcode_runner import WindingSequence

sequence = WindingSequence(klipper)

# Generate and execute
stats = sequence.run_winding_sequence(
    rpm=300,
    layers=10,
    home_first=True,
    calibrate=True
)
```

## Best Practices

### 1. Always Home and Calibrate

```gcode
; Start every sequence with homing
HOME_TRAVERSE
```

### 2. Add Status Queries

```gcode
; Query before winding
QUERY_ANGLE_SENSOR
QUERY_HW_COUNTER

; Wind
WINDER_START RPM=300 LAYERS=10

; Query after winding
QUERY_ANGLE_SENSOR
QUERY_HW_COUNTER
```

### 3. Use Comments Liberally

```gcode
; ========================================
; SECTION: Setup
; ========================================
; This section homes and calibrates

HOME_TRAVERSE  ; Home Y and calibrate spindle
```

### 4. Test with Dry Run

```bash
# Always test new sequences with --dry-run first
python3 ~/gcode_runner.py new_sequence.gcode --dry-run
```

### 5. Monitor Progress

```bash
# Watch the log in another terminal
tail -f /tmp/klippy.log | grep -E "WINDER|Turn complete|Hall"
```

## Troubleshooting

### "Could not connect to Klipper"

```bash
# Check if Klipper is running
ps aux | grep klippy.py

# Check UDS path
ls -la /tmp/klippy_uds

# Restart Klipper if needed
sudo service klipper restart
```

### "Command failed" errors

Check the Klipper log for details:

```bash
tail -100 /tmp/klippy.log
```

### Execution hangs

The winder might be waiting for a long operation (like winding many layers). Check status:

```bash
# In another terminal
python3 ~/klipper_interface.py -g "QUERY_ANGLE_SENSOR"
```

## Advanced Features

### Conditional Execution

```python
# Execute only if conditions are met
runner = GCodeRunner(klipper)

# Check status before running
status = klipper.query_objects({"toolhead": None})
if status and status.get("toolhead", {}).get("status") == "Ready":
    runner.execute_file("winding.gcode")
else:
    print("System not ready!")
```

### Batch Processing

```python
# Run multiple files in sequence
files = [
    "setup.gcode",
    "winding_coil1.gcode",
    "winding_coil2.gcode",
    "cleanup.gcode"
]

for gcode_file in files:
    print(f"Running {gcode_file}...")
    stats = runner.execute_file(gcode_file)
    if not stats['success']:
        print(f"Failed on {gcode_file}")
        break
```

## Related Documentation

- [Klipper Interface README](./klipper_interface.py) - Low-level API
- [Angle Sensor Calibration](../../ANGLE_SENSOR_CALIBRATION.md) - Sensor setup
- [Winder Control](../extras/winder_control.py) - Winding logic

## Support

For issues or questions:
1. Check `/tmp/klippy.log` for errors
2. Run with `--dry-run` to test parsing
3. Verify sensor calibration with `~/verify_calibration.sh`

