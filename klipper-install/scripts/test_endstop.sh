#!/bin/bash
# Test endstop state and configuration

echo "============================================================"
echo "ENDSTOP TEST"
echo "============================================================"
echo ""

# Enable stepper
echo "1. Enabling stepper_y..."
python3 ~/klipper/scripts/klipper_interface.py -g "SET_STEPPER_ENABLE STEPPER=stepper_y ENABLE=1"
sleep 0.5

# Query endstop state
echo ""
echo "2. Querying endstop state..."
echo "   (Press and release the endstop switch while watching)"
python3 ~/klipper/scripts/klipper_interface.py -g "QUERY_ENDSTOPS"

echo ""
echo "3. Check endstop configuration:"
grep "endstop_pin:" ~/printer.cfg | grep stepper_y

echo ""
echo "4. Endstop behavior:"
echo "   - LED turns ON when pressed → Switch is NO (Normally Open)"
echo "   - NO switch pulls LOW when pressed → Needs ^PF3 (inverted)"
echo "   - If endstop shows 'triggered' when NOT pressed → Wrong configuration"
echo ""
echo "5. Current endstop state (from logs):"
tail -20 /tmp/klippy.log | grep -i "endstop\|triggered" | tail -5

echo ""
echo "============================================================"
echo "TO FIX:"
echo "============================================================"
echo ""
echo "If endstop is 'triggered' when NOT pressed:"
echo "  sed -i 's/^endstop_pin: PF3/endstop_pin: ^PF3/' ~/printer.cfg"
echo "  sudo systemctl restart klipper"
echo ""
echo "If endstop is NOT 'triggered' when pressed:"
echo "  sed -i 's/^endstop_pin: \^PF3/endstop_pin: PF3/' ~/printer.cfg"
echo "  sudo systemctl restart klipper"

