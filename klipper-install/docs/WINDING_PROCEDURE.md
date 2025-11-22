# Winding Procedure Implementation

## Overview

This document describes the implementation of the automated winding procedure for guitar pickup coils.

## Winding Process Flow

```
1. Setup Phase
   ├── Select bobbin type
   ├── Select wire gauge
   ├── Set turn count target
   ├── Affix bobbin
   └── Connect leads

2. Homing Phase
   ├── Home traverse (Y-axis)
   ├── Calculate start position
   └── Move to start position

3. Winding Phase
   ├── Start spindle (ramp up)
   ├── Start traverse motion
   ├── Sync traverse to spindle
   ├── Count turns
   └── Layer wire bidirectionally

4. Completion Phase
   ├── Stop spindle
   ├── Disable steppers
   ├── Display info
   └── Reset for next job
```

## Implementation Status

### ✅ Completed Modules
- [x] BLDC motor control (`bldc_motor.py`)
- [x] Angle sensor (`angle_sensor.py`)
- [x] Hall sensor (`spindle_hall.py`)
- [x] Traverse control (`traverse.py`)
- [x] Winder coordinator (`winder_control.py`)

### ⏳ TODO: Winding Procedure

#### High Priority
- [ ] **G-code Parsing:** Parse G-code sequence for winding process
- [ ] **Turn Counting:** Implement turn counting using Hall sensor
- [ ] **Traverse Sync:** Implement real-time traverse sync to spindle RPM
- [ ] **Wire Layering:** Implement bidirectional wire layering algorithm
- [ ] **Bobbin Type Selection:** Support different bobbin types
- [ ] **Start Position Calculation:** Calculate start position from offsets

#### Medium Priority
- [ ] **Ramp Up/Down:** Implement smooth spindle ramp up/down
- [ ] **Layer Tracking:** Track current layer number
- [ ] **Turn Count Display:** Real-time turn count display
- [ ] **Completion Detection:** Detect when target turn count reached
- [ ] **Error Handling:** Handle wire breaks, motor faults, etc.

#### Low Priority
- [ ] **GUI Integration:** Integrate with 5" touch screen
- [ ] **Calibration Routines:** Automated calibration
- [ ] **Load Sensor:** Future enhancement for wire break detection

## G-code Commands

### Current Commands

#### Winder Control
- `WINDER_START RPM=<rpm> LAYERS=<layers> DIRECTION=<forward|reverse>`
- `WINDER_STOP`
- `WINDER_SET_RPM RPM=<rpm>`
- `WINDER_SET_LAYER LAYER=<layer>`
- `QUERY_WINDER`

#### BLDC Motor
- `BLDC_START RPM=<rpm> DIRECTION=<forward|reverse>`
- `BLDC_STOP`
- `BLDC_SET_RPM RPM=<rpm>`
- `BLDC_SET_DIR DIRECTION=<forward|reverse>`
- `BLDC_SET_BRAKE ENGAGE=<0|1>`
- `BLDC_SET_POWER ENABLE=<0|1>`
- `QUERY_BLDC`

#### Sensors
- `QUERY_ANGLE_SENSOR`
- `ANGLE_SENSOR_CALIBRATE ACTION=<RESET|MANUAL> MIN=<min> MAX=<max>`
- `QUERY_SPINDLE_HALL`

#### Traverse
- `TRAVERSE_MOVE POSITION=<pos> SPEED=<speed>`
- `TRAVERSE_HOME`
- `QUERY_TRAVERSE`

### Proposed New Commands

#### Winding Procedure
- `WINDER_SETUP BOBBIN_TYPE=<type> WIRE_GAUGE=<gauge> TURNS=<turns>`
- `WINDER_START_WINDING`
- `WINDER_PAUSE`
- `WINDER_RESUME`
- `WINDER_ABORT`
- `QUERY_WINDING_STATUS`

#### Bobbin Types
- `BOBBIN_TYPE SINGLE_COIL`
- `BOBBIN_TYPE HUMBUCKER`
- `BOBBIN_TYPE P90`
- `BOBBIN_TYPE RAIL`
- `BOBBIN_TYPE CUSTOM WIDTH=<width> EDGE=<edge>`

## Winding Algorithm

### Phase 1: Setup

```python
def setup_winding(bobbin_type, wire_gauge, target_turns):
    # 1. Select bobbin type
    bobbin_config = get_bobbin_config(bobbin_type)
    
    # 2. Set wire gauge
    wire_diameter = get_wire_diameter(wire_gauge)  # 43 AWG = 0.056mm
    
    # 3. Set turn count target
    target_turns = validate_turn_count(target_turns)  # 2,500-10,000
    
    # 4. Calculate winding parameters
    bobbin_width = bobbin_config['width']
    start_offset = bobbin_config['edge_thickness'] + carriage_offset
    
    return {
        'bobbin_type': bobbin_type,
        'wire_diameter': wire_diameter,
        'target_turns': target_turns,
        'bobbin_width': bobbin_width,
        'start_offset': start_offset
    }
```

### Phase 2: Homing

```python
def home_and_position(start_offset):
    # 1. Home traverse axis
    traverse.home()
    
    # 2. Calculate start position
    start_position = start_offset + bobbin_edge_thickness + carriage_to_guide_offset
    
    # 3. Move to start position
    traverse.move_to(start_position)
    
    return start_position
```

### Phase 3: Winding

```python
def start_winding(spindle_rpm, target_turns):
    # 1. Start spindle (ramp up)
    bldc_motor.start_motor(rpm=motor_rpm, forward=True)
    
    # 2. Calculate traverse speed
    traverse_speed = calculate_traverse_speed(spindle_rpm, wire_diameter)
    
    # 3. Start traverse motion
    start_y = spindle_edge_offset
    end_y = start_y + bobbin_width
    
    # 4. Begin layering
    current_turns = 0
    layer = 0
    
    while current_turns < target_turns:
        # Move forward
        traverse.move_to(end_y, speed=traverse_speed)
        
        # Count turns during movement
        turns_during_move = count_turns_during_move()
        current_turns += turns_during_move
        
        # Move backward
        traverse.move_to(start_y, speed=traverse_speed)
        
        # Count turns during movement
        turns_during_move = count_turns_during_move()
        current_turns += turns_during_move
        
        layer += 1
        
        # Check if target reached
        if current_turns >= target_turns:
            break
    
    # 5. Stop winding
    stop_winding()
```

### Phase 4: Turn Counting

```python
def count_turns_during_move():
    """Count turns using Hall sensor during traverse movement"""
    start_count = spindle_hall.get_count()
    
    # Wait for movement to complete
    toolhead.wait_moves()
    
    end_count = spindle_hall.get_count()
    turns = end_count - start_count
    
    return turns
```

### Phase 5: Traverse Sync

```python
def sync_traverse_to_spindle():
    """Real-time sync traverse speed to measured spindle RPM"""
    # Get measured RPM (blended from Hall + Angle sensors)
    measured_rpm = winder_control.get_spindle_rpm()
    
    # Calculate required traverse speed
    required_speed = calculate_traverse_speed(measured_rpm, wire_diameter)
    
    # Update traverse max_velocity
    toolhead.set_max_velocities(required_speed * 1.1, None, None, None)
    
    # Use this speed for next manual_move()
    return required_speed
```

## Bobbin Types

### Single Coil
- **Typical Turns:** 5,000-8,000
- **Bobbin Width:** 12mm
- **Wire:** 43 AWG

### Humbucker
- **Typical Turns:** 5,000-7,000 per coil
- **Bobbin Width:** 12mm
- **Wire:** 43 AWG
- **Note:** Two coils wound separately

### P90
- **Typical Turns:** 10,000+
- **Bobbin Width:** Variable
- **Wire:** 43 AWG

### Rail
- **Typical Turns:** Variable
- **Bobbin Width:** Variable
- **Wire:** 43 AWG

### Custom
- **Turns:** User-defined
- **Bobbin Width:** User-defined
- **Wire:** User-selected gauge

## Error Handling

### Wire Break Detection
- **Future:** Load sensor integration
- **Current:** Manual detection required

### Motor Faults
- **Overcurrent:** TMC2209 stall detection
- **Overheating:** Motor temperature monitoring
- **Communication Loss:** MCU timeout detection

### Traverse Errors
- **Endstop Fault:** Home switch failure
- **Position Error:** Stepper position drift
- **Sync Error:** Traverse speed mismatch

## Calibration

### Angle Sensor Calibration
- **Auto-calibration:** Enabled by default
- **Manual calibration:** `ANGLE_SENSOR_CALIBRATE ACTION=MANUAL MIN=<min> MAX=<max>`
- **Reset calibration:** `ANGLE_SENSOR_CALIBRATE ACTION=RESET`

### Traverse Calibration
- **Home offset:** Measured per installation
- **Start position:** Calculated from offsets
- **Bobbin edge:** Measured per bobbin

### Turn Count Calibration
- **Hall sensor:** 1 pulse = 1 revolution (verified)
- **Angle sensor:** 4096 steps = 1 revolution (for position tracking)

## Testing Procedure

### 1. Individual Module Testing
```gcode
# Test BLDC motor
BLDC_START RPM=100
QUERY_BLDC
BLDC_STOP

# Test angle sensor
QUERY_ANGLE_SENSOR
ANGLE_SENSOR_CALIBRATE ACTION=RESET

# Test Hall sensor
QUERY_SPINDLE_HALL

# Test traverse
TRAVERSE_HOME
TRAVERSE_MOVE POSITION=50 SPEED=10
QUERY_TRAVERSE
```

### 2. Integration Testing
```gcode
# Test winder coordinator
WINDER_START RPM=1000 LAYERS=1
QUERY_WINDER
WINDER_STOP
```

### 3. Full Winding Test
```gcode
# Setup
WINDER_SETUP BOBBIN_TYPE=SINGLE_COIL WIRE_GAUGE=43AWG TURNS=5000

# Start winding
WINDER_START_WINDING

# Monitor progress
QUERY_WINDING_STATUS

# Complete or abort
WINDER_STOP
```

## Future Enhancements

### Load Sensor Integration
- Detect wire breaks
- Monitor wire tension
- Prevent overwinding

### Advanced Layering
- Variable layer patterns
- Custom winding patterns
- Multi-coil winding

### GUI Integration
- Touch screen interface
- Real-time status display
- Winding progress visualization
- Bobbin type selection
- Turn count input

## References

- `PROJECT_SCOPE.md` - Complete project scope
- `HARDWARE_SPECIFICATIONS.md` - Hardware details
- `MODULAR_ARCHITECTURE_SUMMARY.md` - Module architecture
- `BLDC_MOTOR_MODULE.md` - BLDC motor documentation

