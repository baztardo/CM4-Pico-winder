#!/bin/bash
# Test motor WITHOUT TMC2209 UART (bypass TMC2209)

echo "============================================================"
echo "TEST WITHOUT TMC2209 UART"
echo "============================================================"
echo ""
echo "This will comment out TMC2209 config to test motor directly"
echo ""

# Backup config
cp ~/printer.cfg ~/printer.cfg.backup.$(date +%Y%m%d_%H%M%S)

# Comment out TMC2209 section
sed -i 's/^\[tmc2209 stepper_y\]/# [tmc2209 stepper_y]/' ~/printer.cfg
sed -i '/^# \[tmc2209 stepper_y\]/,/^\[/ { /^\[/!s/^/#/; }' ~/printer.cfg

echo "✅ Commented out TMC2209 section"
echo ""
echo "Restarting Klipper..."
sudo systemctl restart klipper
sleep 5

echo ""
echo "Testing motor without TMC2209 UART..."
python3 ~/klipper/scripts/klipper_interface.py -g "SET_STEPPER_ENABLE STEPPER=stepper_y ENABLE=1"
sleep 0.5
python3 ~/klipper/scripts/klipper_interface.py -g "G91"
python3 ~/klipper/scripts/klipper_interface.py -g "G1 Y1 F100"

echo ""
echo "Did the motor move?"
echo "  YES → Motor wiring OK, issue is TMC2209 UART (PF13)"
echo "  NO  → Motor wiring still wrong or motor power issue"
echo ""
echo "To restore TMC2209:"
echo "  cp ~/printer.cfg.backup.* ~/printer.cfg"
echo "  sudo systemctl restart klipper"

