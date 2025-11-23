#!/bin/bash
# Test Motor1 (X-axis) with direct output_pin control
# This bypasses kinematics and TMC2209 UART

echo "============================================================"
echo "MOTOR1 DIRECT TEST (Output Pin Control)"
echo "============================================================"
echo ""
echo "Testing Motor1 with:"
echo "  - Factory-wired LDO stepper motor"
echo "  - Direct step pulses (bypasses TMC2209 UART)"
echo "  - Pins: PE2 (STEP), PB4 (DIR), PC11 (EN)"
echo ""
echo "⚠️  Note: This tests motor wiring/power, not TMC2209 UART"
echo ""

# Enable motor (LOW = enabled)
echo "1. Enabling Motor1 (setting enable LOW)..."
python3 ~/klipper/scripts/klipper_interface.py -g "SET_PIN PIN=motor1_enable VALUE=0"
sleep 0.5

# Set direction
echo ""
echo "2. Setting direction (forward)..."
python3 ~/klipper/scripts/klipper_interface.py -g "SET_PIN PIN=motor1_dir VALUE=0"
sleep 0.2

# Send step pulses manually
echo ""
echo "3. Sending step pulses..."
echo "   👀 WATCH THE MOTOR!"
echo "   Sending 100 pulses at 100Hz (1 second)..."
for i in {1..100}; do
    python3 ~/klipper/scripts/klipper_interface.py -g "SET_PIN PIN=motor1_step VALUE=1"
    sleep 0.005  # 5ms = 200Hz
    python3 ~/klipper/scripts/klipper_interface.py -g "SET_PIN PIN=motor1_step VALUE=0"
    sleep 0.005
    if [ $((i % 20)) -eq 0 ]; then
        echo "   Pulses: $i/100"
    fi
done

sleep 0.5

# Reverse direction
echo ""
echo "4. Reversing direction..."
python3 ~/klipper/scripts/klipper_interface.py -g "SET_PIN PIN=motor1_dir VALUE=1"
sleep 0.2

# Send more pulses
echo ""
echo "5. Sending step pulses (reverse)..."
for i in {1..100}; do
    python3 ~/klipper/scripts/klipper_interface.py -g "SET_PIN PIN=motor1_step VALUE=1"
    sleep 0.005
    python3 ~/klipper/scripts/klipper_interface.py -g "SET_PIN PIN=motor1_step VALUE=0"
    sleep 0.005
done

# Disable motor
echo ""
echo "6. Disabling Motor1..."
python3 ~/klipper/scripts/klipper_interface.py -g "SET_PIN PIN=motor1_enable VALUE=1"

echo ""
echo "============================================================"
echo "TEST COMPLETE"
echo "============================================================"
echo ""
echo "Did the motor move?"
echo "  YES → Motor wiring/power OK! Issue is TMC2209 UART or config"
echo "  NO  → Check:"
echo "        - Motor power supply"
echo "        - Motor wiring (coil connections)"
echo "        - Try swapping motor coil pairs"

