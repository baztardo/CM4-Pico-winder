#!/bin/bash
# Simple test: Home Y axis, then move

echo "============================================================"
echo "HOME AND MOVE TEST"
echo "============================================================"
echo ""

# Enable stepper
echo "1. Enabling stepper_y..."
python3 ~/klipper/scripts/klipper_interface.py -g "SET_STEPPER_ENABLE STEPPER=stepper_y ENABLE=1"
sleep 0.5

# Home Y axis
echo ""
echo "2. Homing Y axis (G28 Y)..."
echo "   👀 WATCH THE MOTOR!"
python3 ~/klipper/scripts/klipper_interface.py -g "G28 Y"
sleep 1

# Set relative mode
echo ""
echo "3. Setting relative mode (G91)..."
python3 ~/klipper/scripts/klipper_interface.py -g "G91"
sleep 0.2

# Move 1mm
echo ""
echo "4. Moving Y axis 1mm..."
echo "   👀 WATCH THE MOTOR!"
python3 ~/klipper/scripts/klipper_interface.py -g "G1 Y1 F100"
sleep 0.5

# Move 5mm more
echo ""
echo "5. Moving Y axis 5mm more..."
python3 ~/klipper/scripts/klipper_interface.py -g "G1 Y5 F100"
sleep 0.5

# Move back
echo ""
echo "6. Moving back -6mm..."
python3 ~/klipper/scripts/klipper_interface.py -g "G1 Y-6 F100"
sleep 0.5

# Disable stepper
echo ""
echo "7. Disabling stepper_y..."
python3 ~/klipper/scripts/klipper_interface.py -g "SET_STEPPER_ENABLE STEPPER=stepper_y ENABLE=0"

echo ""
echo "============================================================"
echo "TEST COMPLETE"
echo "============================================================"
echo ""
echo "Did the motor move?"
echo "  YES → Hardware works! Klipper is controlling the motor."
echo "  NO  → Check:"
echo "        - Stepper driver power"
echo "        - Wiring (PF12→STEP, PF11→DIR, PB3→EN)"
echo "        - Motor coil connections"
echo "        - TMC2209 UART communication (PF13)"
echo "        - Endstop switch (PF3) - should trigger when pressed"

