#!/bin/bash
# Fix endstop that always shows "true"

echo "============================================================"
echo "FIX ENDSTOP ALWAYS TRUE"
echo "============================================================"
echo ""

echo "Current endstop config:"
grep "endstop_pin:" ~/printer.cfg | grep stepper_y

echo ""
echo "If endstop always shows 'true' (both pressed and unpressed):"
echo "  → Endstop pin is inverted incorrectly"
echo "  → Try different pin configurations"
echo ""

# Try PF3 without inversion first
echo "Trying: endstop_pin: PF3 (no inversion)..."
sed -i 's/^endstop_pin: \^PF3/endstop_pin: PF3/' ~/printer.cfg
sed -i 's/^endstop_pin: PF3/endstop_pin: PF3/' ~/printer.cfg  # In case it's already PF3

echo "Updated config:"
grep "endstop_pin:" ~/printer.cfg | grep stepper_y

echo ""
echo "Restarting Klipper..."
sudo systemctl restart klipper
sleep 5

echo ""
echo "Test endstop:"
python3 ~/klipper/scripts/klipper_interface.py -g "QUERY_ENDSTOPS"

echo ""
echo "If still always 'true', try:"
echo "  - endstop_pin: !PF3 (pull-down)"
echo "  - endstop_pin: ^!PF3 (inverted + pull-down)"
echo "  - Check PF3 wiring to switch"

