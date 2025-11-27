# Angle Sensor Calibration Guide

## System Overview

The winder uses two sensors for spindle position tracking:
1. **Hall Sensor (hw_counter)**: Counts revolutions via magnet detection
2. **Angle Sensor**: Continuous position tracking (0-360°) via analog voltage

## Verified Specifications

### Hardware Configuration
- **MCU**: STM32G0B1 (Manta M4P)
- **ADC Resolution**: 12-bit (4096 steps)
- **Hall Sensor Pin**: PA15 (with pull-up)
- **Angle Sensor Pin**: PA1 (ADC input)
- **Hall Detection Mode**: Rising edge only (1 pulse per revolution)
- **Magnet Count**: 1 magnet on spindle

### Measured Performance (Nov 25, 2024)

#### Raw ADC Range
- **Minimum ADC**: 0.430037
- **Maximum ADC**: 0.966911
- **Span**: 0.536874 (53.69% of full ADC scale)
- **Usable Steps**: 4096 × 0.5369 = **2,199 distinct positions**
- **Resolution**: 2199 ÷ 360° = **6.1 steps per degree**

#### Hall Sensor Synchronization
- **Hall fires at angle**: 0.27° ± 2.49°
- **Repeatability**: ±2.5° (GOOD)
- **Test conditions**: 300 RPM, 1 layer (88 revolutions)
- **Hall pulse count**: 88 pulses
- **Accuracy**: 88 pulses vs 88.2 expected = **99.8% accurate**

#### ADC Statistics at Hall Pulses
- **Mean RAW ADC**: 0.680780
- **Std deviation**: 0.162418 (±23.86%)
- **Note**: High variation is NORMAL - hall fires at different angles each revolution due to independent sensor timing

## Configuration Settings

### Current Config (`printer-manta-m4p-modular.cfg`)

```cfg
[hw_counter]
pin: ^PA15           # Pull-up enabled for hall sensor
sample_time: 0.1     # Report interval (seconds)

[angle_sensor]
sensor_pin: PA1
max_angle: 360.0
sensor_vcc: 5.0
angle_auto_calibrate: True  # Auto-learn ADC range
saturation_threshold: 1.0   # Allow full range during calibration

[winder_control]
hall_sensor_correction: 1.0  # 1 pulse = 1 revolution (rising edge only)
```

## Calibration Procedure

### When to Calibrate
- After MCU firmware updates
- After mechanical changes to spindle/sensors
- If turn counting becomes inaccurate
- Recommended: Monthly verification

### Calibration Steps

1. **Start calibration logging**:
   ```
   gcode CALIBRATE_ANGLE_SENSOR ACTION=START
   ```

2. **Home traverse**:
   ```
   gcode G28 Y
   ```

3. **Run test winding** (at least 50 revolutions for good statistics):
   ```
   gcode WINDER_START RPM=300 LAYERS=1
   ```
   Wait for completion...

4. **Stop calibration and view results**:
   ```
   gcode CALIBRATE_ANGLE_SENSOR ACTION=STOP
   ```

5. **Extract results from log**:
   ```bash
   tail -500 /tmp/klippy.log | grep -A 80 'CALIBRATION RESULTS'
   ```

### What to Check

#### ✅ GOOD Results:
- **RAW ADC span**: 40-60% of full scale (0.4 - 0.6 range)
- **Angle at hall pulses**: Std dev < 5°
- **Hall pulse count**: Within ±2% of expected turns
- **ADC min/max**: Not hitting 0.0 or 1.0 (no saturation)

#### ❌ BAD Results (Action Required):
- **Angle std dev > 10°**: Check mechanical coupling, sensor mounting
- **ADC hitting 0.0 or 1.0**: Sensor saturated, check wiring/power
- **Hall count off by >5%**: Check `hall_sensor_correction` factor
- **ADC span < 30%**: Sensor may be damaged or misconfigured

## Calibration Data Analysis

### Resolution Calculation
```
Usable Steps = 4096 × ADC_Span
Steps per Degree = Usable_Steps ÷ 360
```

**Example** (from Nov 25, 2024 test):
```
Usable Steps = 4096 × 0.5369 = 2,199 steps
Steps per Degree = 2199 ÷ 360 = 6.1 steps/degree
```

### Hall Synchronization Check
The hall sensor should fire at a **consistent angle** (±5° or less).

**Why variation occurs**: The angle sensor and hall sensor sample at different rates, so the exact angle reading when the hall fires varies slightly. This is normal and expected.

**What matters**: The standard deviation should be low (<5°), indicating the sensors are mechanically synchronized.

## Troubleshooting

### Problem: Angle sensor shows 0 turns
**Cause**: ADC calibration range doesn't match actual sensor output
**Fix**: Enable `angle_auto_calibrate: True` and run calibration test

### Problem: Hall count is 2× expected
**Cause**: Firmware detecting both rising and falling edges
**Fix**: 
1. Verify `hw_counter.c` has `EXTI->FTSR1` line commented out
2. Recompile and flash firmware
3. Set `hall_sensor_correction: 1.0`

### Problem: High angle variation at hall pulses (>10°)
**Cause**: Mechanical slop, loose coupling, or sensor misalignment
**Fix**: Check physical mounting and mechanical connections

### Problem: ADC values stuck at one value
**Cause**: Sensor not rotating, broken sensor, or wiring issue
**Fix**: 
1. Verify motor is physically spinning spindle
2. Check sensor wiring and power
3. Test sensor with multimeter (should show changing voltage)

## Periodic Verification Script

### Quick Check (30 seconds)
```bash
# Run on CM4
gcode CALIBRATE_ANGLE_SENSOR ACTION=START
gcode WINDER_START RPM=300 LAYERS=1
# Wait for completion
gcode CALIBRATE_ANGLE_SENSOR ACTION=STOP
tail -100 /tmp/klippy.log | grep "RAW ADC:"
```

**Expected output**: `RAW ADC: 0.68 (±0.16) | Angle: 0.3° (±2.5°)`

### Full Calibration Report
```bash
# Extract full calibration results
tail -500 /tmp/klippy.log | grep -A 80 'CALIBRATION RESULTS' > ~/calibration_$(date +%Y%m%d_%H%M%S).txt
```

## Calibration History

| Date | ADC Min | ADC Max | Span | Angle Std Dev | Hall Count | Status |
|------|---------|---------|------|---------------|------------|--------|
| 2024-11-25 | 0.430 | 0.967 | 53.7% | ±2.49° | 88/88.2 | ✅ GOOD |

## Notes

- The angle sensor uses only ~54% of the ADC range - this is normal for this sensor type
- 6.1 steps per degree provides sufficient resolution for turn counting
- Hall sensor fires at ~0° (near the 360°→0° wrap-around point)
- Auto-calibration learns the ADC range dynamically during the first ~100 samples

## Related Files

- **Firmware**: `src/hw_counter.c` (MCU-side hall counter)
- **Python Module**: `klipper-install/extras/hw_counter.py` (host-side logging)
- **Angle Sensor**: `klipper-install/extras/angle_sensor.py` (ADC processing)
- **Config**: `config/printer-manta-m4p-modular.cfg` (system parameters)

