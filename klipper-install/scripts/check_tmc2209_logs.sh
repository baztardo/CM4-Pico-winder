#!/bin/bash
# Check Klipper logs for TMC2209 communication

echo "============================================================"
echo "TMC2209 LOG CHECK"
echo "============================================================"
echo ""

echo "Recent TMC2209 messages:"
echo "------------------------"
tail -100 /tmp/klippy.log | grep -i "tmc\|stepper_y\|uart" | tail -20

echo ""
echo "TMC2209 errors:"
echo "---------------"
tail -100 /tmp/klippy.log | grep -i "tmc.*error\|uart.*error\|stepper.*error" | tail -10

echo ""
echo "Full recent log (last 50 lines):"
echo "--------------------------------"
tail -50 /tmp/klippy.log

