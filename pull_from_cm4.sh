#!/bin/bash
# pull_from_cm4.sh - Backup production files from CM4 to local

REMOTE="winder@winder.local"
LOCAL_BASE="$HOME/Documents/GitHub/CM4-Pico-winder"

echo "=========================================="
echo "Pulling files from CM4 to local..."
echo "=========================================="
echo ""

# Python modules
echo "📦 Python modules..."
mkdir -p "$LOCAL_BASE/klipper-install/extras"
scp $REMOTE:~/klipper/klippy/extras/hw_counter.py "$LOCAL_BASE/klipper-install/extras/" 2>/dev/null && echo "  ✅ hw_counter.py" || echo "  ⚠️  hw_counter.py (not found)"
scp $REMOTE:~/klipper/klippy/extras/angle_sensor.py "$LOCAL_BASE/klipper-install/extras/" 2>/dev/null && echo "  ✅ angle_sensor.py" || echo "  ⚠️  angle_sensor.py (not found)"
scp $REMOTE:~/klipper/klippy/extras/winder_control.py "$LOCAL_BASE/klipper-install/extras/" 2>/dev/null && echo "  ✅ winder_control.py" || echo "  ⚠️  winder_control.py (not found)"
scp $REMOTE:~/klipper/klippy/extras/bldc_motor.py "$LOCAL_BASE/klipper-install/extras/" 2>/dev/null && echo "  ✅ bldc_motor.py" || echo "  ⚠️  bldc_motor.py (not found)"
scp $REMOTE:~/klipper/klippy/extras/traverse.py "$LOCAL_BASE/klipper-install/extras/" 2>/dev/null && echo "  ✅ traverse.py" || echo "  ⚠️  traverse.py (not found)"

# C firmware
echo ""
echo "🔧 C firmware..."
mkdir -p "$LOCAL_BASE/src"
scp $REMOTE:~/klipper/src/hw_counter.c "$LOCAL_BASE/src/" 2>/dev/null && echo "  ✅ hw_counter.c" || echo "  ⚠️  hw_counter.c (not found)"

# Configuration
echo ""
echo "⚙️  Configuration..."
mkdir -p "$LOCAL_BASE/config"
scp $REMOTE:~/printer.cfg "$LOCAL_BASE/config/printer-manta-m4p-modular.cfg" 2>/dev/null && echo "  ✅ printer.cfg" || echo "  ⚠️  printer.cfg (not found)"

# Scripts
echo ""
echo "📜 Scripts..."
mkdir -p "$LOCAL_BASE/klipper-install/scripts"
scp $REMOTE:~/gcode_runner.py "$LOCAL_BASE/klipper-install/scripts/" 2>/dev/null && echo "  ✅ gcode_runner.py" || echo "  ⚠️  gcode_runner.py (not found)"
scp $REMOTE:~/verify_calibration.sh "$LOCAL_BASE/klipper-install/scripts/" 2>/dev/null && echo "  ✅ verify_calibration.sh" || echo "  ⚠️  verify_calibration.py (not found)"
scp $REMOTE:~/klipper_interface.py "$LOCAL_BASE/klipper-install/scripts/" 2>/dev/null && echo "  ✅ klipper_interface.py" || echo "  ⚠️  klipper_interface.py (not found)"

# Web interface
echo ""
echo "🌐 Web interface..."
mkdir -p "$LOCAL_BASE/web-interface"
scp $REMOTE:~/winder-web/winder-console.html "$LOCAL_BASE/web-interface/" 2>/dev/null && echo "  ✅ winder-console.html" || echo "  ⚠️  winder-console.html (not found)"

# Calibration data
echo ""
echo "📊 Calibration data..."
mkdir -p "$LOCAL_BASE/backups/calibration_reports"
scp -r $REMOTE:~/calibration_reports/* "$LOCAL_BASE/backups/calibration_reports/" 2>/dev/null && echo "  ✅ Calibration reports" || echo "  ⚠️  No calibration reports found"

echo ""
echo "=========================================="
echo "Pull complete!"
echo "=========================================="
echo ""
echo "Files saved to: $LOCAL_BASE"

