#!/bin/bash
# Test endstop directly

echo "============================================================"
echo "ENDSTOP DIRECT TEST"
echo "============================================================"
echo ""

echo "1. Checking endstop pin configuration..."
grep "endstop_pin:" ~/printer.cfg | grep stepper_y

echo ""
echo "2. Querying endstop state..."
echo "   Press and release the switch while watching:"
python3 ~/klipper/scripts/klipper_interface.py -g "QUERY_ENDSTOPS"

echo ""
echo "3. Testing endstop with SET_PIN (if endstop is configured as output_pin)..."
echo "   (This won't work if endstop is only in stepper config)"

echo ""
echo "4. Checking logs for endstop messages..."
tail -50 /tmp/klippy.log | grep -i "endstop\|triggered\|PF3" | tail -10

echo ""
echo "============================================================"
echo "TROUBLESHOOTING:"
echo "============================================================"
echo ""
echo "If holding switch doesn't stop motor:"
echo "  1. Endstop pin (PF3) may not be connected"
echo "  2. Endstop pin may be wrong"
echo "  3. Endstop inversion may be wrong"
echo ""
echo "Try different endstop configurations:"
echo "  - endstop_pin: PF3 (no inversion)"
echo "  - endstop_pin: ^PF3 (inverted)"
echo "  - endstop_pin: !PF3 (pull-down)"
echo "  - endstop_pin: ^!PF3 (inverted + pull-down)"

