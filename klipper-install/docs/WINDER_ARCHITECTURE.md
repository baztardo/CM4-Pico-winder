# CNC Winder Architecture Guide

## 📍 **Where's the "Main Loop"?**

### **Answer: There Isn't One! Klipper is Event-Driven**

Traditional embedded firmware has a main loop:
```c
void main() {
    while(1) { /* loop forever */ }
}
```

**Klipper doesn't work this way.** Instead:

```
┌─────────────────────────────────────────────┐
│  Host (Raspberry Pi / CM4)                  │
│  ┌────────────────────────────────────────┐ │
│  │  klippy/reactor.py                     │ │
│  │  ↓ Event loop (select/epoll)           │ │
│  │  ↓ Processes events as they arrive     │ │
│  │                                         │ │
│  │  klippy/toolhead.py                    │ │
│  │  ↓ Plans motion                        │ │
│  │                                         │ │
│  │  klippy/extras/winder.py ← YOUR CODE   │ │
│  │  ↓ Custom winding logic                │ │
│  └────────────────────────────────────────┘ │
│                    ↓ USB/Serial              │
└───────────────────────────────────────────┬─┘
                                            │
┌───────────────────────────────────────────┴─┐
│  MCU (STM32/RP2040)                         │
│  ┌────────────────────────────────────────┐ │
│  │  src/sched.c                           │ │
│  │  ↓ Timer-driven scheduler              │ │
│  │                                         │ │
│  │  src/stepper.c                         │ │
│  │  ↓ Executes steps at precise times     │ │
│  └────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

---

## 🏗️ **Where to Put YOUR Code**

### **✅ Configuration (Variables & Pins) - NO HARDCODING!**

**File: `printer.cfg`** (your config file)
```ini
[winder]
wire_diameter: 0.056      # ← Variables go here
spindle_pwm_pin: PA4      # ← Pin assignments here
bobbin_width: 12.0
# etc...
```

**Why this way?**
- ✅ Board-agnostic (change pins without recompiling)
- ✅ Easy to modify without programming
- ✅ Multiple configs for different boards

### **✅ Custom Logic**

**File: `klippy/extras/winder.py`** (we just created this)
- Your winding algorithms
- Spindle synchronization
- Hall sensor reading
- Custom G-code commands

---

## 🎛️ **How Your Winder Works**

### **1. Initialization (Startup)**

```
1. Klipper reads printer.cfg
   ↓
2. Loads [winder] section
   ↓
3. Calls winder.py → __init__()
   ↓
4. Sets up pins, registers commands
   ↓
5. Ready for operation!
```

### **2. Operation (Event-Driven)**

```
User: "HOME_TRAVERSE"
   ↓
G-code → gcode.py → winder.py
   ↓
Winder calculates home sequence
   ↓
Sends commands to stepper
   ↓
MCU executes steps
   ↓
Done! (event complete)
```

**No continuous loop needed!**

### **3. Emergency Stop (FAST Response)**

```
E-stop button pressed
   ↓
Hardware interrupt (MCU level)
   ↓
Immediate MCU shutdown
   ↓
NO Python code delay! ← CRITICAL FOR SAFETY
```

---

## 📦 **Keeping Modularity for Multiple Boards**

### **Method 1: Config Files (Recommended)**

Create separate configs for each board:

```
config/
  ├── winder-manta-mp4.cfg    ← Manta MP4 pins
  ├── winder-skr-pico.cfg     ← SKR-Pico pins
  ├── winder-nucleo.cfg       ← Nucleo pins
  └── winder-common.cfg       ← Shared settings
```

**Example: winder-manta-mp4.cfg**
```ini
[include winder-common.cfg]  # Shared config

[stepper_x]
step_pin: PA0   # Manta MP4 specific
dir_pin: PA1
enable_pin: !PA2

[winder]
spindle_pwm_pin: PA4
# ...
```

**Example: winder-skr-pico.cfg**
```ini
[include winder-common.cfg]  # Same shared config

[stepper_x]
step_pin: gpio11  # SKR-Pico specific (RP2040)
dir_pin: gpio10
enable_pin: !gpio12

[winder]
spindle_pwm_pin: gpio6
# ...
```

### **Method 2: Pin Aliases (Advanced)**

```ini
[board_pins]
aliases:
    # Traverse stepper
    TRAVERSE_STEP=PA0,
    TRAVERSE_DIR=PA1,
    TRAVERSE_EN=PA2,
    # Spindle
    SPINDLE_PWM=PA4,
    SPINDLE_DIR=PA5

[stepper_x]
step_pin: TRAVERSE_STEP  # Uses alias
```

---

## 🔧 **Your Specific Requirements - Implementation**

### **1. Traverse Carriage**

```ini
[stepper_x]
rotation_distance: 6.0      # 6mm lead screw
position_min: 0
position_max: 93            # 125mm - 32mm carriage
homing_retract_dist: 2.0    # Back off from home switch
```

**Homing Sequence (automatic):**
1. Move to home switch
2. Trigger endstop
3. Back off 2mm
4. Move to start position (50mm)

### **2. Spindle Sync Calculation**

In `winder.py`:
```python
def calculate_traverse_speed(self, spindle_rpm, wire_diameter):
    # For each revolution, move one wire diameter
    revs_per_second = spindle_rpm / 60.0
    traverse_speed = revs_per_second * wire_diameter
    return traverse_speed
```

**Example:**
- Spindle: 100 RPM
- Wire: 0.056mm (43 AWG)
- Traverse speed: (100/60) × 0.056 = 0.093 mm/s

### **3. Hall Sensor (Spindle Feedback)**

```ini
[pulse_counter spindle_hall]
pin: ^PA7
poll_time: 0.100  # Read every 100ms
```

**In your code:**
```python
# Read current pulse count
hall_counter = self.printer.lookup_object('pulse_counter spindle_hall')
pulses = hall_counter.get_status()['counts']

# Calculate RPM
rpm = (pulses / time_elapsed) * 60.0
```

### **4. Emergency Stop (Hardware Level)**

```ini
[emergency_stop]
pin: ^!PC15  # Active low, pullup resistor
```

**This triggers MCU-level shutdown - NO software delay!**

### **5. BLDC Motor Control**

```ini
[winder]
spindle_pwm_pin: PA4    # Speed (PWM)
spindle_dir_pin: PA5    # Direction (sink to GND)
spindle_brake_pin: PA6  # Brake (HIGH = stop)
```

**Direction control:**
- `DIR = LOW` → Forward
- `DIR = HIGH` → Reverse (sink to GND)

**Brake control:**
- `BRAKE = LOW` → Run
- `BRAKE = HIGH` → Stop

### **6. Wire Size Changes**

```gcode
CHANGE_WIRE DIAMETER=0.056  # 43 AWG
CHANGE_WIRE DIAMETER=0.071  # 42 AWG
CHANGE_WIRE DIAMETER=0.089  # 41 AWG
```

All calculations automatically adjust!

---

## 📊 **Data Flow**

### **Complete Winding Cycle:**

```
1. User: START_WINDING RPM=150 LAYERS=5
   ↓
2. winder.py receives command
   ↓
3. Calculate traverse speed from RPM + wire diameter
   ↓
4. Set spindle PWM (speed control)
   ↓
5. Start synchronized traverse motion
   ↓
6. Hall sensor monitors spindle RPM
   ↓
7. Adjust traverse speed if RPM changes
   ↓
8. Complete layer, reverse direction
   ↓
9. Repeat for specified layers
   ↓
10. DONE!
```

---

## 🎮 **Available G-code Commands**

```gcode
# Homing
HOME_TRAVERSE                    # Home and move to start

# Winding control
START_WINDING RPM=100 LAYERS=1  # Start winding
STOP_WINDING                     # Stop winding

# Configuration
CHANGE_WIRE DIAMETER=0.056      # Set wire diameter
SET_SPINDLE_SPEED RPM=200       # Manual spindle control

# Status
STATUS                           # Report winder state
WINDER_STATUS                    # Detailed status
```

---

## 🚀 **Next Steps**

1. **Pick your board** (Manta MP4, SKR-Pico, etc.)
2. **Edit `printer.cfg`** with correct pin assignments
3. **Test homing** sequence
4. **Test spindle** control (PWM/DIR/BRAKE)
5. **Test hall sensor** reading
6. **Fine-tune** synchronization
7. **Add web GUI** later

---

## 📝 **Important Notes**

### **No Hardcoding!**
All hardware-specific stuff goes in `printer.cfg`, NOT in Python code!

### **Emergency Stop**
The E-stop button must be hardware-level for safety. It directly triggers MCU shutdown.

### **TMC2209 UART**
Your TMC2209 config handles current limiting, StealthChop, etc. No manual tuning needed!

### **Multiple Boards**
Just create different `.cfg` files - Python code stays the same!

---

## 🐛 **Debugging**

### **Check stepper movement:**
```gcode
G28 X           # Home traverse
G1 X50 F1000    # Move to position 50mm at 1000mm/min
```

### **Check spindle:**
```gcode
SET_SPINDLE_SPEED RPM=50  # Slow speed test
SET_SPINDLE_SPEED RPM=0   # Stop
```

### **Monitor status:**
```gcode
STATUS  # Real-time info
```

---

## 📚 **Key Files Reference**

| What | Where | Purpose |
|------|-------|---------|
| **Your config** | `printer.cfg` | All settings, pins, values |
| **Winder logic** | `klippy/extras/winder.py` | Custom algorithms |
| **Event loop** | `klippy/reactor.py` | Core (don't modify) |
| **Motion** | `klippy/toolhead.py` | Planner (don't modify) |
| **MCU scheduler** | `src/sched.c` | Timer events (don't modify) |
| **Stepper control** | `src/stepper.c` | Step execution (don't modify) |

**YOU ONLY MODIFY:** `winder.py` and `printer.cfg`!

