#!/bin/bash
# Diagnose why Motor2 starts then stops

echo "============================================================"
echo "MOTOR2 STOP DIAGNOSTIC"
echo "============================================================"
echo ""

# Check endstop state
echo "1. Checking endstop state..."
echo "   (Press and release endstop while watching)"
python3 ~/klipper/scripts/klipper_interface.py -g "QUERY_ENDSTOPS"
sleep 1

# Check logs for endstop triggers
echo ""
echo "2. Checking logs for endstop triggers..."
tail -50 /tmp/klippy.log | grep -i "endstop\|triggered" | tail -5

# Check TMC2209 errors
echo ""
echo "3. Checking TMC2209 errors..."
tail -100 /tmp/klippy.log | grep -i "tmc\|uart\|error\|fault" | tail -10

# Try homing with verbose output
echo ""
echo "4. Testing homing (watch for what stops it)..."
python3 ~/klipper/scripts/klipper_interface.py -g "SET_STEPPER_ENABLE STEPPER=stepper_y ENABLE=1"
sleep 0.5

echo ""
echo "   Starting G28 Y..."
echo "   👀 WATCH THE MOTOR AND LOGS!"
python3 ~/klipper/scripts/klipper_interface.py -g "G28 Y" &
HOMING_PID=$!

# Monitor logs in real-time
sleep 3
echo ""
echo "   Recent logs during homing:"
tail -20 /tmp/klippy.log | tail -10

wait $HOMING_PID 2>/dev/null

echo ""
echo "============================================================"
echo "TROUBLESHOOTING:"
echo "============================================================"
echo ""
echo "If motor starts then stops immediately:"
echo "  1. Endstop may be triggering incorrectly"
echo "     → Check: endstop_pin: ^PF3 (should be inverted)"
echo "     → Try: Manually press/release endstop and check QUERY_ENDSTOPS"
echo ""
echo "  2. TMC2209 may be faulting"
echo "     → Check logs for TMC errors"
echo "     → Check TMC2209 UART connection (PF13)"
echo "     → Try increasing current: run_current: 0.600"
echo ""
echo "  3. Homing speed may be too fast"
echo "     → Current: homing_speed: 10"
echo "     → Try: homing_speed: 5"

