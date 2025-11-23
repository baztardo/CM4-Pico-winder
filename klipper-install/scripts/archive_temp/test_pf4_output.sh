#!/bin/bash
# Test PF4 as OUTPUT to verify it's working

echo "============================================================"
echo "PF4 OUTPUT TEST (Verify pin is working)"
echo "============================================================"
echo ""

# Backup
cp ~/printer.cfg ~/printer.cfg.backup.$(date +%s)

# Comment out endstop
sed -i 's/^endstop_pin:/#endstop_pin:/' ~/printer.cfg

# Add test pin as OUTPUT
if ! grep -q "\[output_pin test_pf4\]" ~/printer.cfg; then
    echo "" >> ~/printer.cfg
    echo "# Test PF4 as OUTPUT" >> ~/printer.cfg
    echo "[output_pin test_pf4]" >> ~/printer.cfg
    echo "pin: PF4" >> ~/printer.cfg
    echo "value: 0" >> ~/printer.cfg
fi

echo "✓ Config updated"
echo ""

echo "Restarting Klipper..."
sudo systemctl restart klipper
sleep 8

echo ""
echo "Testing PF4 as OUTPUT..."
echo ""

echo "1. Setting PF4 LOW (0)..."
python3 ~/klipper/scripts/klipper_interface.py -g "SET_PIN PIN=test_pf4 VALUE=0" 2>&1 | grep -v "^$"
sleep 1

echo ""
echo "2. Setting PF4 HIGH (1)..."
python3 ~/klipper/scripts/klipper_interface.py -g "SET_PIN PIN=test_pf4 VALUE=1" 2>&1 | grep -v "^$"
sleep 1

echo ""
echo "3. Reading PF4 state..."
python3 ~/klipper/scripts/klipper_interface.py -g "QUERY_PIN PIN=test_pf4" 2>&1 | grep -v "^$"

echo ""
echo "============================================================"
echo "ANALYSIS:"
echo "============================================================"
echo ""
echo "If PF4 can be set HIGH/LOW, the pin is working."
echo "If PF4 always reads LOW even when set HIGH, it's shorted to GND."
echo ""
echo "If PF4 works as OUTPUT but not as INPUT:"
echo "  → Switch might be on a different pin"
echo "  → Switch wiring might be incorrect"
echo ""

echo "Restoring config..."
mv ~/printer.cfg.backup.* ~/printer.cfg 2>/dev/null || echo "Backup not found"
sudo systemctl restart klipper

echo ""
echo "Done!"

