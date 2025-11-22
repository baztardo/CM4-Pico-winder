# Hardware Specifications

## BLDC Motor

### Motor Specifications
- **Size:** Nema 17
- **Type:** 3-phase, 24V
- **Poles:** 8
- **Max RPM:** 3000 RPM (motor)
- **Max Spindle RPM:** 2000 RPM (after gear reduction)

### Control Interface
- **PWM (P):** 2.5-5V, Frequency: 1kHz-20kHz
- **DIR:** Active when LOW level (change direction)
- **BRAKE:** Active HIGH (brake engaged)
- **SC:** Speed pulse output interface

### Gear Ratio
- **Motor Gear:** 40T timing gear
- **Spindle Gear:** 60T timing gear
- **Ratio:** 40:60 = 0.667 (motor:spindle)
- **Belt:** 6mm x 300mm
- **Calculation:**
  - Spindle RPM = Motor RPM × 0.667
  - Motor RPM = Spindle RPM / 0.667
  - Example: 1000 RPM spindle → 1500 RPM motor

## Hall Sensor (Spindle RPM Tracking)

### Specifications
- **Type:** Magnetic Hall Effect proximity sensor, NPN NO
- **Voltage:** 5-30VDC
- **Effective Distance:** 0-10mm
- **Output:** 1 pulse per revolution
- **Function:**
  - Track rotation revolution for RPM
  - Track turn counts
  - Primary sensor for RPM measurement

### Pin Assignment
- **M4P Pin:** PC15
- **Connection:** Direct to MCU (with pull-up)

## Angle Sensor (P3022-V1-CW360)

### Specifications
- **Rotation:** 360°
- **Power:** 5VDC @ 16mA
- **Resolution:** 360°/4096 ≈ 0.088° per step
- **Update Speed:** ~0.6ms
- **Output Signal:** Analog 0-5V (12-bit ADC)
- **Load Resistance:** >10kΩ
- **Gear Ratio:** 20T:20T (1:1 ratio to spindle)
- **Belt:** 6mm x 200mm

### Function
- Track location of spindle (0-360°)
- Used for traverse sync
- Track length of copper wire wound
- Calibrate length of wire per turn
- Can be used with Hall sensor for precise position tracking

### Pin Assignment
- **M4P Pin:** PA1 (BLTouch SERVOS port)
- **Connection:** Direct to MCU ADC
- **Voltage Protection:** Requires voltage divider (10K/22K) + zener clamp (3.6V)

### Saturation Handling
- Sensor may saturate at high end (ADC ≥ 0.99)
- Software uses Hall sensor to track revolutions during saturation
- Auto-calibration maps observed range to 0-360°

## Traverse Carriage

### Carriage Specifications
- **Size:** 32mm x 32mm
- **Function:** Guide copper wire onto bobbin
- **Wire:** 43 AWG copper wire (coated)
- **Bobbin Width:** Average 12mm wide
- **Travel:** 102mm linear movement

### Stepper Motor (Nema 11)
- **Holding Torque:** 6N·cm
- **Current:** 0.6A
- **Resistance:** 5.5Ω
- **Inductance:** 3.2mH
- **Speed Range:** 0-120mm/s
- **Step Angle:** 1.8°

### Lead Screw
- **Diameter:** 6mm
- **Pitch:** 1.0mm
- **Rotation Distance:** 1.0mm per revolution

### Homing
- **Home Switch:** Y-Stop (PF3)
- **Home Procedure:**
  1. Move to home switch
  2. Back off 5mm
  3. Move to start position:
     - Start offset
     - + Bobbin edge thickness
     - + Carriage edge to wire guide offset

### Driver
- **Type:** TMC2209
- **UART Pin:** PF13
- **Step Pin:** PF12
- **Dir Pin:** PF11
- **Enable Pin:** PB3 (inverted)

## Control Board (Manta M4P)

### Specifications
- **Power Supply:** 24V
- **Host:** CM4 (Compute Module 4)
- **MCU:** STM32G0B0RE, 32-bit ARM Cortex-M0+ @ 64MHz

### Pin Assignments

#### Traverse (Y-Axis)
- **Step:** PF12
- **Dir:** PF11
- **Enable:** PB3 (inverted)
- **Endstop:** PF3
- **TMC2209 UART:** PF13

#### BLDC Motor (E0 Header)
- **PWM (Step):** PB3 (E0 STEP)
- **DIR:** PB4 (E0 DIR)
- **Brake (ENA):** PD5 (E0 ENA)
- **Power:** PB7 (Bed heater port)

#### Sensors
- **Angle Sensor:** PA1 (BLTouch SERVOS port)
- **Hall Sensor:** PC15 (Spindle Hall)

#### Display
- **Type:** 5" Touch Screen
- **Interfaces:** HDMI, SPI, USB

## Wire Specifications

### 43 AWG Copper Wire
- **Diameter:** 0.056mm
- **Type:** Coated copper wire
- **Usage:** Primary wire gauge for pickup winding

### Other Gauges
- Popular gauge choices available
- Configurable via `wire_diameter` parameter

## Winding Parameters

### Turn Count Range
- **Minimum:** 2,500 turns
- **Maximum:** 10,000 turns
- **Typical Ranges:**
  - Single coil: 5,000-8,000 turns
  - Humbucker: 5,000-7,000 turns per coil
  - P90: 10,000+ turns
  - Rail: Variable

### Traverse Speed Calculation
- **Formula:** `traverse_speed (mm/s) = (spindle_rpm / 60) × wire_diameter (mm)`
- **Example:** 1000 RPM spindle, 0.056mm wire
  - `traverse_speed = (1000 / 60) × 0.056 = 0.933 mm/s`

### Bobbin Specifications
- **Width:** 12mm (average)
- **Edge Thickness:** Measured per bobbin
- **Start Offset:** Configurable (default: 38mm)

## Safety Features

### Motor Control
- Emergency stop capability
- Motor brake control (active HIGH)
- Power control (optional)
- Shutdown handling

### Traverse Control
- Endstop protection
- Position limits (0-93mm)
- Homing requirement before movement

### Sensor Protection
- Angle sensor voltage divider (10K/22K)
- Zener clamp (3.6V) for overvoltage protection
- Hall sensor pull-up protection

## Truth Table: Motor Phase

*(To be filled in with actual motor phase truth table)*

## References

- Manta M4P User Manual
- Manta M4P Schematic
- P3022-V1-CW360 Angle Sensor Datasheet
- TMC2209 Driver Datasheet
- Klipper Documentation

