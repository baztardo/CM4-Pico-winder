#!/bin/bash
# push_to_cm4.sh - Deploy local changes to CM4

REMOTE="winder@winder.local"
LOCAL_BASE="$HOME/Documents/GitHub/CM4-Pico-winder"

echo "=========================================="
echo "Pushing files from local to CM4..."
echo "=========================================="
echo ""

# Python modules
echo "📦 Python modules..."
scp "$LOCAL_BASE/klipper-install/extras/hw_counter.py" $REMOTE:~/klipper/klippy/extras/ && echo "  ✅ hw_counter.py"
scp "$LOCAL_BASE/klipper-install/extras/angle_sensor.py" $REMOTE:~/klipper/klippy/extras/ && echo "  ✅ angle_sensor.py"
scp "$LOCAL_BASE/klipper-install/extras/winder_control.py" $REMOTE:~/klipper/klippy/extras/ && echo "  ✅ winder_control.py"
scp "$LOCAL_BASE/klipper-install/extras/bldc_motor.py" $REMOTE:~/klipper/klippy/extras/ && echo "  ✅ bldc_motor.py"
scp "$LOCAL_BASE/klipper-install/extras/traverse.py" $REMOTE:~/klipper/klippy/extras/ && echo "  ✅ traverse.py"

# C firmware
echo ""
echo "🔧 C firmware..."
scp "$LOCAL_BASE/src/hw_counter.c" $REMOTE:~/klipper/src/ && echo "  ✅ hw_counter.c"

# Configuration
echo ""
echo "⚙️  Configuration..."
scp "$LOCAL_BASE/config/printer-manta-m4p-modular.cfg" $REMOTE:~/printer.cfg && echo "  ✅ printer.cfg"

# Scripts
echo ""
echo "📜 Scripts..."
scp "$LOCAL_BASE/klipper-install/scripts/gcode_runner.py" $REMOTE:~/ && echo "  ✅ gcode_runner.py"
scp "$LOCAL_BASE/klipper-install/scripts/verify_calibration.sh" $REMOTE:~/ && echo "  ✅ verify_calibration.sh"
scp "$LOCAL_BASE/klipper-install/scripts/klipper_interface.py" $REMOTE:~/ && echo "  ✅ klipper_interface.py"

# Make scripts executable
ssh $REMOTE "chmod +x ~/gcode_runner.py ~/verify_calibration.sh ~/klipper_interface.py"

# Web interface
echo ""
echo "🌐 Web interface..."
ssh $REMOTE "mkdir -p ~/winder-web"
scp "$LOCAL_BASE/web-interface/winder-console.html" $REMOTE:~/winder-web/ && echo "  ✅ winder-console.html"

# Examples
echo ""
echo "📝 Examples..."
ssh $REMOTE "mkdir -p ~/examples"
scp "$LOCAL_BASE/klipper-install/scripts/examples/test_sequence.gcode" $REMOTE:~/examples/ && echo "  ✅ test_sequence.gcode"
scp "$LOCAL_BASE/klipper-install/scripts/examples/production_humbucker.gcode" $REMOTE:~/examples/ && echo "  ✅ production_humbucker.gcode"

echo ""
echo "=========================================="
echo "Push complete!"
echo "=========================================="
echo ""
echo "⚠️  IMPORTANT: Next steps depend on what changed:"
echo ""
echo "If C code (hw_counter.c) changed:"
echo "  ssh winder@winder.local"
echo "  cd ~/klipper"
echo "  make"
echo "  make flash"
echo ""
echo "If Python modules or config changed:"
echo "  ssh winder@winder.local 'sudo service klipper restart'"
echo ""

