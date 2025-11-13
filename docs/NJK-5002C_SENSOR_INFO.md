# NJK-5002C Hall Sensor Configuration

## Sensor Specifications

**Model:** NJK-5002C  
**Type:** NPN NO (Normally Open)  
**Supply Voltage:** 5-30VDC  
**Detection Distance:** 10mm (effective 0-10mm)  
**Output:** NPN three-wire, normally open (NO)  
**Load Current:** 150mA max  
**Thread:** M12 x 32mm

## How NPN NO Sensors Work

**NPN NO (Normally Open) Behavior:**
- **No magnet detected:** Output is **open/floating** (high impedance)
- **Magnet detected:** Output **pulls LOW** (sinks to GND)
- **Never drives HIGH** - only pulls LOW or floats

## Safe for 3.3V GPIO

✅ **These sensors are SAFE for 3.3V GPIO pins** because:
- They never drive the pin HIGH with 5V
- They only pull LOW (to GND) or float
- Need pull-up resistor to read properly

## Configuration

**In `printer.cfg`:**
```ini
[winder]
motor_hall_pin: ^gpio4      # ^ = internal pull-up to 3.3V
spindle_hall_pin: ^gpio22   # ^ = internal pull-up to 3.3V
```

**Pin Syntax:**
- `^gpio4` = Pull-up to 3.3V (correct for NPN NO)
- `~gpio4` = Pull-down to GND (wrong for NPN NO)
- `gpio4` = Default (usually pull-up, but explicit is better)

## Wiring

**3-Wire NPN NO Sensor:**
1. **Red/Brown:** VCC (5-30VDC) - Power supply positive
2. **Black/Blue:** GND - Power supply negative  
3. **Yellow/White:** Signal output - Connect to GPIO pin

**Connection:**
```
Sensor VCC → 5V (or 12V/24V if available)
Sensor GND → GND (common ground with SKR Pico)
Sensor Signal → GPIO pin (gpio4 or gpio22)
GPIO pin → Internal pull-up to 3.3V (via ^ in config)
```

## Reading the Signal

**Logic:**
- **No magnet:** GPIO reads HIGH (pulled up to 3.3V)
- **Magnet present:** GPIO reads LOW (sensor pulls to GND)

**Pulse Counter:**
- Counts edges (LOW→HIGH and HIGH→LOW transitions)
- Each transition = one pulse
- Frequency = pulses per second = RPM calculation

## Troubleshooting

**If MCU shuts down:**
- Check for external pull-up to 5V (remove it)
- Verify sensor is powered correctly
- Check wiring (signal, VCC, GND)
- Verify sensor is actually NPN NO (not PNP)

**If no signal:**
- Check sensor power (5-30VDC)
- Verify pull-up is configured (`^` in pin name)
- Test sensor with multimeter (should pull LOW when magnet present)
- Check wiring connections

**If wrong readings:**
- Verify sensor type (should be NPN NO)
- Check if sensor is normally open (NO) vs normally closed (NC)
- Verify pull-up configuration

## Safety Notes

⚠️ **DO NOT:**
- Connect sensor VCC to GPIO pin (will damage MCU)
- Use external pull-up to 5V (use internal 3.3V pull-up)
- Reverse VCC and GND (will damage sensor)

✅ **SAFE:**
- Internal pull-up to 3.3V (via `^` in config)
- Sensor only pulls LOW, never drives HIGH
- Common ground between sensor and MCU


