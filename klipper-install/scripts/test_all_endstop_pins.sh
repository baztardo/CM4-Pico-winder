#!/bin/bash
# Test all possible endstop pins to find which one is connected

echo "============================================================"
echo "TEST ALL POSSIBLE ENDSTOP PINS"
echo "============================================================"
echo ""

# List of pins to test (common endstop pins on MP8)
PINS=("PF3" "PF4" "PF5" "PC0" "PC1" "PC2")

echo "Testing pins: ${PINS[@]}"
echo ""
echo "For each pin, check if QUERY_ENDSTOPS changes when you press the switch"
echo ""

for pin in "${PINS[@]}"; do
    echo "============================================================"
    echo "Testing: $pin"
    echo "============================================================"
    
    # Backup config
    cp ~/printer.cfg ~/printer.cfg.backup
    
    # Set endstop pin
    sed -i "s/^endstop_pin:.*/endstop_pin: ^$pin/" ~/printer.cfg
    
    echo "Config updated: endstop_pin: ^$pin"
    echo "Restarting Klipper..."
    sudo systemctl restart klipper
    sleep 8
    
    echo ""
    echo "Current endstop state (switch NOT pressed):"
    python3 ~/klipper/scripts/klipper_interface.py -g "QUERY_ENDSTOPS" 2>&1 | grep -i "stepper_y\|y:" || echo "Query failed"
    
    echo ""
    echo "Press and HOLD the switch, then press Enter..."
    read
    
    echo "Endstop state (switch PRESSED):"
    python3 ~/klipper/scripts/klipper_interface.py -g "QUERY_ENDSTOPS" 2>&1 | grep -i "stepper_y\|y:" || echo "Query failed"
    
    echo ""
    echo "RELEASE the switch, then press Enter..."
    read
    
    echo "Endstop state (switch RELEASED):"
    python3 ~/klipper/scripts/klipper_interface.py -g "QUERY_ENDSTOPS" 2>&1 | grep -i "stepper_y\|y:" || echo "Query failed"
    
    echo ""
    echo "Did the endstop state change when you pressed/released?"
    echo "If YES, $pin is the correct pin!"
    echo "If NO, press Enter to test next pin..."
    read
    
    # Restore backup
    mv ~/printer.cfg.backup ~/printer.cfg
done

echo ""
echo "============================================================"
echo "TEST COMPLETE"
echo "============================================================"
echo ""
echo "If none of the pins worked, check:"
echo "  1. Physical wiring - which pin is the switch actually connected to?"
echo "  2. Switch type - is it NO (Normally Open) or NC (Normally Closed)?"
echo "  3. Switch power - is the switch LED circuit separate from signal?"

