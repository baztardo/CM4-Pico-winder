#!/bin/bash
# Fix endstop configuration - test different pin configurations

echo "============================================================"
echo "ENDSTOP CONFIGURATION FIX"
echo "============================================================"
echo ""

# Backup config
cp ~/printer.cfg ~/printer.cfg.backup.$(date +%Y%m%d_%H%M%S)
echo "✓ Config backed up"

# Current endstop config
echo "Current endstop_pin:"
grep "endstop_pin:" ~/printer.cfg | grep stepper_y

echo ""
echo "The error 'Endstop still triggered after retract' means:"
echo "  - Endstop is reading as TRIGGERED when it shouldn't be"
echo "  - This prevents homing"
echo ""
echo "Testing endstop state..."
echo ""

# Check endstop state via QUERY_ENDSTOPS
python3 ~/klipper/scripts/klipper_interface.py -g "QUERY_ENDSTOPS"

echo ""
echo "If endstop shows as 'triggered' when NOT pressed, we need to invert it."
echo ""
echo "Trying different configurations:"
echo ""

# Option 1: Try inverted (^PF3) - for NO switch that pulls LOW when pressed
echo "Option 1: Inverted endstop (^PF3) - for NO switch"
sed -i 's/^endstop_pin: PF3/endstop_pin: ^PF3/' ~/printer.cfg
echo "  Changed to: endstop_pin: ^PF3"
grep "endstop_pin:" ~/printer.cfg | grep stepper_y

echo ""
echo "Restarting Klipper..."
sudo systemctl restart klipper
sleep 5

echo ""
echo "Testing homing..."
python3 ~/klipper/scripts/klipper_interface.py -g "SET_STEPPER_ENABLE STEPPER=stepper_y ENABLE=1"
sleep 0.5
python3 ~/klipper/scripts/klipper_interface.py -g "G28 Y"

echo ""
echo "Check if homing worked. If not, try Option 2:"
echo ""
echo "Option 2: If still not working, try without inversion but check switch type"
echo "  - NO switch (LED ON when pressed) → needs ^PF3 (inverted)"
echo "  - NC switch (LED OFF when pressed) → needs PF3 (not inverted)"
echo ""
echo "To revert: cp ~/printer.cfg.backup.* ~/printer.cfg"

