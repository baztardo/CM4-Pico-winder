#!/bin/bash
# Real test: Home Y axis, then move - with detailed output

echo "============================================================"
echo "HOME AND MOVE TEST - Detailed"
echo "============================================================"
echo ""

# Enable stepper
echo "1. Enabling stepper_y..."
python3 ~/klipper/scripts/klipper_interface.py -g "SET_STEPPER_ENABLE STEPPER=stepper_y ENABLE=1"
if [ $? -eq 0 ]; then
    echo "   ✓ Stepper enabled"
else
    echo "   ✗ Failed to enable stepper"
    exit 1
fi
sleep 0.5

# Home Y axis
echo ""
echo "2. Homing Y axis (G28 Y)..."
echo "   👀 WATCH THE MOTOR - it should move toward endstop!"
echo "   (This may take 10-30 seconds)"
python3 ~/klipper/scripts/klipper_interface.py -g "G28 Y"
if [ $? -eq 0 ]; then
    echo "   ✓ Homing command sent"
else
    echo "   ✗ Homing failed - check logs: tail -50 /tmp/klippy.log"
    exit 1
fi

# Wait and check if homed
sleep 3
echo ""
echo "3. Checking if Y axis is homed..."
python3 ~/klipper/scripts/klipper_interface.py --query toolhead | grep -i "homed\|position" || echo "   (Check position manually)"

# Set relative mode
echo ""
echo "4. Setting relative mode (G91)..."
python3 ~/klipper/scripts/klipper_interface.py -g "G91"
sleep 0.2

# Move 1mm
echo ""
echo "5. Moving Y axis 1mm..."
echo "   👀 WATCH THE MOTOR!"
python3 ~/klipper/scripts/klipper_interface.py -g "G1 Y1 F100"
if [ $? -eq 0 ]; then
    echo "   ✓ Movement command sent"
else
    echo "   ✗ Movement failed"
fi
sleep 1

# Move 5mm more
echo ""
echo "6. Moving Y axis 5mm more..."
python3 ~/klipper/scripts/klipper_interface.py -g "G1 Y5 F100"
sleep 1

# Move back
echo ""
echo "7. Moving back -6mm..."
python3 ~/klipper/scripts/klipper_interface.py -g "G1 Y-6 F100"
sleep 1

# Disable stepper
echo ""
echo "8. Disabling stepper_y..."
python3 ~/klipper/scripts/klipper_interface.py -g "SET_STEPPER_ENABLE STEPPER=stepper_y ENABLE=0"

echo ""
echo "============================================================"
echo "TEST COMPLETE"
echo "============================================================"
echo ""
echo "Did the motor move during homing (G28 Y)?"
echo "  YES → TMC2209 is working! Motor moved toward endstop."
echo "  NO  → Check:"
echo "        - TMC2209 power (5V logic + motor power)"
echo "        - Motor wiring (coil connections)"
echo "        - TMC2209 UART (PF13) - check logs for errors"
echo "        - Endstop switch (PF3) - should trigger when pressed"
echo ""
echo "Check logs: tail -50 /tmp/klippy.log | grep -i 'tmc\|error\|stepper\|endstop'"

