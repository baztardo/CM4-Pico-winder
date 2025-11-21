#!/bin/bash
# Test switch directly with multimeter/continuity

echo "============================================================"
echo "DIRECT SWITCH TEST"
echo "============================================================"
echo ""
echo "Test the switch with a multimeter:"
echo ""
echo "1. Power OFF the board"
echo "2. Set multimeter to continuity/beep mode"
echo "3. Connect one probe to PF4 pin on Motor 2 Y header"
echo "4. Connect other probe to GND"
echo ""
echo "Expected results:"
echo "  - Switch NOT pressed: NO continuity (open circuit)"
echo "  - Switch PRESSED: Continuity (closed circuit, beeps)"
echo ""
echo "If switch doesn't change continuity when pressed:"
echo "  → Switch is BAD (replace it)"
echo ""
echo "If switch DOES change continuity:"
echo "  → Switch is good, wiring issue"
echo ""

echo "Press Enter when done testing..."
read

echo ""
echo "============================================================"
echo "BYPASS SWITCH - USE VIRTUAL ENDSTOP"
echo "============================================================"
echo ""
echo "To get motor working WITHOUT the switch:"
echo "  Change endstop_pin to: tmc2209_stepper_y:virtual_endstop"
echo ""
echo "This will disable physical endstop and allow homing without switch."
echo ""
echo "Do you want to enable virtual endstop? (y/n)"
read answer

if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
    cp ~/printer.cfg ~/printer.cfg.backup.$(date +%s)
    sed -i 's/^endstop_pin:.*/endstop_pin: tmc2209_stepper_y:virtual_endstop/' ~/printer.cfg
    echo ""
    echo "✓ Config updated to use virtual endstop"
    echo "  Restarting Klipper..."
    sudo systemctl restart klipper
    sleep 5
    echo ""
    echo "✓ Klipper restarted"
    echo ""
    echo "Now try: G28 Y"
    echo "Motor should home without needing the switch!"
fi

