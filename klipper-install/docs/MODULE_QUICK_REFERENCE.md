# Klipper Module Quick Reference

## File Location

Create: `klippy/extras/angle_sensor.py`

## Minimal Template

```python
# klippy/extras/angle_sensor.py
import logging

class AngleSensor:
    def __init__(self, config):
        self.printer = config.get_printer()
        self.name = config.get_name()
        
        # Read config
        self.pin = config.get('sensor_pin')
        
        # Setup hardware
        ppins = self.printer.lookup_object('pins')
        self.mcu_adc = ppins.setup_pin('adc', self.pin)
        
        # Register events
        self.printer.register_event_handler("klippy:connect", self.handle_connect)
        
        # Register G-code
        gcode = self.printer.lookup_object('gcode')
        gcode.register_command("QUERY_ANGLE", self.cmd_QUERY_ANGLE,
                               desc=self.cmd_QUERY_ANGLE_help)
    
    def handle_connect(self):
        logging.info("Angle sensor connected")
    
    cmd_QUERY_ANGLE_help = "Query angle sensor"
    def cmd_QUERY_ANGLE(self, gcmd):
        value, _ = self.mcu_adc.get_last_value()
        gcmd.respond_info("Angle: %.3f" % value)
    
    def get_status(self, eventtime):
        value, timestamp = self.mcu_adc.get_last_value()
        return {'value': value, 'timestamp': timestamp}

def load_config(config):
    return AngleSensor(config)
```

## Config File

```cfg
[angle_sensor]
sensor_pin: PA0
```

## Key Functions

### Registration
- `load_config(config)` - For `[angle_sensor]`
- `load_config_prefix(config)` - For `[angle_sensor spindle]`

### Config Access
- `config.get('param')` - Required string
- `config.getfloat('param', default)` - Optional float
- `config.getboolean('param', default)` - Optional bool
- `config.getint('param', default)` - Optional int
- `config.get_name()` - Section name
- `config.getsection('subsection')` - Get subsection

### Module Lookup
- `printer.lookup_object('module_name')` - Get module
- `printer.load_object(config, 'module_name')` - Load module

### Pin Setup
```python
ppins = printer.lookup_object('pins')
adc = ppins.setup_pin('adc', 'PA0')
digital = ppins.setup_pin('digital_out', 'PB1')
pwm = ppins.setup_pin('pwm', 'PB3')
```

### Event Handlers
```python
printer.register_event_handler("klippy:connect", callback)
printer.register_event_handler("klippy:ready", callback)
printer.register_event_handler("klippy:shutdown", callback)
printer.register_event_handler("homing:home_rails_end", callback)
```

### G-Code Commands
```python
gcode = printer.lookup_object('gcode')
gcode.register_command("MY_CMD", self.cmd_MY_CMD, desc="Help text")
gcode.register_mux_command("SET_VAL", "PARAM", "default", 
                           self.cmd_SET_VAL, desc="Help")
```

### G-Code Handler
```python
def cmd_MY_CMD(self, gcmd):
    value = gcmd.get_float('VALUE', 0.0)
    name = gcmd.get('NAME', 'default')
    gcmd.respond_info("Result: %.3f" % value)
    # Or raise error:
    raise gcmd.error("Invalid value")
```

## Common Patterns

### ADC Sensor
```python
self.mcu_adc.setup_adc_callback(REPORT_TIME, self.adc_callback)

def adc_callback(self, read_time, read_value):
    self.last_value = read_value
```

### Output Pin
```python
print_time = toolhead.get_last_move_time()
self.mcu_pin.set_digital(print_time, 1)  # HIGH
```

### Status Reporting
```python
def get_status(self, eventtime):
    return {'key': self.value}
```

## Module Communication

```python
# Get module
toolhead = self.printer.lookup_object('toolhead')
winder = self.printer.lookup_object('winder')

# Get status
status = toolhead.get_status(None)
position = toolhead.get_position()

# Call methods
toolhead.manual_move([10, 0, 0], 100)
```

## Testing

1. Add to `printer.cfg`:
   ```cfg
   [angle_sensor]
   sensor_pin: PA0
   ```

2. Restart:
   ```bash
   sudo systemctl restart klipper
   ```

3. Test:
   ```bash
   python3 ~/klipper/scripts/klipper_interface.py -g "QUERY_ANGLE"
   ```

