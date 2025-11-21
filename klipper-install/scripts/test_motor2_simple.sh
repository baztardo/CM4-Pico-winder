#!/bin/bash
# Simple Motor2 (Y-axis) test

echo "============================================================"
echo "MOTOR2 (Y-AXIS) TEST"
echo "============================================================"
echo ""

# Enable stepper
echo "1. Enabling stepper_y..."
python3 ~/klipper/scripts/klipper_interface.py -g "SET_STEPPER_ENABLE STEPPER=stepper_y ENABLE=1"
sleep 1

# Home Y axis
echo ""
echo "2. Homing Y axis (G28 Y)..."
echo "   👀 WATCH THE MOTOR!"
python3 ~/klipper/scripts/klipper_interface.py -g "G28 Y"
sleep 2

# Check if homed
echo ""
echo "3. Checking if homed..."
python3 ~/klipper/scripts/klipper_interface.py --query toolhead | grep -i "homed\|position" || echo "   (Check manually)"

# Move
echo ""
echo "4. Moving Y axis 1mm..."
echo "   👀 WATCH THE MOTOR!"
python3 ~/klipper/scripts/klipper_interface.py -g "G91"
python3 ~/klipper/scripts/klipper_interface.py -g "G1 Y1 F100"
sleep 1

# Move more
echo ""
echo "5. Moving Y axis 5mm..."
python3 ~/klipper/scripts/klipper_interface.py -g "G1 Y5 F100"
sleep 1

# Move back
echo ""
echo "6. Moving back -6mm..."
python3 ~/klipper/scripts/klipper_interface.py -g "G1 Y-6 F100"
sleep 1

# Disable
echo ""
echo "7. Disabling stepper_y..."
python3 ~/klipper/scripts/klipper_interface.py -g "SET_STEPPER_ENABLE STEPPER=stepper_y ENABLE=0"

echo ""
echo "============================================================"
echo "TEST COMPLETE"
echo "============================================================"
echo ""
echo "Did the motor move during G28 Y?"
echo "  YES → Motor2 works! TMC2209 is working."
echo "  NO  → Check logs: tail -50 /tmp/klippy.log | grep -i 'tmc\|error\|endstop'"

