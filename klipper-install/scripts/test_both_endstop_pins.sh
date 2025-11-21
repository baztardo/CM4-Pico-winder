#!/bin/bash
# Test both PF3 and PF4 endstop pins

echo "============================================================"
echo "TEST BOTH ENDSTOP PINS (PF3 vs PF4)"
echo "============================================================"
echo ""
echo "According to MP8 official config:"
echo "  - stepper_x endstop: ^PF3"
echo "  - stepper_y endstop: ^PF4"
echo ""
echo "You're using stepper_y, so PF4 might be correct!"
echo ""

# Test PF4
echo "Testing PF4 (official Y-axis endstop)..."
sed -i 's/endstop_pin:.*PF.*/endstop_pin: ^PF4/' ~/printer.cfg
sudo systemctl restart klipper
sleep 5

echo "Query endstops with PF4:"
python3 ~/klipper/scripts/klipper_interface.py -g "QUERY_ENDSTOPS"

echo ""
echo "Press and release switch, then press Enter..."
read

echo "Query endstops again:"
python3 ~/klipper/scripts/klipper_interface.py -g "QUERY_ENDSTOPS"

echo ""
echo "If PF4 doesn't work, try PF3:"
echo "  sed -i 's/endstop_pin:.*PF.*/endstop_pin: ^PF3/' ~/printer.cfg"
echo "  sudo systemctl restart klipper"

