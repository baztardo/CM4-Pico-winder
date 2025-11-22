# Pin Reference - MP8 vs M4P

## Pin Differences Between Boards

### Spindle Hall Sensor
- **MP8:** PF6
- **M4P:** PC15 ✅

### Angle Sensor
- **MP8:** PB2 (or PA0/TH0)
- **M4P:** PA1 (BLTouch SERVOS port) ✅

### Traverse (Y-Axis)
- **MP8:** PF12 (STEP), PF11 (DIR), PF3 (ENDSTOP), PF13 (TMC2209 UART)
- **M4P:** PF12 (STEP), PF11 (DIR), PF3 (ENDSTOP), PF13 (TMC2209 UART) ✅ (Same)

### BLDC Motor (E0 Header)
- **MP8:** PB3 (STEP/PWM), PB4 (DIR), PD5 (ENA/Brake)
- **M4P:** PB3 (STEP/PWM), PB4 (DIR), PD5 (ENA/Brake) ✅ (Same)

## M4P Pin Assignments

### Spindle Hall Sensor
- **Pin:** PC15
- **Type:** Digital input (pulse counter)
- **Pull-up:** Recommended (use `^PC15` in config)
- **Function:** 1 pulse per revolution

### Angle Sensor
- **Pin:** PA1 (BLTouch SERVOS port)
- **Type:** ADC input
- **Voltage:** 0-5V (requires voltage divider for safety)
- **Function:** 0-360° position tracking

### Traverse Stepper (Y-Axis)
- **Step:** PF12
- **Dir:** PF11
- **Enable:** PB3 (inverted)
- **Endstop:** PF3
- **TMC2209 UART:** PF13

### BLDC Motor (E0 Header)
- **PWM (Step):** PB3
- **DIR:** PB4
- **Brake (ENA):** PD5
- **Power:** PB7 (Bed heater port, optional)

## Configuration Examples

### M4P Configuration
```cfg
[spindle_hall]
hall_pin: PC15    # M4P pin

[angle_sensor]
sensor_pin: PA1   # BLTouch SERVOS port
```

### MP8 Configuration (for reference)
```cfg
[spindle_hall]
hall_pin: PF6     # MP8 pin

[angle_sensor]
sensor_pin: PB2   # MP8 pin (or PA0/TH0)
```

## Notes

- **PF6** is correct for **MP8** board
- **PC15** is correct for **M4P** board
- Always verify pin assignments match your specific board version
- Check board schematic/manual for pin availability

