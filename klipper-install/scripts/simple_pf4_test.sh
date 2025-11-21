#!/bin/bash
# Simple PF4 test - modifies config and tests

echo "============================================================"
echo "SIMPLE PF4 WIRING TEST"
echo "============================================================"
echo ""

# Backup
cp ~/printer.cfg ~/printer.cfg.backup.$(date +%s)

# Comment out endstop
sed -i 's/^endstop_pin:/#endstop_pin:/' ~/printer.cfg

# Add test pin if not exists
if ! grep -q "\[output_pin test_pf4\]" ~/printer.cfg; then
    echo "" >> ~/printer.cfg
    echo "# Temporary test pin" >> ~/printer.cfg
    echo "[output_pin test_pf4]" >> ~/printer.cfg
    echo "pin: PF4" >> ~/printer.cfg
    echo "value: 0" >> ~/printer.cfg
fi

echo "✓ Config updated"
echo "  - Commented out endstop_pin"
echo "  - Added test_pf4 output_pin"
echo ""

echo "Restarting Klipper..."
sudo systemctl restart klipper
sleep 8

echo ""
echo "Testing PF4..."
echo ""
echo "1. Current state (switch NOT pressed):"
python3 ~/klipper/scripts/klipper_interface.py -g "QUERY_PIN PIN=test_pf4" 2>&1 | grep -v "^$" || echo "Failed to query"

echo ""
echo "2. Press and HOLD the switch, then press Enter..."
read

echo "   Reading PF4 (pressed)..."
python3 ~/klipper/scripts/klipper_interface.py -g "QUERY_PIN PIN=test_pf4" 2>&1 | grep -v "^$" || echo "Failed to query"

echo ""
echo "3. RELEASE the switch, then press Enter..."
read

echo "   Reading PF4 (released)..."
python3 ~/klipper/scripts/klipper_interface.py -g "QUERY_PIN PIN=test_pf4" 2>&1 | grep -v "^$" || echo "Failed to query"

echo ""
echo "============================================================"
echo "Restoring config..."
mv ~/printer.cfg.backup.* ~/printer.cfg 2>/dev/null || echo "Backup not found"
sudo systemctl restart klipper

echo ""
echo "Done! Check if PF4 value changed when switch was pressed."

