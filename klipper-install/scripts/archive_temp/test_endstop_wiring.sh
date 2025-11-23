#!/bin/bash
# Test endstop wiring by temporarily using PF4 as a regular GPIO pin

echo "============================================================"
echo "TEST ENDSTOP WIRING (PF4 GPIO TEST)"
echo "============================================================"
echo ""

echo "This will temporarily disable the endstop and test PF4 as GPIO"
echo ""

# Backup config
cp ~/printer.cfg ~/printer.cfg.backup

# Comment out endstop_pin temporarily
sed -i 's/^endstop_pin:/#endstop_pin:/' ~/printer.cfg

# Add PF4 as test output_pin
if ! grep -q "\[output_pin test_pf4\]" ~/printer.cfg; then
    cat >> ~/printer.cfg << 'EOF'

# Temporary test pin for PF4 wiring check
[output_pin test_pf4]
pin: PF4
value: 0
EOF
fi

echo "✓ Updated printer.cfg (endstop disabled, PF4 as test pin)"
echo ""
echo "Restarting Klipper..."
sudo systemctl restart klipper
sleep 5

echo ""
echo "Testing PF4 as GPIO..."
echo ""
echo "Current PF4 state (read from test_pf4 pin):"
python3 ~/klipper/scripts/klipper_interface.py -g "QUERY_PIN PIN=test_pf4" 2>/dev/null || echo "Query failed - try reading via API"

echo ""
echo "Press and HOLD the switch, then press Enter..."
read
echo "Reading PF4 (pressed)..."
python3 ~/klipper/scripts/klipper_interface.py -g "QUERY_PIN PIN=test_pf4" 2>/dev/null || echo "Query failed"

echo ""
echo "RELEASE the switch, then press Enter..."
read
echo "Reading PF4 (released)..."
python3 ~/klipper/scripts/klipper_interface.py -g "QUERY_PIN PIN=test_pf4" 2>/dev/null || echo "Query failed"

echo ""
echo "If values don't change, PF4 is not connected to the switch!"

echo ""
echo "Restoring config..."
mv ~/printer.cfg.backup ~/printer.cfg
sudo systemctl restart klipper

echo ""
echo "Done!"

