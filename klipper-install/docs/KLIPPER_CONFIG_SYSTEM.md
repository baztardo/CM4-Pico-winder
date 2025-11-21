# Klipper Configuration System Explained

## Overview

This document explains how Klipper parses, registers, and uses configuration sections like `[stepper_y]`, `[winder]`, etc.

## Key Files

### 1. **`klippy/configfile.py`** - Configuration Parser
   - **Purpose**: Parses the `printer.cfg` file and handles includes
   - **Key Classes**:
     - `ConfigFileReader`: Reads and parses config files (handles `[include]` directives)
     - `ConfigWrapper`: Wraps a config section, provides `get()`, `getfloat()`, etc.
     - `PrinterConfig`: Main config manager, tracks autosave and validation

### 2. **`klippy/klippy.py`** - Main Printer Object
   - **Purpose**: Loads all configuration sections and creates objects
   - **Key Method**: `load_object(config, section_name)`
     - Dynamically loads Python modules from `klippy/extras/` or `klippy/kinematics/`
     - Calls `load_config()` or `load_config_prefix()` function in the module

### 3. **`klippy/stepper.py`** - Stepper Motor Handling
   - **Purpose**: Creates stepper motor objects from config sections
   - **Key Function**: `PrinterStepper(config)` - builds MCU stepper from config

## How Configuration Sections Work

### Step 1: Config File Parsing

```python
# klippy/klippy.py, line 114-127
def _read_config(self):
    # 1. Read config file (handles includes, autosave, etc.)
    config = pconfig.read_main_config()
    
    # 2. Load ALL sections that start with any prefix
    for section_config in config.get_prefix_sections(''):
        self.load_object(config, section_config.get_name(), None)
```

**What happens:**
- `config.get_prefix_sections('')` finds ALL sections: `[stepper_x]`, `[stepper_y]`, `[winder]`, `[tmc2209 stepper_y]`, etc.
- Each section name is passed to `load_object()`

### Step 2: Dynamic Module Loading

```python
# klippy/klippy.py, line 90-113
def load_object(self, config, section, default=configfile.sentinel):
    # Example: section = "stepper_y"
    module_parts = section.split()  # ["stepper_y"]
    module_name = module_parts[0]   # "stepper_y"
    
    # Look for module in klippy/extras/stepper_y.py
    py_name = os.path.join('extras', module_name + '.py')
    
    # Import the module
    mod = importlib.import_module('extras.' + module_name)
    
    # Call load_config() or load_config_prefix() function
    init_func = getattr(mod, 'load_config', None)
    if init_func is None:
        init_func = getattr(mod, 'load_config_prefix', None)
    
    # Create the object
    self.objects[section] = init_func(config.getsection(section))
```

**What happens:**
- For `[stepper_y]`: Looks for `klippy/extras/stepper_y.py` → **Doesn't exist!**
- Falls back to `load_config_prefix()` pattern

### Step 3: Prefix-Based Loading (for steppers)

For sections like `[stepper_y]`, Klipper uses a **prefix pattern**:

```python
# klippy/klippy.py, line 105-106
if len(module_parts) > 1:  # ["stepper", "y"]
    init_func = 'load_config_prefix'  # Use prefix loader
```

**What happens:**
- `[stepper_y]` splits into `["stepper", "y"]`
- Looks for `klippy/extras/stepper.py` → **Exists!**
- Calls `stepper.load_config_prefix(config)` with section name `"stepper_y"`

### Step 4: Stepper Module Registration

```python
# klippy/extras/stepper.py (if it existed, but it doesn't)
# Instead, steppers are loaded by kinematics!

# klippy/kinematics/cartesian.py, line 16
self.rails = [stepper.LookupMultiRail(config.getsection('stepper_' + n))
              for n in 'xyz']
```

**What happens:**
- Kinematics (like `cartesian`) explicitly loads `[stepper_x]`, `[stepper_y]`, `[stepper_z]`
- Calls `stepper.LookupMultiRail(config.getsection('stepper_y'))`
- Which calls `stepper.PrinterStepper(config)` to create the MCU stepper

## Example: `[stepper_y]` Flow

```
1. Config file parsed:
   [stepper_y]
   step_pin: PF12
   dir_pin: PF11
   ...

2. klippy.py finds section:
   section_config.get_name() → "stepper_y"

3. load_object() called:
   module_parts = ["stepper_y"]
   module_name = "stepper_y"
   → Looks for extras/stepper_y.py (doesn't exist)

4. Falls back to prefix pattern:
   module_parts = ["stepper", "y"]  # Split on underscore
   → Looks for extras/stepper.py (doesn't exist either!)

5. Kinematics loads it explicitly:
   cartesian.py: config.getsection('stepper_y')
   → stepper.LookupMultiRail(config)
   → stepper.PrinterStepper(config)
   → Creates MCU_stepper object
```

## Example: `[winder]` Flow

```
1. Config file parsed:
   [winder]
   spindle_hall_pin: ^PF6
   angle_sensor_pin: PA0
   ...

2. klippy.py finds section:
   section_config.get_name() → "winder"

3. load_object() called:
   module_parts = ["winder"]
   module_name = "winder"
   → Looks for extras/winder.py ✅ EXISTS!

4. Calls winder.load_config(config):
   def load_config(config):
       return Winder(config.get_printer(), config)
   
5. Winder object created and registered:
   printer.objects['winder'] = Winder(...)
```

## Example: `[tmc2209 stepper_y]` Flow

```
1. Config file parsed:
   [tmc2209 stepper_y]
   uart_pin: PF13
   ...

2. klippy.py finds section:
   section_config.get_name() → "tmc2209 stepper_y"

3. load_object() called:
   module_parts = ["tmc2209", "stepper_y"]
   module_name = "tmc2209"
   → Looks for extras/tmc2209.py ✅ EXISTS!

4. Calls tmc2209.load_config_prefix(config):
   def load_config_prefix(config):
       # config.get_name() = "tmc2209 stepper_y"
       return TMC2209(config.get_printer(), config)
   
5. TMC2209 object created:
   printer.objects['tmc2209 stepper_y'] = TMC2209(...)
```

## Key Concepts

### 1. **Section Naming Patterns**

- **Simple**: `[winder]` → Looks for `extras/winder.py`
- **Prefix**: `[stepper_y]` → Looks for `extras/stepper.py` with `load_config_prefix()`
- **Multi-word**: `[tmc2209 stepper_y]` → Looks for `extras/tmc2209.py` with `load_config_prefix()`

### 2. **Module Registration Functions**

Modules must export one of these functions:

```python
# For simple sections: [winder]
def load_config(config):
    return MyModule(config.get_printer(), config)

# For prefix sections: [stepper_y], [tmc2209 stepper_y]
def load_config_prefix(config):
    # config.get_name() = full section name
    return MyModule(config.get_printer(), config)
```

### 3. **Config Access**

Once loaded, objects can access their config:

```python
class Winder:
    def __init__(self, printer, config):
        # config is a ConfigWrapper for [winder] section
        self.hall_pin = config.get('spindle_hall_pin')
        self.angle_pin = config.get('angle_sensor_pin')
        self.rpm_max = config.getfloat('rpm_max', default=1000.0)
```

### 4. **Object Lookup**

Other modules can find registered objects:

```python
# In winder.py
def __init__(self, printer, config):
    self.printer = printer
    
    # Look up stepper_y object
    stepper_y = printer.lookup_object('stepper_y')
    
    # Look up TMC2209 driver
    tmc = printer.lookup_object('tmc2209 stepper_y')
```

## Special Cases

### Steppers Are Loaded by Kinematics

**Important**: `[stepper_x]`, `[stepper_y]`, `[stepper_z]` are **NOT** loaded automatically by `load_object()`!

Instead, they're loaded **explicitly by kinematics**:

```python
# klippy/kinematics/cartesian.py
class CartKinematics:
    def __init__(self, toolhead, config):
        # Explicitly loads [stepper_x], [stepper_y], [stepper_z]
        self.rails = [
            stepper.LookupMultiRail(config.getsection('stepper_' + n))
            for n in 'xyz'
        ]
```

**Why?** Because kinematics need to know which steppers exist and how to use them.

### Custom Kinematics (like `winder`)

Your `winder` kinematics can load steppers differently:

```python
# klippy/kinematics/winder.py
class WinderKinematics:
    def __init__(self, toolhead, config):
        # Only load stepper_y (traverse)
        self.traverse_rail = stepper.LookupMultiRail(
            config.getsection('stepper_y')
        )
        
        # Don't load stepper_x or stepper_z
```

## Summary

1. **Config parsing**: `configfile.py` reads `printer.cfg` and handles includes
2. **Section discovery**: `klippy.py` finds all sections via `get_prefix_sections('')`
3. **Dynamic loading**: `load_object()` imports Python modules from `extras/` or `kinematics/`
4. **Module pattern**: Modules export `load_config()` or `load_config_prefix()` functions
5. **Object registration**: Created objects stored in `printer.objects[section_name]`
6. **Object lookup**: Other modules use `printer.lookup_object('section_name')` to find objects

## References

- `klippy/configfile.py` - Config parsing and validation
- `klippy/klippy.py` - Main printer object and object loading
- `klippy/stepper.py` - Stepper motor creation
- `klippy/kinematics/cartesian.py` - Example kinematics loading steppers
- `klippy/extras/winder.py` - Your custom module example

