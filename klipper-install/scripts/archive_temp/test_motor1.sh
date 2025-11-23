#!/bin/bash
# Test Motor1 (X-axis) with factory-wired LDO stepper and new TMC2209

echo "============================================================"
echo "MOTOR1 (X-AXIS) TEST"
echo "============================================================"
echo ""
echo "Testing with:"
echo "  - Factory-wired LDO stepper motor"
echo "  - New TMC2209 driver"
echo "  - Pins: PE2 (STEP), PB4 (DIR), PC11 (EN), PC10 (UART)"
echo ""

# Enable stepper
echo "1. Enabling stepper_x..."
python3 ~/klipper/scripts/klipper_interface.py -g "SET_STEPPER_ENABLE STEPPER=stepper_x ENABLE=1"
if [ $? -eq 0 ]; then
    echo "   ✓ Stepper enabled"
else
    echo "   ✗ Failed to enable stepper"
    exit 1
fi
sleep 0.5

# Home X axis
echo ""
echo "2. Homing X axis (G28 X)..."
echo "   👀 WATCH THE MOTOR - it should move toward endstop!"
python3 ~/klipper/scripts/klipper_interface.py -g "G28 X"
if [ $? -eq 0 ]; then
    echo "   ✓ Homing command sent"
else
    echo "   ✗ Homing failed - check logs: tail -50 /tmp/klippy.log"
    exit 1
fi

sleep 3

# Set relative mode
echo ""
echo "3. Setting relative mode (G91)..."
python3 ~/klipper/scripts/klipper_interface.py -g "G91"
sleep 0.2

# Move 1mm
echo ""
echo "4. Moving X axis 1mm..."
echo "   👀 WATCH THE MOTOR!"
python3 ~/klipper/scripts/klipper_interface.py -g "G1 X1 F100"
sleep 1

# Move 5mm more
echo ""
echo "5. Moving X axis 5mm more..."
python3 ~/klipper/scripts/klipper_interface.py -g "G1 X5 F100"
sleep 1

# Move back
echo ""
echo "6. Moving back -6mm..."
python3 ~/klipper/scripts/klipper_interface.py -g "G1 X-6 F100"
sleep 1

# Disable stepper
echo ""
echo "7. Disabling stepper_x..."
python3 ~/klipper/scripts/klipper_interface.py -g "SET_STEPPER_ENABLE STEPPER=stepper_x ENABLE=0"

echo ""
echo "============================================================"
echo "TEST COMPLETE"
echo "============================================================"
echo ""
echo "Did the motor move?"
echo "  YES → Motor1 works! Factory motor + new TMC2209 = OK"
echo "        → Issue was with Motor2 (Y-axis) motor wiring or old driver"
echo "  NO  → Check:"
echo "        - TMC2209 UART (PC10)"
echo "        - Motor power"
echo "        - Check logs: tail -50 /tmp/klippy.log | grep -i 'tmc\|error'"

