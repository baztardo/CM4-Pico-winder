#!/bin/bash
# Check endstop state

echo "============================================================"
echo "ENDSTOP CHECK"
echo "============================================================"
echo ""

echo "1. Querying endstop state..."
echo "   (Press and release endstop switch while watching)"
python3 ~/klipper/scripts/klipper_interface.py -g "QUERY_ENDSTOPS"

echo ""
echo "2. Checking endstop config..."
grep "endstop_pin:" ~/printer.cfg | grep stepper_y

echo ""
echo "3. Endstop behavior:"
echo "   - If endstop shows 'triggered' when NOT pressed → Wrong pin inversion"
echo "   - If endstop shows 'open' when NOT pressed → Correct"
echo "   - If endstop shows 'triggered' when pressed → Correct"
echo ""
echo "Current config: endstop_pin: ^PF3 (inverted)"
echo "This means: LOW = triggered, HIGH = open"
echo ""
echo "If endstop is showing 'triggered' when NOT pressed:"
echo "  → Try removing ^ inversion: endstop_pin: PF3"
echo "  → Edit: nano ~/printer.cfg"
echo "  → Find: endstop_pin: ^PF3"
echo "  → Change to: endstop_pin: PF3"
echo "  → Restart: sudo systemctl restart klipper"

