# Winder Kinematics C Helper (`kin_winder.c`)

## Overview

The `kin_winder.c` file provides a custom C helper for the winder kinematics, enabling optimized position calculations for the traverse (Y-axis) stepper synchronized with spindle rotation.

## Why a Custom C Helper?

Unlike simple cartesian movement, the winder requires:

1. **Synchronized Movement**: Traverse (Y-axis) must move in sync with spindle rotation
2. **Gear Ratio Calculations**: Motor-to-spindle gear ratio (40:60 = 0.667)
3. **Wire Length per Turn**: Depends on bobbin diameter, wire diameter, layer number
4. **Turns per Layer**: Depends on bobbin width and wire diameter
5. **Performance**: C-level calculations for real-time synchronization

## Current Implementation

The initial implementation (`kin_winder.c`) provides:

- **Basic Y-axis position calculation**: Currently identical to cartesian Y-axis
- **Structure for future enhancements**: `winder_stepper` struct ready for expansion
- **Y-axis only**: Enforces that only Y-axis is supported (traverse)

## Future Enhancements

The `winder_stepper` struct is structured to support future additions:

```c
struct winder_stepper {
    struct stepper_kinematics sk;
    // Future parameters:
    // double gear_ratio;           // Motor:Spindle gear ratio (e.g., 0.667)
    // double wire_diameter;          // Wire diameter in mm (e.g., 0.056 for 43AWG)
    // double bobbin_diameter;        // Current bobbin diameter (changes with layers)
    // double current_layer;          // Current layer number
};
```

### Potential Future Features:

1. **Real-time Spindle RPM Feedback**: Access spindle rotation data in C for tighter synchronization
2. **Dynamic Speed Adjustment**: Adjust traverse speed based on measured spindle RPM
3. **Wire Length Tracking**: Calculate wire length per turn in C for performance
4. **Layer-aware Calculations**: Account for changing bobbin diameter as layers build up

## Integration

### Files Modified:

1. **`klippy/chelper/kin_winder.c`**: New C helper file
2. **`klippy/chelper/__init__.py`**: 
   - Added `kin_winder.c` to `SOURCE_FILES`
   - Added `defs_kin_winder` function definitions
   - Added to `defs_all` list
3. **`klipper-install/kinematics/winder.py`**: 
   - Changed from `cartesian_stepper_alloc` to `winder_stepper_alloc`

### Compilation:

The C helper is automatically compiled into `c_helper.so` when Klipper starts. The Python code will rebuild it if `kin_winder.c` or `__init__.py` changes.

## Usage

The winder kinematics Python code calls:

```python
self.rail.setup_itersolve('winder_stepper_alloc', b'y')
```

This allocates a `winder_stepper` structure and sets up the Y-axis position calculation callback.

## Synchronization Architecture

Currently, synchronization happens at the Python level:

1. **`winder_control.py`**: Calculates traverse speed based on target spindle RPM
2. **G-code Commands**: Creates moves with calculated traverse speed
3. **Toolhead**: Plans moves with synchronized speeds
4. **C Helper**: Calculates Y position from planned moves

Future enhancement could add:
- Real-time spindle RPM feedback in C layer
- Dynamic adjustment of traverse position based on actual spindle rotation
- Tighter synchronization than Python-level planning allows

## Notes

- The C helper's `calc_position` function is called during step generation
- It receives a `struct move *m` with the planned trajectory
- The move already has synchronized speeds calculated by Python
- Future enhancements could access spindle rotation data directly in C

