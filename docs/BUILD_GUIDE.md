# KLIPPER MINIMAL BUILD GUIDE
## Custom Motor Control System (CM4 + Pico + TMC2209)

---

## WHAT WE'RE BUILDING

**Architecture:**
```
CM4 (Python Control)  ←USB→  Pico (C Firmware - Klipper Timer Core + Custom Commands)
```

**Keeps from Klipper:**
- Event scheduler (sched.c/h)
- Command protocol (command.c/h)
- Timer system (timer.c, timer_irq.c)
- RP2040 hardware support

**Removes from Klipper:**
- ALL 3D printer code (stepper.c, kinematics, heaters, etc.)
- Python host (klippy/)

**Adds Custom:**
- custom_stepper.c (YOUR motor control)
- custom_encoder.c (YOUR encoder reading)
- config.h (YOUR pin/parameter definitions)

---

## FILE STRUCTURE

```
klipper-minimal/
├── src/
│   ├── sched.c              ✅ KEEP (Core scheduler)
│   ├── sched.h              ✅ KEEP
│   ├── command.c            ✅ KEEP (Command protocol)
│   ├── command.h            ✅ KEEP
│   ├── basecmd.c            ✅ KEEP (Basic commands)
│   ├── basecmd.h            ✅ KEEP
│   ├── compiler.h           ✅ KEEP (Macros)
│   ├── config.h             ✨ NEW (YOUR parameters)
│   ├── custom_stepper.c     ✨ NEW (YOUR motor)
│   ├── custom_encoder.c     ✨ NEW (YOUR encoder)
│   ├── board/
│   │   ├── irq.h            ✅ KEEP
│   │   ├── misc.h           ✅ KEEP
│   │   ├── io.h             ✅ KEEP
│   │   └── pgm.h            ✅ KEEP
│   ├── generic/
│   │   ├── timer_irq.c      ✅ KEEP
│   │   ├── timer_irq.h      ✅ KEEP
│   │   ├── armcm_boot.c     ✅ KEEP
│   │   └── armcm_boot.h     ✅ KEEP
│   └── rp2040/
│       ├── main.c           ✅ KEEP
│       ├── timer.c          ✅ KEEP (CRITICAL)
│       ├── gpio.c           ✅ KEEP
│       ├── gpio.h           ✅ KEEP
│       ├── usbserial.c      ✅ KEEP
│       ├── chipid.c         ✅ KEEP
│       ├── Makefile         ✅ KEEP
│       └── rp2040_link.lds  ✅ KEEP
├── Makefile                 ✅ KEEP (modified)
└── .config                  ✅ KEEP
```

**Total: ~25 core files + 3 custom files**

---

## STEP-BY-STEP BUILD

### Step 1: Get Klipper Source (On CM4)

```bash
cd ~
git clone https://github.com/Klipper3d/klipper klipper-full
cd klipper-full
```

### Step 2: Create Minimal Structure

```bash
cd ~
mkdir -p klipper-minimal/src/{board,generic,rp2040}
cd klipper-minimal
```

### Step 3: Copy Core Files

```bash
# From klipper-full to klipper-minimal:
cp ~/klipper-full/src/sched.{c,h} src/
cp ~/klipper-full/src/command.{c,h} src/
cp ~/klipper-full/src/basecmd.{c,h} src/
cp ~/klipper-full/src/compiler.h src/

# Board headers
cp ~/klipper-full/src/board/* src/board/

# Generic ARM
cp ~/klipper-full/src/generic/timer_irq.{c,h} src/generic/
cp ~/klipper-full/src/generic/armcm_boot.{c,h} src/generic/

# RP2040 specific
cp ~/klipper-full/src/rp2040/* src/rp2040/

# Build system
cp ~/klipper-full/Makefile .
```

### Step 4: Add Custom Files

Copy these 3 files from /tmp/klipper-minimal/src/:
- `config.h` → `src/config.h`
- `custom_stepper.c` → `src/custom_stepper.c`
- `custom_encoder.c` → `src/custom_encoder.c`

### Step 5: Modify Makefile

Edit `src/Makefile` and remove all 3D printer modules:

**DELETE these lines:**
```makefile
src-y += stepper.c endstop.c trsync.c
src-y += extruder.c heater.c pwm.c
src-y += kin_*.c
```

**ADD these lines:**
```makefile
src-y += custom_stepper.c custom_encoder.c
```

### Step 6: Build Configuration

```bash
make menuconfig
```

**Settings:**
- Micro-controller: `Raspberry Pi RP2040`
- Bootloader: `No bootloader`
- Communication: `USB`
- Clock: `125 MHz`

Save and exit.

### Step 7: Compile

```bash
make clean
make -j4
```

**Output:** `out/klipper.uf2`

### Step 8: Flash to Pico

```bash
# Hold BOOTSEL button on Pico
# Plug in USB
# Release BOOTSEL

# Copy firmware
cp out/klipper.uf2 /media/pi/RPI-RP2/
```

Pico reboots and appears as USB serial device.

---

## PYTHON HOST CODE

Simple Python control library (instead of full Klippy):

```python
# custom_control.py
import serial
import struct
import time

class CustomMotorController:
    def __init__(self, port='/dev/ttyACM0'):
        self.ser = serial.Serial(port, 250000)
        self.stepper_oid = 0
        self.encoder_oid = 1
        
        # Initialize objects
        self._send_command('allocate_oids', count=10)
        
        # Configure stepper
        self._send_command('config_custom_stepper',
            oid=self.stepper_oid,
            step_pin=STEP_PIN,
            dir_pin=DIR_PIN,
            enable_pin=ENABLE_PIN)
        
        # Configure encoder
        self._send_command('config_custom_encoder',
            oid=self.encoder_oid,
            pin_a=ENCODER_A_PIN,
            pin_b=ENCODER_B_PIN,
            pull_up=1)
    
    def enable_motor(self, enable=True):
        self._send_command('custom_stepper_enable',
            oid=self.stepper_oid,
            enable=1 if enable else 0)
    
    def move(self, steps, rpm):
        # Calculate interval from RPM
        steps_per_sec = (rpm * TOTAL_STEPS_PER_REV) / 60
        interval_us = 1000000 / steps_per_sec
        
        self._send_command('custom_stepper_move',
            oid=self.stepper_oid,
            direction=0,
            steps=steps,
            interval=int(interval_us))
    
    def get_position(self):
        self._send_command('custom_stepper_get_position',
            oid=self.stepper_oid)
        # Parse response...
    
    def _send_command(self, cmd, **params):
        # Implement Klipper protocol
        # (Simplified - actual implementation needs proper encoding)
        pass

# Usage:
motor = CustomMotorController()
motor.enable_motor(True)
motor.move(steps=16000, rpm=2500)  # 10 revolutions at max speed
```

---

## TESTING PROCEDURE

### Test 1: Communication

```bash
ls -l /dev/ttyACM0  # Pico should appear
```

### Test 2: Basic Commands

```python
# Send allocate_oids
# Send config commands
# Verify no errors
```

### Test 3: Slow Movement

```python
motor.move(steps=1600, rpm=100)  # 1 rev at slow speed
```

### Test 4: High Speed

```python
motor.move(steps=16000, rpm=2500)  # 10 rev at max speed
```

### Test 5: Encoder Tracking

```python
# Start encoder polling
# Move motor
# Verify encoder counts match expected
```

---

## NEXT STEPS

Once basic system working:

1. Add TMC2209 UART control
2. Add closed-loop position control
3. Add LCD update task (non-blocking)
4. Add speed ramping (acceleration/deceleration)
5. Build complete Python UI

---

## TROUBLESHOOTING

**Problem:** Won't compile
- Check all #include paths
- Verify all Kconfig dependencies

**Problem:** USB not recognized
- Check USB cable/port
- Reflash bootloader if needed

**Problem:** Motor doesn't move
- Check pin assignments in config.h
- Verify enable pin (active LOW!)
- Check TMC2209 orientation (DO NOT REVERSE!)

**Problem:** Encoder counts wrong
- Adjust poll_ticks (try 10-50µs)
- Check quadrature wiring (A/B not swapped)
- Verify pull-up resistors

---

## KEY DIFFERENCES FROM FULL KLIPPER

| Feature | Full Klipper | Your Build |
|---------|-------------|------------|
| Stepper control | kinematics, trapq | Simple timer-based |
| Commands | 100+ | 10 custom |
| Python host | Klippy (complex) | Simple serial lib |
| Configuration | printer.cfg | config.h |
| Size | ~500KB | ~50KB |
| 3D printer code | YES | NO |
| Your motor/encoder | NO | YES |

---

## SUPPORT FILES LOCATION

All files created in: `/tmp/klipper-minimal/`

- config.h
- custom_stepper.c  
- custom_encoder.c
- This guide

Copy to CM4 and start building!
