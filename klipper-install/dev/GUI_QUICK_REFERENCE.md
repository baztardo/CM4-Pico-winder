# Winder GUI Quick Reference

## Technology Stack

- **Framework:** KlipperScreen (Python/Kivy)
- **API:** Moonraker (HTTP REST + WebSocket)
- **Backend:** Klipper (winder modules)

## G-code Commands Available

### Winding Control
```gcode
WINDER_START RPM=1000 LAYERS=5 DIRECTION=forward
WINDER_STOP
WINDER_SET_RPM RPM=1500
QUERY_WINDER
```

### BLDC Motor
```gcode
BLDC_START RPM=1500 DIRECTION=forward POWER=1
BLDC_STOP
BLDC_SET_RPM RPM=2000
BLDC_SET_DIR DIRECTION=reverse
BLDC_SET_BRAKE ENGAGE=1
QUERY_BLDC
```

### Traverse
```gcode
TRAVERSE_HOME
TRAVERSE_MOVE POS=50 SPEED=10
QUERY_TRAVERSE
```

### Angle Sensor
```gcode
QUERY_ANGLE_SENSOR
ANGLE_SENSOR_CALIBRATE ACTION=RESET
ANGLE_SENSOR_CALIBRATE ACTION=MANUAL MIN=0.04 MAX=1.0
```

### Spindle Hall
```gcode
QUERY_SPINDLE_HALL
```

## Moonraker API Endpoints

### Status Query
```http
GET /api/printer/objects/query?winder_control&bldc_motor&angle_sensor&spindle_hall&traverse
```

### Send G-code
```http
POST /api/printer/gcode/script
Content-Type: application/json
{"script": "WINDER_START RPM=1000 LAYERS=5"}
```

### WebSocket Subscribe
```json
{
    "jsonrpc": "2.0",
    "method": "printer.objects.subscribe",
    "params": {
        "objects": {
            "winder_control": None,
            "bldc_motor": None,
            "angle_sensor": None,
            "spindle_hall": None,
            "traverse": None
        }
    },
    "id": 5434
}
```

## Status Object Structure

### winder_control
```python
{
    "is_winding": bool,
    "spindle_rpm_target": float,
    "spindle_rpm_measured": float,
    "current_layer": int,
    "wire_diameter": float,
    "bobbin_width": float,
    "gear_ratio": float
}
```

### bldc_motor
```python
{
    "is_running": bool,
    "current_rpm": float,
    "target_rpm": float,
    "direction_forward": bool,
    "brake_engaged": bool,
    "power_on": bool
}
```

### angle_sensor
```python
{
    "current_angle_deg": float,
    "current_angle_rad": float,
    "measured_rpm": float,
    "revolutions": int,
    "is_saturated": bool,
    "adc_min": float,
    "adc_max": float,
    "calibration_complete": bool
}
```

### spindle_hall
```python
{
    "measured_rpm": float,
    "current_count": int,
    "frequency": float
}
```

### traverse
```python
{
    "is_homed": bool,
    "current_position": float,
    "max_position": float,
    "home_offset": float,
    "max_velocity": float
}
```

## UI Components Needed

### Display Widgets
- RPM Gauge (circular or linear)
- Angle Display (0-360°)
- Turn Counter (large number)
- Progress Bar (layer/turn progress)
- Status LEDs (running, error, ready)

### Control Widgets
- Start Button (large, prominent)
- Stop Button (emergency red)
- Pause Button
- RPM Input (numeric keypad)
- Layers Input
- Turns Input

### Navigation
- Main Screen
- Setup Screen
- History Screen
- Settings Screen
- Diagnostics Screen

## Color Scheme

- **Primary:** Blue (Klipper standard)
- **Success/Active:** Green
- **Warning:** Yellow/Orange
- **Error/Stop:** Red
- **Background:** Dark (for touchscreen visibility)
- **Text:** White/Light Gray

## Screen Sizes

- **Minimum:** 800x480 (standard KlipperScreen)
- **Optimal:** 1024x600 (better for complex UI)
- **Touch Targets:** Minimum 48x48px

## Development Checklist

- [ ] Set up KlipperScreen development environment
- [ ] Create custom theme structure
- [ ] Implement Moonraker client
- [ ] Create main panel
- [ ] Add status display widgets
- [ ] Add control buttons
- [ ] Implement setup panel
- [ ] Add job management
- [ ] Test with hardware
- [ ] Polish UI/UX

