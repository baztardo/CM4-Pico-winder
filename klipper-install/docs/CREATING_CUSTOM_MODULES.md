# Creating Custom Klipper Modules

## Overview

To create a custom configuration section like `[angle_sensor]`, you need to:

1. Create a Python module file in `klippy/extras/`
2. Export a `load_config()` or `load_config_prefix()` function
3. Register event handlers and G-code commands
4. Communicate with other modules via `printer.lookup_object()`

## Basic Structure

### Simple Section: `[angle_sensor]`

**File:** `klippy/extras/angle_sensor.py`

```python
# Custom angle sensor module
#
# Copyright (C) 2024  Your Name
#
# This file may be distributed under the terms of the GNU GPLv3 license.
import logging

class AngleSensor:
    def __init__(self, config):
        self.printer = config.get_printer()
        self.name = config.get_name()
        
        # Read config parameters
        self.sensor_pin = config.get('sensor_pin')
        self.sample_rate = config.getfloat('sample_rate', 100.0, above=0.)
        
        # Setup hardware pin
        ppins = self.printer.lookup_object('pins')
        self.mcu_adc = ppins.setup_pin('adc', self.sensor_pin)
        
        # Register event handlers
        self.printer.register_event_handler("klippy:connect", self.handle_connect)
        self.printer.register_event_handler("klippy:ready", self.handle_ready)
        
        # Register G-code commands
        gcode = self.printer.lookup_object('gcode')
        gcode.register_command("QUERY_ANGLE_SENSOR", self.cmd_QUERY_ANGLE_SENSOR,
                               desc=self.cmd_QUERY_ANGLE_SENSOR_help)
    
    def handle_connect(self):
        """Called when MCU connects"""
        logging.info("Angle sensor connected")
    
    def handle_ready(self):
        """Called when Klipper is ready"""
        logging.info("Angle sensor ready")
    
    cmd_QUERY_ANGLE_SENSOR_help = "Query angle sensor value"
    def cmd_QUERY_ANGLE_SENSOR(self, gcmd):
        """G-code command handler"""
        value, timestamp = self.mcu_adc.get_last_value()
        gcmd.respond_info("Angle sensor value: %.3f" % value)
    
    def get_status(self, eventtime):
        """Status reporting for API"""
        value, timestamp = self.mcu_adc.get_last_value()
        return {
            'value': value,
            'timestamp': timestamp
        }

def load_config(config):
    return AngleSensor(config)
```

**Config file:**
```cfg
[angle_sensor]
sensor_pin: PA0
sample_rate: 100.0
```

### Prefix Section: `[angle_sensor spindle]`

**File:** `klippy/extras/angle_sensor.py` (same file, different function)

```python
def load_config_prefix(config):
    # config.get_name() = "angle_sensor spindle"
    return AngleSensor(config)
```

**Config file:**
```cfg
[angle_sensor spindle]
sensor_pin: PA0
sample_rate: 100.0

[angle_sensor traverse]
sensor_pin: PA1
sample_rate: 50.0
```

## Key Components

### 1. Module Registration Functions

**For simple sections:**
```python
def load_config(config):
    return MyModule(config)
```

**For prefix sections:**
```python
def load_config_prefix(config):
    return MyModule(config)
```

### 2. Config Access

```python
class MyModule:
    def __init__(self, config):
        # Get printer object
        self.printer = config.get_printer()
        
        # Get section name
        self.name = config.get_name()  # e.g., "angle_sensor" or "angle_sensor spindle"
        
        # Read config parameters
        self.pin = config.get('pin')  # Required
        self.rate = config.getfloat('rate', 100.0)  # Optional, default 100.0
        self.enabled = config.getboolean('enabled', True)  # Optional, default True
        
        # Get subsections
        if config.has_section('submodule'):
            sub_config = config.getsection('submodule')
            self.sub_value = sub_config.get('value')
```

### 3. Pin Setup

```python
from . import pins

class MyModule:
    def __init__(self, config):
        self.printer = config.get_printer()
        
        # Get pins object
        ppins = self.printer.lookup_object('pins')
        
        # Setup different pin types
        self.mcu_adc = ppins.setup_pin('adc', config.get('sensor_pin'))
        self.mcu_digital = ppins.setup_pin('digital_out', config.get('output_pin'))
        self.mcu_pwm = ppins.setup_pin('pwm', config.get('pwm_pin'))
```

### 4. Event Handlers

```python
class MyModule:
    def __init__(self, config):
        self.printer = config.get_printer()
        
        # Register event handlers
        self.printer.register_event_handler("klippy:connect", self.handle_connect)
        self.printer.register_event_handler("klippy:ready", self.handle_ready)
        self.printer.register_event_handler("klippy:shutdown", self.handle_shutdown)
        self.printer.register_event_handler("homing:home_rails_begin", self.handle_home_begin)
        self.printer.register_event_handler("homing:home_rails_end", self.handle_home_end)
    
    def handle_connect(self):
        """Called when MCU connects (before ready)"""
        pass
    
    def handle_ready(self):
        """Called when Klipper is fully ready"""
        pass
    
    def handle_shutdown(self):
        """Called on shutdown"""
        pass
```

**Common Events:**
- `"klippy:connect"` - MCU connected
- `"klippy:ready"` - Klipper ready
- `"klippy:shutdown"` - Shutting down
- `"homing:home_rails_begin"` - Homing started
- `"homing:home_rails_end"` - Homing finished
- `"stepper:sync_mcu_position"` - Stepper position synced
- `"toolhead:set_position"` - Toolhead position set

### 5. G-Code Commands

```python
class MyModule:
    def __init__(self, config):
        gcode = self.printer.lookup_object('gcode')
        
        # Simple command
        gcode.register_command("MY_COMMAND", self.cmd_MY_COMMAND,
                               desc=self.cmd_MY_COMMAND_help)
        
        # Mux command (with parameter)
        gcode.register_mux_command("SET_MY_VALUE", "PARAM", "default",
                                   self.cmd_SET_MY_VALUE,
                                   desc=self.cmd_SET_MY_VALUE_help)
    
    cmd_MY_COMMAND_help = "Description of command"
    def cmd_MY_COMMAND(self, gcmd):
        # Get parameters
        value = gcmd.get_float('VALUE', 0.0)
        name = gcmd.get('NAME', 'default')
        
        # Respond
        gcmd.respond_info("Value: %.3f" % value)
        
        # Or raise error
        if value < 0:
            raise gcmd.error("Value must be positive")
    
    cmd_SET_MY_VALUE_help = "Set my value"
    def cmd_SET_MY_VALUE(self, gcmd):
        param = gcmd.get('PARAM')  # From mux
        value = gcmd.get_float('VALUE')
        # ...
```

### 6. Communicating with Other Modules

```python
class MyModule:
    def __init__(self, config):
        self.printer = config.get_printer()
    
    def some_method(self):
        # Lookup other modules
        toolhead = self.printer.lookup_object('toolhead')
        stepper_y = self.printer.lookup_object('stepper_y')
        winder = self.printer.lookup_object('winder')
        
        # Get status from other modules
        toolhead_status = toolhead.get_status(None)
        winder_status = winder.get_status(None)
        
        # Call methods on other modules
        position = toolhead.get_position()
        stepper_y.do_set_position([0, 0, 0, 0])
```

### 7. Status Reporting

```python
class MyModule:
    def get_status(self, eventtime):
        """Called by API to get module status"""
        return {
            'value': self.current_value,
            'enabled': self.enabled,
            'last_update': self.last_update_time
        }
```

**Access via API:**
```python
# Other modules can query your status
my_module = self.printer.lookup_object('angle_sensor')
status = my_module.get_status(None)
```

## Complete Example: Angle Sensor Module

```python
# klippy/extras/angle_sensor.py
import logging
from . import query_adc

REPORT_TIME = 0.100  # Report every 100ms

class AngleSensor:
    def __init__(self, config):
        self.printer = config.get_printer()
        self.name = config.get_name()
        
        # Config parameters
        self.sensor_pin = config.get('sensor_pin')
        self.max_angle = config.getfloat('max_angle', 360.0, above=0.)
        
        # Setup ADC pin
        ppins = self.printer.lookup_object('pins')
        self.mcu_adc = ppins.setup_pin('adc', self.sensor_pin)
        
        # Register with query_adc
        query_adc = self.printer.load_object(config, 'query_adc')
        query_adc.register_adc(self.name, self.mcu_adc)
        
        # Setup ADC callback
        self.mcu_adc.setup_adc_callback(REPORT_TIME, self.adc_callback)
        
        # State
        self.last_value = 0.0
        self.last_angle = 0.0
        self.last_read_time = 0.0
        
        # Register events
        self.printer.register_event_handler("klippy:connect", self.handle_connect)
        
        # Register G-code
        gcode = self.printer.lookup_object('gcode')
        gcode.register_command("QUERY_ANGLE_SENSOR", self.cmd_QUERY_ANGLE_SENSOR,
                               desc=self.cmd_QUERY_ANGLE_SENSOR_help)
    
    def handle_connect(self):
        logging.info("Angle sensor '%s' connected on pin %s" % 
                     (self.name, self.sensor_pin))
    
    def adc_callback(self, read_time, read_value):
        """Called when ADC reading is available"""
        # Convert ADC value (0.0-1.0) to angle (0-360)
        self.last_value = read_value
        self.last_angle = read_value * self.max_angle
        self.last_read_time = read_time
    
    cmd_QUERY_ANGLE_SENSOR_help = "Query angle sensor value"
    def cmd_QUERY_ANGLE_SENSOR(self, gcmd):
        name = gcmd.get('NAME', self.name)
        if name != self.name:
            gcmd.respond_info("Unknown sensor: %s" % name)
            return
        
        gcmd.respond_info("Angle sensor '%s': %.3f° (ADC: %.6f)" % 
                          (self.name, self.last_angle, self.last_value))
    
    def get_status(self, eventtime):
        """Status for API"""
        return {
            'value': self.last_value,
            'angle': self.last_angle,
            'timestamp': self.last_read_time
        }

def load_config(config):
    return AngleSensor(config)

def load_config_prefix(config):
    # For [angle_sensor spindle] style sections
    return AngleSensor(config)
```

## Module Communication Patterns

### Pattern 1: Lookup and Use

```python
# In your module
def some_method(self):
    # Get another module
    toolhead = self.printer.lookup_object('toolhead')
    
    # Use it
    position = toolhead.get_position()
    toolhead.manual_move([10, 0, 0], 100)  # Move X 10mm at 100mm/s
```

### Pattern 2: Register Callbacks

```python
# In your module
def __init__(self, config):
    # Register callback with another module
    stepper_enable = self.printer.lookup_object('stepper_enable')
    stepper_enable.register_stepper(config, self.my_stepper)
```

### Pattern 3: Event Handlers

```python
# In your module
def __init__(self, config):
    # Listen to events from other modules
    self.printer.register_event_handler("stepper:sync_mcu_position",
                                       self.handle_stepper_sync)

def handle_stepper_sync(self, mcu_stepper):
    if mcu_stepper.get_name() == "stepper_y":
        # Do something when stepper_y syncs
        pass
```

### Pattern 4: Status Queries

```python
# In your module
def get_other_module_status(self):
    # Query status from another module
    winder = self.printer.lookup_object('winder')
    status = winder.get_status(None)
    
    rpm = status.get('rpm', 0.0)
    angle = status.get('angle', 0.0)
```

## Common Module Patterns

### ADC Sensor Pattern

```python
class MyADCSensor:
    def __init__(self, config):
        ppins = self.printer.lookup_object('pins')
        self.mcu_adc = ppins.setup_pin('adc', config.get('sensor_pin'))
        self.mcu_adc.setup_adc_callback(REPORT_TIME, self.adc_callback)
    
    def adc_callback(self, read_time, read_value):
        # Process ADC reading
        pass
```

### Output Pin Pattern

```python
class MyOutputPin:
    def __init__(self, config):
        ppins = self.printer.lookup_object('pins')
        self.mcu_pin = ppins.setup_pin('digital_out', config.get('pin'))
    
    def set_value(self, value):
        print_time = self.printer.lookup_object('toolhead').get_last_move_time()
        self.mcu_pin.set_digital(print_time, value)
```

### Stepper Integration Pattern

```python
class MyStepperModule:
    def __init__(self, config):
        # Register with stepper_enable
        stepper_enable = self.printer.lookup_object('stepper_enable')
        stepper_enable.register_stepper(config, self.my_stepper)
        
        # Listen to stepper events
        self.printer.register_event_handler("stepper:sync_mcu_position",
                                           self.handle_sync)
```

## Testing Your Module

1. **Add to config:**
   ```cfg
   [angle_sensor]
   sensor_pin: PA0
   ```

2. **Restart Klipper:**
   ```bash
   sudo systemctl restart klipper
   ```

3. **Check logs:**
   ```bash
   tail -f /tmp/klippy.log
   ```

4. **Test G-code:**
   ```bash
   python3 ~/klipper/scripts/klipper_interface.py -g "QUERY_ANGLE_SENSOR"
   ```

## Best Practices

1. **Error Handling:**
   ```python
   try:
       value = config.get('required_param')
   except config.error as e:
       raise config.error("Missing required_param: %s" % str(e))
   ```

2. **Logging:**
   ```python
   import logging
   logging.info("Module initialized")
   logging.warning("Warning message")
   logging.error("Error message")
   ```

3. **Status Reporting:**
   ```python
   def get_status(self, eventtime):
       return {
           'key': self.value,
           'timestamp': eventtime
       }
   ```

4. **Documentation:**
   ```python
   cmd_MY_COMMAND_help = "Clear description of what command does"
   ```

## References

- `klippy/extras/query_adc.py` - Simple ADC query module
- `klippy/extras/adc_temperature.py` - ADC sensor with callbacks
- `klippy/extras/angle.py` - Complex sensor module (SPI angle sensors)
- `klippy/extras/output_pin.py` - Output pin control
- `klippy/extras/stepper_enable.py` - Stepper enable/disable

