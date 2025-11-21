#!/bin/bash
# Check Klipper logs for PF4 errors

echo "============================================================"
echo "CHECKING KLIPPER LOGS FOR PF4 ERRORS"
echo "============================================================"
echo ""

echo "Recent Klipper errors:"
tail -100 /tmp/klippy.log | grep -i "error\|pf4\|test_pf4\|pin" | tail -20

echo ""
echo "============================================================"
echo "CHECKING CONFIG"
echo "============================================================"
echo ""

echo "PF4 config in printer.cfg:"
grep -A 3 "test_pf4\|PF4" ~/printer.cfg | head -10

echo ""
echo "============================================================"
echo "TESTING ENDSTOP STATUS DIRECTLY"
echo "============================================================"
echo ""

# Restore endstop config
sed -i 's/^#endstop_pin:/endstop_pin:/' ~/printer.cfg
sed -i '/\[output_pin test_pf4\]/,/^$/d' ~/printer.cfg

sudo systemctl restart klipper
sleep 8

echo "Querying endstop status:"
python3 ~/klipper/scripts/klipper_interface.py -g "QUERY_ENDSTOPS"

echo ""
echo "Check if stepper_y endstop shows triggered/not triggered"
echo "when you press/release the switch"

