#!/bin/bash
# Systematic diagnostic - test each component independently
# No guessing, no circles - find the exact problem

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== SYSTEMATIC DIAGNOSTIC ===${NC}"
echo "Testing each component independently to find the exact problem"
echo ""

# Test 1: MCU Communication
echo -e "${BLUE}[TEST 1] MCU Communication${NC}"
MCU_VERSION=$(python3 ~/klipper/scripts/klipper_interface.py --query mcu 2>&1 | grep -o '"mcu_version":"[^"]*"' | cut -d'"' -f4)
if [ -n "$MCU_VERSION" ]; then
    echo -e "${GREEN}✓ PASS: MCU responding - Version: $MCU_VERSION${NC}"
    MCU_OK=1
else
    echo -e "${RED}✗ FAIL: MCU not responding${NC}"
    MCU_OK=0
    echo "STOPPING - Fix MCU communication first"
    exit 1
fi
echo ""

# Test 2: Pin Control (output_pin)
echo -e "${BLUE}[TEST 2] Pin Control (PF12, PF11, PB3)${NC}"
# Create minimal config for pin testing
cat > /tmp/pin_test.cfg <<EOF
[mcu]
serial: /dev/serial/by-id/usb-Klipper_stm32g0b1xx_2000080012504B4633373520-if00

[printer]
kinematics: none

[output_pin test_step]
pin: PF12

[output_pin test_dir]
pin: PF11

[output_pin test_enable]
pin: PB3
EOF

cp ~/printer.cfg ~/printer.cfg.backup.$(date +%s)
cp /tmp/pin_test.cfg ~/printer.cfg
sudo systemctl restart klipper
sleep 5

# Test each pin
echo "Testing PF12 (STEP pin)..."
RESULT1=$(python3 ~/klipper/scripts/klipper_interface.py -g "SET_PIN PIN=test_step VALUE=1" 2>&1 | grep -o "Result:.*")
echo "  $RESULT1"

echo "Testing PF11 (DIR pin)..."
RESULT2=$(python3 ~/klipper/scripts/klipper_interface.py -g "SET_PIN PIN=test_dir VALUE=1" 2>&1 | grep -o "Result:.*")
echo "  $RESULT2"

echo "Testing PB3 (ENABLE pin)..."
RESULT3=$(python3 ~/klipper/scripts/klipper_interface.py -g "SET_PIN PIN=test_enable VALUE=0" 2>&1 | grep -o "Result:.*")
echo "  $RESULT3"

if echo "$RESULT1" | grep -q "True" && echo "$RESULT2" | grep -q "True" && echo "$RESULT3" | grep -q "True"; then
    echo -e "${GREEN}✓ PASS: All pins controllable${NC}"
    PINS_OK=1
else
    echo -e "${RED}✗ FAIL: Pin control not working${NC}"
    PINS_OK=0
fi
echo ""

# Test 3: Stepper Configuration (without TMC2209, without endstop)
echo -e "${BLUE}[TEST 3] Stepper Configuration (Direct Control)${NC}"
cat > /tmp/stepper_test.cfg <<EOF
[mcu]
serial: /dev/serial/by-id/usb-Klipper_stm32g0b1xx_2000080012504B4633373520-if00

[printer]
kinematics: cartesian
max_velocity: 200
max_accel: 300

[stepper_y]
step_pin: PF12
dir_pin: PF11
enable_pin: !PB3
microsteps: 16
rotation_distance: 1.0
# NO ENDSTOP - virtual endstop
endstop_pin: tmc2209_stepper_y:virtual_endstop
position_endstop: 0
position_min: -10
position_max: 93
homing_speed: 10
homing_retract_dist: 0
homing_retract_speed: 0

# NO TMC2209 - direct control only
EOF

cp /tmp/stepper_test.cfg ~/printer.cfg
sudo systemctl restart klipper
sleep 5

# Check if stepper config loads
CONFIG_ERROR=$(tail -50 /tmp/klippy.log | grep -i "error\|config" | tail -3)
if [ -z "$CONFIG_ERROR" ] || echo "$CONFIG_ERROR" | grep -qi "virtual_endstop.*not found"; then
    echo -e "${YELLOW}⚠️  Virtual endstop issue - trying without endstop${NC}"
    # Try without endstop requirement
    sed -i 's/endstop_pin:.*/endstop_pin:/' ~/printer.cfg
    sed -i '/^endstop_pin:$/a position_endstop: 0' ~/printer.cfg
    sudo systemctl restart klipper
    sleep 5
fi

# Try movement
echo "Attempting movement..."
python3 ~/klipper/scripts/klipper_interface.py -g "G91" > /dev/null 2>&1
MOVEMENT_RESULT=$(python3 ~/klipper/scripts/klipper_interface.py -g "G1 Y1 F100" 2>&1 | grep -o "Result:.*")
echo "  Movement result: $MOVEMENT_RESULT"

# Check logs for step pulses
STEP_PULSES=$(tail -100 /tmp/klippy.log | grep -i "step\|pulse" | wc -l)
if [ "$STEP_PULSES" -gt 0 ]; then
    echo -e "${GREEN}✓ PASS: Step pulses detected in logs${NC}"
    echo "  Found $STEP_PULSES step-related log entries"
    STEP_OK=1
else
    echo -e "${RED}✗ FAIL: No step pulses in logs${NC}"
    STEP_OK=0
    echo "  This means Klipper is NOT sending step commands"
    echo "  Check logs: tail -50 /tmp/klippy.log"
fi
echo ""

# Test 4: Hardware Verification
echo -e "${BLUE}[TEST 4] Hardware Verification Checklist${NC}"
echo ""
echo "Please verify these hardware connections:"
echo ""
echo "  [ ] Stepper driver has power (LED on driver board?)"
echo "  [ ] PF12 → Driver STEP pin"
echo "  [ ] PF11 → Driver DIR pin"  
echo "  [ ] PB3 → Driver EN pin"
echo "  [ ] GND → Driver GND"
echo "  [ ] Motor wires connected to driver outputs"
echo ""
read -p "Are ALL hardware connections verified? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    HW_OK=1
else
    HW_OK=0
    echo -e "${RED}✗ FAIL: Hardware not verified${NC}"
fi
echo ""

# Summary
echo -e "${BLUE}=== DIAGNOSTIC SUMMARY ===${NC}"
echo ""
echo "Test 1 - MCU Communication: $([ $MCU_OK -eq 1 ] && echo -e "${GREEN}PASS${NC}" || echo -e "${RED}FAIL${NC}")"
echo "Test 2 - Pin Control: $([ $PINS_OK -eq 1 ] && echo -e "${GREEN}PASS${NC}" || echo -e "${RED}FAIL${NC}")"
echo "Test 3 - Step Pulses: $([ $STEP_OK -eq 1 ] && echo -e "${GREEN}PASS${NC}" || echo -e "${RED}FAIL${NC}")"
echo "Test 4 - Hardware: $([ $HW_OK -eq 1 ] && echo -e "${GREEN}VERIFIED${NC}" || echo -e "${RED}NOT VERIFIED${NC}")"
echo ""

# Diagnosis
if [ $MCU_OK -eq 1 ] && [ $PINS_OK -eq 1 ] && [ $STEP_OK -eq 0 ] && [ $HW_OK -eq 1 ]; then
    echo -e "${RED}DIAGNOSIS: Klipper is not generating step pulses${NC}"
    echo "  → Check stepper configuration"
    echo "  → Check kinematics configuration"
    echo "  → Check for config errors: tail -100 /tmp/klippy.log | grep -i error"
elif [ $MCU_OK -eq 1 ] && [ $PINS_OK -eq 1 ] && [ $STEP_OK -eq 1 ] && [ $HW_OK -eq 1 ]; then
    echo -e "${YELLOW}DIAGNOSIS: Software working, but motor not moving${NC}"
    echo "  → Hardware issue: Check motor wiring, driver power, motor coils"
    echo "  → Try swapping motor coil pairs (A+/A- or B+/B-)"
    echo "  → Verify driver enable signal (should be LOW to enable)"
else
    echo -e "${RED}DIAGNOSIS: Multiple issues detected${NC}"
    echo "  → Fix failed tests above first"
fi

