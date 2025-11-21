#!/bin/bash
# Basic hardware test - verify MCU is working and pins are responding

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Basic Hardware Diagnostic ===${NC}"
echo ""

# Test 1: Check if MCU is responding
echo -e "${BLUE}Test 1: MCU Communication${NC}"
MCU_RESPONSE=$(python3 ~/klipper/scripts/klipper_interface.py --query mcu 2>&1 | head -5)
if echo "$MCU_RESPONSE" | grep -q "mcu_version"; then
    echo -e "${GREEN}✓ MCU is responding${NC}"
else
    echo -e "${RED}❌ MCU not responding properly${NC}"
    echo "$MCU_RESPONSE"
fi
echo ""

# Test 2: Check Klipper logs for step pulses
echo -e "${BLUE}Test 2: Checking if step pulses are being sent${NC}"
echo "Sending movement command and checking logs..."
python3 ~/klipper/scripts/klipper_interface.py -g "G91" > /dev/null 2>&1
python3 ~/klipper/scripts/klipper_interface.py -g "G1 Y1 F100" > /dev/null 2>&1 &
sleep 2
if tail -100 /tmp/klippy.log | grep -qi "step\|stepper\|move"; then
    echo -e "${GREEN}✓ Step commands found in logs${NC}"
    tail -100 /tmp/klippy.log | grep -i "step\|stepper\|move" | tail -5
else
    echo -e "${YELLOW}⚠️  No step commands in logs${NC}"
fi
echo ""

# Test 3: Check for errors
echo -e "${BLUE}Test 3: Checking for errors${NC}"
ERRORS=$(tail -200 /tmp/klippy.log | grep -i "error\|failed\|shutdown\|invalid" | tail -10)
if [ -n "$ERRORS" ]; then
    echo -e "${RED}❌ Errors found:${NC}"
    echo "$ERRORS"
else
    echo -e "${GREEN}✓ No recent errors${NC}"
fi
echo ""

# Test 4: Test output pins directly
echo -e "${BLUE}Test 4: Testing output pins directly${NC}"
echo "Creating test config with output_pin for stepper control..."
cat > /tmp/test_output_pins.cfg <<EOF
[mcu]
serial: /dev/serial/by-id/usb-Klipper_stm32g0b1xx_2000080012504B4633373520-if00

[printer]
kinematics: none
max_velocity: 200
max_accel: 300

# Test output pins directly
[output_pin stepper_y_step]
pin: PF12
pwm: False

[output_pin stepper_y_dir]
pin: PF11
pwm: False

[output_pin stepper_y_enable]
pin: !PB3
pwm: False
value: 1  # Enable stepper
EOF

echo "Test config created: /tmp/test_output_pins.cfg"
echo ""
echo "This will test if pins can be controlled directly"
echo ""

# Test 5: Hardware checklist
echo -e "${BLUE}Test 5: Hardware Checklist${NC}"
echo ""
echo "Please verify:"
echo "  [ ] Stepper driver has power (12V/24V LED on?)"
echo "  [ ] PF12 (STEP) connected to driver STEP pin"
echo "  [ ] PF11 (DIR) connected to driver DIR pin"
echo "  [ ] PB3 (ENABLE) connected to driver EN pin"
echo "  [ ] GND connected between MP8 and driver"
echo "  [ ] Driver motor outputs connected to stepper motor"
echo "  [ ] Stepper motor coils connected correctly"
echo ""
echo "TMC2209 specific:"
echo "  [ ] PF13 (UART) connected to driver PDN_UART pin"
echo "  [ ] Driver has 5V power (if separate from motor power)"
echo ""

# Test 6: Try manual step pulse
echo -e "${BLUE}Test 6: Manual Step Pulse Test${NC}"
echo ""
echo "Try manually toggling step pin:"
echo "  python3 ~/klipper/scripts/klipper_interface.py -g 'SET_PIN PIN=stepper_y_step VALUE=1'"
echo "  sleep 0.001"
echo "  python3 ~/klipper/scripts/klipper_interface.py -g 'SET_PIN PIN=stepper_y_step VALUE=0'"
echo ""
echo "Repeat 10 times - motor should move slightly if wiring is correct"
echo ""

echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Verify all hardware connections"
echo "2. Check stepper driver power LED"
echo "3. Try manual step pulse test"
echo "4. Check if motor coils are correct (swap A+/A- or B+/B- if needed)"

