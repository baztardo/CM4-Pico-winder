# Coil Winding Workflow Guide

## 🎯 Overview - From Design to Wound Coil

This guide shows you the complete workflow for winding coils, similar to the 3D printing workflow (CAD → Slicer → G-code → Print).

```
┌────────────────────────────────────────────────────────┐
│  STEP 1: Define Coil Specification                    │
│  • Wire gauge (AWG) / diameter (mm)                   │
│  • Bobbin dimensions                                  │
│  • Number of layers                                   │
│  • Winding speed (RPM)                                │
└────────────────┬───────────────────────────────────────┘
                 ↓
┌────────────────────────────────────────────────────────┐
│  STEP 2: Generate G-code (like slicing)               │
│  • Use coil_generator.py                              │
│  • Or use Excel template                              │
│  • Or write manual G-code for testing                 │
└────────────────┬───────────────────────────────────────┘
                 ↓
┌────────────────────────────────────────────────────────┐
│  STEP 3: Upload to Klipper                            │
│  • Via Mainsail/Fluidd web interface                  │
│  • Or via scp command                                 │
└────────────────┬───────────────────────────────────────┘
                 ↓
┌────────────────────────────────────────────────────────┐
│  STEP 4: Wind the Coil                                │
│  • Click "Print" in Mainsail                          │
│  • Monitor progress                                   │
│  • Wait for completion                                │
└────────────────┬───────────────────────────────────────┘
                 ↓
┌────────────────────────────────────────────────────────┐
│  STEP 5: Remove Finished Coil                         │
│  ✅ Coil ready!                                        │
└────────────────────────────────────────────────────────┘
```

---

## 📦 Method 1: Python Script (Recommended)

### **Prerequisites**

```bash
# On your Mac or CM4
python3 --version  # Should be Python 3.6+
```

### **Quick Start**

```bash
# Navigate to scripts directory
cd /Users/ssnow/Documents/GitHub/CM4-Pico-winder/scripts

# Generate a test coil (5 layers)
python3 coil_generator.py \
  --wire 0.056 \
  --bobbin 12 \
  --layers 5 \
  --rpm 100 \
  --output test_5layer.gcode

# Generate a production coil (50 layers)
python3 coil_generator.py \
  --wire 0.056 \
  --bobbin 12 \
  --layers 50 \
  --rpm 200 \
  --output pickup_coil.gcode
```

### **Parameters Explained**

| **Parameter** | **Description** | **Example** |
|---------------|-----------------|-------------|
| `--wire` | Wire diameter in mm | `0.056` (43 AWG) |
| `--bobbin` | Bobbin width in mm | `12` |
| `--layers` | Number of layers to wind | `50` |
| `--rpm` | Spindle speed in RPM | `200` |
| `--start` | Start position (optional) | `38.0` (default) |
| `--pattern` | Winding pattern (optional) | `simple` (default) |
| `--output` | Output G-code file | `my_coil.gcode` |

### **Common Wire Gauges**

| **AWG** | **Diameter (mm)** | **Diameter (inches)** |
|---------|-------------------|----------------------|
| 42 | 0.0630 | 0.00248 |
| 43 | 0.0560 | 0.00220 |
| 44 | 0.0500 | 0.00197 |
| 45 | 0.0445 | 0.00175 |

---

## 📤 Method 2: Upload to Klipper

### **Option A: Via Mainsail Web Interface (Easiest)**

1. Open Mainsail in browser: `http://winder.local`
2. Click **"Files"** → **"G-code Files"**
3. Click **"Upload"** button
4. Select your `.gcode` file
5. Click on the file name → **"Print"**
6. Monitor progress in dashboard

### **Option B: Via SCP Command**

```bash
# From your Mac, upload G-code
scp test_5layer.gcode winder@winder.local:~/gcodes/

# Then in Mainsail:
# - Navigate to Files
# - Click on the file
# - Click "Print"
```

### **Option C: Directly on CM4**

```bash
# SSH to CM4
ssh winder@winder.local

# Generate G-code directly on CM4
cd ~/klipper/scripts
python3 coil_generator.py \
  --wire 0.056 \
  --bobbin 12 \
  --layers 10 \
  --rpm 150 \
  --output ~/gcodes/my_coil.gcode

# File automatically appears in Mainsail!
```

---

## 🎮 Method 3: Quick Wind Macros (Fast!)

Add these macros to your `printer.cfg`:

```ini
#=====================================================
# QUICK WIND MACROS
#=====================================================

[gcode_macro WIND_TEST]
description: Wind a quick 5-layer test coil
gcode:
    G28 Y              ; Home
    G92 E0             ; Reset E
    G1 Y38 F1000       ; Move to start
    
    ; Wind 5 layers (60mm total E)
    G1 Y50 E12 F336    ; Layer 1 (→)
    G1 Y38 E24 F336    ; Layer 2 (←)
    G1 Y50 E36 F336    ; Layer 3 (→)
    G1 Y38 E48 F336    ; Layer 4 (←)
    G1 Y50 E60 F336    ; Layer 5 (→)
    
    M118 Test complete!
    G1 Y38 F1000       ; Return

[gcode_macro WIND_PICKUP_50]
description: Wind a standard 50-layer pickup coil
gcode:
    M118 Starting 50-layer pickup coil...
    RUN_SHELL_COMMAND CMD=generate_pickup_50
    SDCARD_PRINT_FILE FILENAME=pickup_50.gcode

[gcode_shell_command generate_pickup_50]
command: python3 ~/klipper/scripts/coil_generator.py --wire 0.056 --bobbin 12 --layers 50 --rpm 200 --output ~/gcodes/pickup_50.gcode
timeout: 10.0

[gcode_macro WIND_CUSTOM]
description: Wind custom coil
gcode:
    {% set layers = params.LAYERS|default(10)|int %}
    {% set rpm = params.RPM|default(150)|int %}
    
    M118 Generating {layers}-layer coil at {rpm} RPM...
    RUN_SHELL_COMMAND CMD=generate_custom PARAMS="--wire 0.056 --bobbin 12 --layers {layers} --rpm {rpm} --output ~/gcodes/custom.gcode"
    G4 P2000  ; Wait for generation
    SDCARD_PRINT_FILE FILENAME=custom.gcode

[gcode_shell_command generate_custom]
command: python3 ~/klipper/scripts/coil_generator.py
timeout: 10.0
```

**Usage:**
```gcode
WIND_TEST           ; Quick 5-layer test
WIND_PICKUP_50      ; Standard 50-layer pickup
WIND_CUSTOM LAYERS=30 RPM=250  ; Custom parameters
```

---

## 📊 Method 4: Manual G-code (For Testing)

### **Minimal Test G-code**

```gcode
; test_manual.gcode - Minimal winding test
G28 Y              ; Home traverse
G92 E0             ; Reset E position
G1 Y38 F1000       ; Move to start

; Wind 3 layers manually
G1 Y50 E12.0 F672  ; Layer 1 forward
G1 Y38 E24.0 F672  ; Layer 2 reverse
G1 Y50 E36.0 F672  ; Layer 3 forward

M118 Manual test complete
G1 Y38 F1000       ; Return to start
```

**To use:**
1. Create file `test_manual.gcode`
2. Upload via Mainsail
3. Click "Print"

---

## 🧮 Calculating Parameters

### **Feed Rate Calculation**

```
Given:
  Spindle RPM = 200
  Wire diameter = 0.056 mm

Calculate traverse speed:
  traverse_speed (mm/s) = (RPM / 60) × wire_diameter
  traverse_speed = (200 / 60) × 0.056
  traverse_speed = 0.187 mm/s

Convert to feed rate (mm/min for G-code):
  feed_rate = traverse_speed × 60
  feed_rate = 0.187 × 60
  feed_rate = 11.2 mm/min

Use in G-code:
  G1 Y50 E12 F11.2
```

### **Layers Required**

```
Given:
  Bobbin width = 12 mm
  Wire diameter = 0.056 mm
  Desired coil resistance = 8 kΩ (example)
  Wire resistance = 268 Ω/m (43 AWG copper)

Calculate:
  Turns per layer = 12 / 0.056 = 214 turns
  Circumference (approx) = π × 25mm = 78.5 mm
  Wire per layer = 214 × 0.0785m = 16.8m
  Resistance per layer = 16.8m × 268 Ω/m = 4502 Ω
  
  Layers needed = 8000 / 4502 = 1.78 layers
  → Wind 2 layers for ~9kΩ
```

---

## 🎯 Example Workflows

### **Workflow 1: Quick Test (First Time)**

```bash
# 1. Generate test G-code
python3 coil_generator.py --wire 0.056 --bobbin 12 --layers 5 --rpm 100 --output test.gcode

# 2. Upload to Klipper
scp test.gcode winder@winder.local:~/gcodes/

# 3. Open Mainsail (http://winder.local)
# 4. Click "Print" on test.gcode
# 5. Watch it wind!
```

### **Workflow 2: Production Coil**

```bash
# 1. Design coil specification
#    - 43 AWG wire (0.056mm)
#    - 12mm bobbin
#    - 50 layers
#    - 200 RPM

# 2. Generate G-code
python3 coil_generator.py \
  --wire 0.056 \
  --bobbin 12 \
  --layers 50 \
  --rpm 200 \
  --output pickup_50.gcode

# 3. Verify output
cat pickup_50.gcode | head -20

# 4. Upload and wind
scp pickup_50.gcode winder@winder.local:~/gcodes/

# 5. Wind in Mainsail
# Estimated time: ~4m 17s
```

### **Workflow 3: Batch Production**

```bash
# Create multiple coil specs
for layers in 20 30 40 50; do
  python3 coil_generator.py \
    --wire 0.056 \
    --bobbin 12 \
    --layers $layers \
    --rpm 200 \
    --output pickup_${layers}layer.gcode
done

# Upload all at once
scp pickup_*.gcode winder@winder.local:~/gcodes/

# Now you have a library of coils ready to wind!
```

---

## 🔍 Troubleshooting

### **Problem: "Wire spacing looks wrong"**

**Check:**
- Is `rotation_distance` in `[spindle_stepper]` correct?
- Run extruder calibration (like 3D printing)
- Measure 100mm of wire wound, adjust `rotation_distance`

### **Problem: "Layers are uneven"**

**Check:**
- Spindle Hall feedback working?
- Motor RPM stable?
- Pressure advance tuned?

### **Problem: "Wire breaks during winding"**

**Check:**
- Tension too high? Reduce RPM
- Wire snagged? Check feed path
- Sharp edges on bobbin?

---

## 📚 Next Steps

1. **Test the workflow:**
   - Generate `test_5layer.gcode`
   - Upload to Mainsail
   - Wind and inspect

2. **Calibrate:**
   - Verify wire spacing
   - Adjust `rotation_distance` if needed
   - Tune pressure advance

3. **Create coil library:**
   - Generate common specifications
   - Save as presets
   - Document successful coils

4. **Advanced features:**
   - Add crosswind patterns
   - Layer transition optimization
   - Automatic tension control

---

## 🎯 Summary

**You now have:**
- ✅ G-code generator (like a slicer!)
- ✅ Example G-code files
- ✅ Upload methods
- ✅ Quick-wind macros
- ✅ Complete workflow

**Just like 3D printing:**
1. Design spec → 2. Generate G-code → 3. Upload → 4. Print (wind)!

---

**Ready to wind your first coil!** 🚀

