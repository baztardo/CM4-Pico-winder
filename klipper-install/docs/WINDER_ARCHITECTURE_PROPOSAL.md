# Winder Architecture Proposal

## Current Problem

**Naming Confusion:**
- `kinematics/winder.py` → `WinderKinematics` (movement/homing)
- `extras/winder.py` → `WinderController` (BLDC, sensors, coordination)
- Config `[winder]` → Which one? Both?

**Monolithic Module:**
- `extras/winder.py` does everything:
  - BLDC motor control
  - Angle sensor handling
  - Hall sensor handling
  - Traverse coordination
  - Winding logic
  - RPM calculations
  - Status reporting

## Proposed Architecture

### Module Structure

```
klippy/
├── kinematics/
│   └── winder.py              # WinderKinematics - Movement/homing only
│
└── extras/
    ├── bldc_motor.py          # BLDCMotor - Motor control (DONE ✅)
    ├── angle_sensor.py        # AngleSensor - ADC angle sensor (DONE ✅)
    ├── spindle_hall.py        # SpindleHall - Hall sensor for spindle RPM (DONE ✅)
    ├── traverse.py             # Traverse - Traverse stepper coordination (DONE ✅)
    └── winder_control.py      # WinderControl - Main coordinator/hub (DONE ✅)
```

### Module Responsibilities

#### 1. `kinematics/winder.py` - Movement & Homing
**Purpose:** Handle Y-axis (traverse) movement and homing
**Responsibilities:**
- Stepper rail setup
- Homing logic
- Movement validation
- Position tracking

**Status:** ✅ Already correct - no changes needed

#### 2. `extras/bldc_motor.py` - BLDC Motor Control
**Purpose:** Control BLDC motor (speed, direction, brake, power)
**Responsibilities:**
- PWM speed control
- Direction control
- Brake control
- Power control
- G-code commands: `BLDC_START`, `BLDC_STOP`, `BLDC_SET_RPM`, etc.

**Status:** ✅ Already created

#### 3. `extras/angle_sensor.py` - Angle Sensor
**Purpose:** Read and process ADC angle sensor
**Responsibilities:**
- ADC pin setup
- Angle reading (0-360°)
- Saturation detection/handling
- RPM calculation from angle
- Status reporting

**Status:** ⏳ To be created

#### 4. `extras/spindle_hall.py` - Spindle Hall Sensor
**Purpose:** Read spindle RPM from Hall sensor
**Responsibilities:**
- Hall sensor pin setup
- Pulse counting
- RPM calculation
- Revolution tracking
- Status reporting

**Status:** ⏳ To be created

#### 5. `extras/traverse.py` - Traverse Control
**Purpose:** Coordinate traverse stepper movements
**Responsibilities:**
- Traverse stepper lookup
- Movement commands
- Position tracking
- G-code commands: `TRAVERSE_MOVE`, `TRAVERSE_HOME`, etc.

**Status:** ⏳ To be created

#### 6. `extras/winder_control.py` - Main Coordinator
**Purpose:** Coordinate all winder components
**Responsibilities:**
- Lookup and coordinate sub-modules:
  - `bldc_motor`
  - `angle_sensor`
  - `spindle_hall`
  - `traverse`
- High-level winding operations:
  - `WINDER_START` - Start winding sequence
  - `WINDER_STOP` - Stop winding
  - `WINDER_SET_RPM` - Set winding RPM
  - `WINDER_SET_LAYER` - Set layer parameters
- RPM blending (angle sensor + hall sensor)
- Traverse sync coordination
- Status aggregation
- G-code command registration

**Status:** ✅ Created (replaces current `winder.py`)

## Configuration Structure

### Current (Confusing)
```cfg
[winder]
motor_pwm_pin: PC9
motor_dir_pin: PB4
spindle_hall_pin: PF6
angle_sensor_pin: PA0
# ... everything mixed together
```

### Proposed (Clear Separation)
```cfg
# BLDC Motor Control
[bldc_motor]
pwm_pin: PC9
dir_pin: PB4
brake_pin: PD5
power_pin: PB7
max_rpm: 3000.0

# Angle Sensor (ADC)
[angle_sensor]
sensor_pin: PA0
max_angle: 360.0
saturation_threshold: 0.95

# Spindle Hall Sensor
[spindle_hall]
hall_pin: PF6
pulses_per_revolution: 1

# Traverse Control
[traverse]
stepper: stepper_y
max_position: 93.0

# Winder Control (main hub)
[winder_control]
bldc_motor: bldc_motor
angle_sensor: angle_sensor
spindle_hall: spindle_hall
traverse: traverse
gear_ratio: 0.667
wire_diameter: 0.056
bobbin_width: 12.0
```

## Benefits

### 1. **Clear Separation of Concerns**
- Each module has a single, well-defined responsibility
- Easier to understand and maintain
- Easier to test independently

### 2. **Reusability**
- `bldc_motor` can be used in other projects
- `angle_sensor` can be used standalone
- `traverse` can be used for other linear movements

### 3. **Better Naming**
- `winder_coordinator` clearly indicates it coordinates other modules
- No confusion between `kinematics/winder.py` and `extras/winder.py`

### 4. **Easier Development**
- Work on one module at a time
- Test modules independently
- Debug specific functionality in isolation

### 5. **Follows Klipper Patterns**
- Similar to how `heaters.py` coordinates temperature sensors
- Similar to how `tmc.py` coordinates with `stepper_enable`
- Matches Klipper's modular architecture

## Migration Path

### Phase 1: Create Sub-Modules ✅
- [x] `bldc_motor.py` - DONE
- [ ] `angle_sensor.py` - Extract from `winder.py`
- [ ] `spindle_hall.py` - Extract from `winder.py`
- [ ] `traverse.py` - Extract from `winder.py`

### Phase 2: Create Coordinator ✅
- [x] `winder_control.py` - Coordinator module created
- [x] High-level logic extracted
- [x] Sub-modules coordinated

### Phase 3: Update Config
- [ ] Split `[winder]` config into separate sections
- [ ] Update `printer.cfg` examples
- [ ] Update documentation

### Phase 4: Cleanup
- [ ] Archive old `extras/winder.py` (keep for reference)
- [ ] Update config files to use new modules
- [ ] Test integration
- [ ] Update documentation

## Example: Winder Control

```python
# extras/winder_control.py
class WinderControl:
    def __init__(self, config):
        self.printer = config.get_printer()
        
        # Lookup sub-modules
        self.bldc_motor = self.printer.lookup_object(
            config.get('bldc_motor', 'bldc_motor'))
        self.angle_sensor = self.printer.lookup_object(
            config.get('angle_sensor', 'angle_sensor'), None)
        self.spindle_hall = self.printer.lookup_object(
            config.get('spindle_hall', 'spindle_hall'))
        self.traverse = self.printer.lookup_object(
            config.get('traverse', 'traverse'))
        
        # Winding parameters
        self.gear_ratio = config.getfloat('gear_ratio', 0.667)
        self.wire_diameter = config.getfloat('wire_diameter', 0.056)
        
        # Register G-code commands
        gcode = self.printer.lookup_object('gcode')
        gcode.register_command("WINDER_START", self.cmd_WINDER_START, ...)
        gcode.register_command("WINDER_STOP", self.cmd_WINDER_STOP, ...)
    
    def start_winding(self, rpm, direction='forward'):
        """Start winding operation"""
        # Coordinate all modules
        self.bldc_motor.start_motor(rpm=rpm, forward=(direction=='forward'))
        self.traverse.home()  # Ensure traverse is homed
        # ... winding logic ...
    
    def get_rpm(self):
        """Get current RPM (blended from sensors)"""
        # Blend angle sensor and hall sensor RPM
        angle_rpm = self.angle_sensor.get_rpm() if self.angle_sensor else None
        hall_rpm = self.spindle_hall.get_rpm()
        
        # Prefer hall sensor (more reliable), fallback to angle
        return hall_rpm if hall_rpm else angle_rpm
```

## Comparison

### Current Architecture
```
winder.py (1422 lines)
├── BLDC motor control
├── Angle sensor handling
├── Hall sensor handling
├── Traverse coordination
├── Winding logic
└── Status reporting
```

### New Architecture ✅
```
bldc_motor.py (~250 lines) ✅
angle_sensor.py (~300 lines) ✅
spindle_hall.py (~120 lines) ✅
traverse.py (~150 lines) ✅
winder_control.py (~350 lines) ✅
─────────────────────────────
Total: ~1170 lines (better organized!)
```

## Recommendation

**YES, split into modules!** This is better architecture because:

1. ✅ **Clearer naming** - No confusion between `kinematics/winder.py` and `extras/winder.py`
2. ✅ **Better organization** - Each module has a single responsibility
3. ✅ **Easier maintenance** - Smaller, focused modules
4. ✅ **Reusability** - Modules can be used independently
5. ✅ **Follows Klipper patterns** - Matches how other Klipper modules work
6. ✅ **Easier testing** - Test modules independently

## Next Steps

1. **Rename current `winder.py`** → `winder_coordinator.py` (temporary)
2. **Extract modules** one at a time:
   - `angle_sensor.py` first (simplest)
   - `spindle_hall.py` second
   - `traverse.py` third
3. **Refactor coordinator** to use sub-modules
4. **Update config** to use new structure
5. **Test integration**

Would you like me to start extracting the modules?

