# Klipper Module Patterns Analysis

This document analyzes existing Klipper modules to identify patterns, code structures, and techniques that can be leveraged for the winder project.

## Table of Contents

1. [PWM Motor Control Patterns](#pwm-motor-control-patterns)
2. [ADC Sensor Reading Patterns](#adc-sensor-reading-patterns)
3. [Event Handling & State Management](#event-handling--state-management)
4. [G-code Command Patterns](#g-code-command-patterns)
5. [Recommendations for Winder Modules](#recommendations-for-winder-modules)

---

## PWM Motor Control Patterns

### 1. `pwm_tool.py` - Queued PWM Output

**Key Features:**
- Hardware vs Software PWM support
- Cycle time configuration
- Max duration for safety
- Start/shutdown values
- Queued updates via `syncemitter`

**Relevant Code:**
```python
# Setup PWM pin
self.mcu_pwm = ppins.setup_pin('pwm', pin_name)
self.mcu_pwm.setup_max_duration(0.)  # No max duration
self.mcu_pwm.setup_cycle_time(cycle_time, hardware_pwm)
self.mcu_pwm.setup_start_value(start_value, shutdown_value)

# Set PWM value
def set_pwm(self, print_time, value):
    clock = self._mcu.print_time_to_clock(print_time)
    if self._invert:
        value = 1. - value
    v = int(max(0., min(1., value)) * self._pwm_max + 0.5)
    self._send_update(clock, v)
```

**Use for BLDC Motor:**
- ✅ Hardware PWM support (already using)
- ✅ Cycle time = 1/frequency (already using)
- ✅ Proper value clamping (0.0-1.0)
- ✅ Print time scheduling

**Improvements Needed:**
- Consider using `GCodeRequestQueue` for async requests
- Add min_pwm_duty handling (currently manual)

---

### 2. `fan.py` - Fan Control with Enable Pin

**Key Features:**
- Enable pin for power control
- Kick-start time (full speed startup)
- `off_below` threshold
- `GCodeRequestQueue` for async speed changes
- Tachometer integration

**Relevant Code:**
```python
# Enable pin setup
self.enable_pin = None
enable_pin = config.get('enable_pin', None)
if enable_pin is not None:
    self.enable_pin = ppins.setup_pin('digital_out', enable_pin)
    self.enable_pin.setup_max_duration(0.)

# Apply speed with enable pin control
def _apply_speed(self, print_time, value):
    if self.enable_pin:
        if value > 0 and self.last_fan_value == 0:
            self.enable_pin.set_digital(print_time, 1)  # Enable
        elif value == 0 and self.last_fan_value > 0:
            self.enable_pin.set_digital(print_time, 0)  # Disable
    
    # Kick-start logic
    if (value and self.kick_start_time
        and (not self.last_fan_value or value - self.last_fan_value > .5)):
        # Run at full speed for kick_start_time
        self.mcu_fan.set_pwm(print_time, self.max_power)
        return "delay", self.kick_start_time
    
    self.mcu_fan.set_pwm(print_time, value)

# GCodeRequestQueue for async requests
from . import output_pin
self.gcrq = output_pin.GCodeRequestQueue(config, self.mcu_fan.get_mcu(),
                                         self._apply_speed)

def set_speed(self, value, print_time=None):
    self.gcrq.send_async_request(value, print_time)
```

**Use for BLDC Motor:**
- ✅ Enable pin pattern (power_pin) - **ALREADY IMPLEMENTED**
- ✅ Kick-start could help motor startup
- ✅ `GCodeRequestQueue` for better async handling
- ✅ `off_below` threshold for minimum RPM

**Recommended Changes:**
```python
# Replace manual print_time handling with GCodeRequestQueue
from . import output_pin
self.gcrq = output_pin.GCodeRequestQueue(config, self.mcu_pwm.get_mcu(),
                                         self._apply_pwm)

def _apply_pwm(self, print_time, duty_cycle):
    # Handle power pin, brake, direction, PWM
    # Return "delay" tuple if kick-start needed
    pass
```

---

### 3. `servo.py` - Angle-to-PWM Conversion

**Key Features:**
- Angle to pulse width conversion
- Min/max pulse width limits
- `GCodeRequestQueue` integration

**Relevant Code:**
```python
# Angle to PWM conversion
self.min_width = config.getfloat('minimum_pulse_width', .001)
self.max_width = config.getfloat('maximum_pulse_width', .002)
self.max_angle = config.getfloat('maximum_servo_angle', 180.)
self.angle_to_width = (self.max_width - self.min_width) / self.max_angle
self.width_to_value = 1. / SERVO_SIGNAL_PERIOD

def _get_pwm_from_angle(self, angle):
    angle = max(0., min(self.max_angle, angle))
    width = self.min_width + angle * self.angle_to_width
    return width * self.width_to_value
```

**Use for BLDC Motor:**
- RPM to duty cycle conversion (similar pattern)
- Clamping min/max values
- Not directly applicable, but pattern is useful

---

## ADC Sensor Reading Patterns

### 1. `hall_filament_width_sensor.py` - Dual ADC Reading

**Key Features:**
- Two ADC pins (adc1, adc2)
- Separate callbacks for each ADC
- Averaging/smoothing (5:1 ratio)
- Calibration with two points
- Array-based position tracking

**Relevant Code:**
```python
# Setup two ADC pins
self.mcu_adc = self.ppins.setup_pin('adc', self.pin1)
self.mcu_adc.setup_adc_sample(ADC_SAMPLE_TIME, ADC_SAMPLE_COUNT)
self.mcu_adc.setup_adc_callback(ADC_REPORT_TIME, self.adc_callback)

self.mcu_adc2 = self.ppins.setup_pin('adc', self.pin2)
self.mcu_adc2.setup_adc_sample(ADC_SAMPLE_TIME, ADC_SAMPLE_COUNT)
self.mcu_adc2.setup_adc_callback(ADC_REPORT_TIME, self.adc2_callback)

# Callback pattern
def adc_callback(self, read_time, read_value):
    self.lastFilamentWidthReading = round(read_value * 10000)

def adc2_callback(self, read_time, read_value):
    self.lastFilamentWidthReading2 = round(read_value * 10000)
    # Calculate diameter using two-point calibration
    diameter_new = round((self.dia2 - self.dia1)/
        (self.rawdia2-self.rawdia1)*
      ((self.lastFilamentWidthReading+self.lastFilamentWidthReading2)
       -self.rawdia1)+self.dia1,2)
    # Smoothing: 5 parts old, 1 part new
    self.diameter=(5.0 * self.diameter + diameter_new)/6
```

**Use for Angle Sensor:**
- ✅ Dual ADC pattern (if needed for redundancy)
- ✅ Smoothing algorithm (5:1 ratio)
- ✅ Two-point calibration
- ✅ Position-based tracking array

**Current Implementation:**
- Single ADC (PA1) - sufficient
- Smoothing via buffer averaging - good
- Auto-calibration - better than manual two-point

**Potential Improvement:**
- Consider exponential smoothing like filament sensor:
```python
# Instead of simple average, use weighted average
self.angle_value = (5.0 * self.angle_value + new_value) / 6.0
```

---

### 2. `adc_scaled.py` - Scaled ADC with VREF/VSSA

**Key Features:**
- Scales ADC based on VREF and VSSA
- Handles voltage reference drift
- Smoothing with time constant

**Relevant Code:**
```python
def _handle_callback(self, read_time, read_value):
    max_adc = self._main.last_vref[1]
    min_adc = self._main.last_vssa[1]
    scaled_val = (read_value - min_adc) / (max_adc - min_adc)
    self._last_state = (scaled_val, read_time)
    self._callback(read_time, scaled_val)

def calc_smooth(self, read_time, read_value, last):
    last_time, last_value = last
    time_diff = read_time - last_time
    value_diff = read_value - last_value
    adj_time = min(time_diff * self.inv_smooth_time, 1.)
    smoothed_value = last_value + value_diff * adj_time
    return (read_time, smoothed_value)
```

**Use for Angle Sensor:**
- ✅ Voltage reference scaling (if VCC varies)
- ✅ Time-based smoothing (better than simple average)
- Currently not needed (stable 5V supply), but pattern is useful

---

## Event Handling & State Management

### 1. `filament_switch_sensor.py` - RunoutHelper Pattern

**Key Features:**
- Reusable helper class (`RunoutHelper`)
- Event delay to prevent false triggers
- State tracking (`filament_present`)
- G-code execution on events
- Status reporting

**Relevant Code:**
```python
class RunoutHelper:
    def __init__(self, config):
        self.event_delay = config.getfloat('event_delay', 3., minval=.0)
        self.min_event_systime = self.reactor.NEVER
        self.filament_present = False
        self.sensor_enabled = True
    
    def note_filament_present(self, eventtime, is_filament_present):
        if is_filament_present == self.filament_present:
            return
        
        self.filament_present = is_filament_present
        
        if eventtime < self.min_event_systime or not self.sensor_enabled:
            return  # Ignore during initialization/cooldown
        
        # Check printing status
        idle_timeout = self.printer.lookup_object("idle_timeout")
        is_printing = idle_timeout.get_status(now)["state"] == "Printing"
        
        if is_filament_present:
            # Insert event
            self.reactor.register_callback(self._insert_event_handler)
        else:
            # Runout event
            self.reactor.register_callback(self._runout_event_handler)
```

**Use for Winder:**
- ✅ Event delay pattern (prevent false triggers)
- ✅ State change detection
- ✅ G-code execution on events
- Could create `WinderHelper` for common winder event handling

---

### 2. `filament_motion_sensor.py` - Position-Based Tracking

**Key Features:**
- Position-based detection (not just time-based)
- Extruder position tracking
- Timer-based updates
- Integration with `RunoutHelper`

**Relevant Code:**
```python
def _extruder_pos_update_event(self, eventtime):
    extruder_pos = self._get_extruder_pos(eventtime)
    # Check for filament runout
    self.runout_helper.note_filament_present(eventtime,
            extruder_pos < self.filament_runout_pos)
    return eventtime + CHECK_RUNOUT_TIMEOUT

def _get_extruder_pos(self, eventtime=None):
    if eventtime is None:
        eventtime = self.reactor.monotonic()
    print_time = self.estimated_print_time(eventtime)
    return self.extruder.find_past_position(print_time)
```

**Use for Winder:**
- ✅ Position-based tracking (wire length, turns)
- ✅ Timer-based updates
- ✅ Past position lookup
- Could track wire length based on spindle revolutions

---

## G-code Command Patterns

### 1. `gcode_move.py` - Lookahead Callbacks

**Key Features:**
- `register_lookahead_callback` for timing
- Print time scheduling
- Coordinate manipulation

**Relevant Code:**
```python
def cmd_SET_PIN(self, gcmd):
    value = gcmd.get_float('VALUE', minval=0., maxval=self.scale)
    value /= self.scale
    # Obtain print_time and apply requested settings
    toolhead = self.printer.lookup_object('toolhead')
    toolhead.register_lookahead_callback(
        lambda print_time: self._set_pin(print_time, value))
```

**Use for BLDC Motor:**
- ✅ Proper print time scheduling
- ✅ Lookahead for coordinated moves
- Currently using manual `toolhead.get_last_move_time()` - could improve

---

### 2. `servo.py` - GCodeRequestQueue Pattern

**Key Features:**
- `GCodeRequestQueue` for async requests
- Proper print time handling
- Discard duplicate requests

**Relevant Code:**
```python
from . import output_pin

self.gcrq = output_pin.GCodeRequestQueue(
    config, self.mcu_servo.get_mcu(), self._set_pwm)

def _set_pwm(self, print_time, value):
    if value == self.last_value:
        return "discard", 0.  # Discard duplicate
    self.last_value = value
    self.mcu_servo.set_pwm(print_time, value)

def cmd_SET_SERVO(self, gcmd):
    angle = gcmd.get_float('ANGLE')
    value = self._get_pwm_from_angle(angle)
    self.gcrq.queue_gcode_request(value)  # Queue async
```

**Use for BLDC Motor:**
- ✅ Async request handling
- ✅ Duplicate request detection
- ✅ Proper print time scheduling
- **RECOMMENDED**: Replace manual print_time handling

---

## Recommendations for Winder Modules

### BLDC Motor (`bldc_motor.py`)

**Current Implementation:**
- ✅ Basic PWM setup
- ✅ Direction/Brake/Power pins
- ✅ Manual print_time handling
- ✅ Sequential reactor callbacks

**Recommended Improvements:**

1. **Use `GCodeRequestQueue`**:
```python
from . import output_pin

class BLDCMotor:
    def __init__(self, config):
        # ... existing code ...
        self.gcrq = output_pin.GCodeRequestQueue(
            config, self.mcu_pwm.get_mcu(), self._apply_motor_state)
    
    def _apply_motor_state(self, print_time, duty_cycle):
        """Apply motor state changes atomically"""
        # Handle power pin
        if self.mcu_power:
            if duty_cycle > 0 and not self.power_on:
                self.mcu_power.set_digital(print_time, 1)
                self.power_on = True
            elif duty_cycle == 0 and self.power_on:
                self.mcu_power.set_digital(print_time, 0)
                self.power_on = False
        
        # Handle brake
        if self.mcu_brake:
            brake_value = 0 if duty_cycle > 0 else 1
            if self.brake_inverted:
                brake_value = 1 - brake_value
            self.mcu_brake.set_digital(print_time, brake_value)
        
        # Handle direction
        if self.mcu_dir:
            dir_value = 0 if self.direction_forward else 1
            if self.dir_inverted:
                dir_value = 1 - dir_value
            self.mcu_dir.set_digital(print_time, dir_value)
        
        # Set PWM (with min duty cycle)
        actual_duty = max(self.min_pwm_duty, min(duty_cycle, 1.0))
        self.mcu_pwm.set_pwm(print_time, actual_duty)
        
        # Return delay if kick-start needed
        if duty_cycle > 0 and self.last_duty == 0:
            return "delay", self.kick_start_time
        
        self.last_duty = duty_cycle
    
    def set_rpm(self, rpm):
        duty_cycle = rpm / self.max_rpm
        self.gcrq.queue_gcode_request(duty_cycle)
```

2. **Add Kick-Start**:
```python
self.kick_start_time = config.getfloat('kick_start_time', 0.1, minval=0.)
```

3. **Add `off_below` Threshold**:
```python
self.off_below = config.getfloat('off_below', 0.05, minval=0., maxval=1.)
# In _apply_motor_state:
if duty_cycle < self.off_below:
    duty_cycle = 0.0
```

---

### Angle Sensor (`angle_sensor.py`)

**Current Implementation:**
- ✅ ADC callback pattern
- ✅ Buffer-based averaging
- ✅ Auto-calibration
- ✅ Saturation handling

**Recommended Improvements:**

1. **Add Exponential Smoothing** (like filament sensor):
```python
def _angle_sensor_callback(self, read_time, read_value):
    # ... existing calibration code ...
    
    # Exponential smoothing (5:1 ratio)
    if self.last_angle_value is not None:
        self.angle_value = (5.0 * self.angle_value + mapped_value) / 6.0
    else:
        self.angle_value = mapped_value
```

2. **Add Voltage Reference Scaling** (if VCC varies):
```python
# Similar to adc_scaled.py
self.vcc_reference = config.getfloat('vcc_reference', 5.0)
# Scale ADC based on actual VCC
scaled_value = read_value * (self.vcc_reference / 5.0)
```

---

### Spindle Hall Sensor (`spindle_hall.py`)

**Current Implementation:**
- ✅ Uses `pulse_counter.FrequencyCounter`
- ✅ RPM calculation

**No Changes Needed** - Already follows best practices!

---

### Traverse (`traverse.py`)

**Current Implementation:**
- ✅ Uses standard stepper
- ✅ Homing integration
- ✅ Position tracking

**No Changes Needed** - Uses standard Klipper stepper patterns!

---

## Summary of Key Patterns

| Pattern | Module | Use For | Status |
|---------|--------|---------|--------|
| **GCodeRequestQueue** | `servo.py`, `fan.py` | BLDC Motor | ⚠️ **RECOMMENDED** |
| **Enable Pin** | `fan.py` | BLDC Power Pin | ✅ Already Using |
| **Kick-Start** | `fan.py` | BLDC Motor | ⚠️ **RECOMMENDED** |
| **Exponential Smoothing** | `hall_filament_width_sensor.py` | Angle Sensor | ⚠️ **RECOMMENDED** |
| **Dual ADC** | `hall_filament_width_sensor.py` | Angle Sensor | ❌ Not Needed |
| **RunoutHelper** | `filament_switch_sensor.py` | Event Handling | 💡 Could Use |
| **Position Tracking** | `filament_motion_sensor.py` | Wire Length | 💡 Could Use |
| **Lookahead Callbacks** | `gcode_move.py` | Timing | ✅ Already Using |

**Legend:**
- ✅ Already Implemented
- ⚠️ Recommended Improvement
- 💡 Optional Enhancement
- ❌ Not Applicable

---

## Next Steps

1. **Priority 1**: Refactor BLDC motor to use `GCodeRequestQueue`
2. **Priority 2**: Add kick-start to BLDC motor
3. **Priority 3**: Add exponential smoothing to angle sensor
4. **Priority 4**: Consider `RunoutHelper` pattern for winder events

