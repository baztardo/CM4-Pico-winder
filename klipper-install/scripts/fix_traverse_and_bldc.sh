#!/bin/bash
# Comprehensive fix for traverse stepper and BLDC motor
# Step-by-step troubleshooting

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Traverse Stepper & BLDC Motor Diagnostic ===${NC}"
echo ""

# Step 1: Check config file
echo -e "${BLUE}Step 1: Checking printer.cfg...${NC}"
if [ ! -f ~/printer.cfg ]; then
    echo -e "${RED}❌ printer.cfg not found!${NC}"
    exit 1
fi

echo "✓ Config file exists"
echo ""

# Step 2: Check stepper_y configuration
echo -e "${BLUE}Step 2: Checking stepper_y configuration...${NC}"
STEPPER_Y_CONFIG=$(grep -A 10 "\[stepper_y\]" ~/printer.cfg)
echo "$STEPPER_Y_CONFIG"
echo ""

# Step 3: Check if TMC2209 is configured
echo -e "${BLUE}Step 3: Checking TMC2209 configuration...${NC}"
if grep -q "\[tmc2209 stepper_y\]" ~/printer.cfg; then
    echo -e "${GREEN}✓ TMC2209 section found${NC}"
    TMC_CONFIG=$(grep -A 5 "\[tmc2209 stepper_y\]" ~/printer.cfg)
    echo "$TMC_CONFIG"
else
    echo -e "${YELLOW}⚠️  TMC2209 section NOT found${NC}"
    echo "   This might be the issue - TMC2209 needs to be configured"
fi
echo ""

# Step 4: Check endstop configuration
echo -e "${BLUE}Step 4: Checking endstop configuration...${NC}"
ENDSTOP=$(grep "endstop_pin:" ~/printer.cfg | grep stepper_y -A 1 | grep endstop_pin)
echo "Current endstop: $ENDSTOP"
echo ""

# Step 5: Create a test config without endstop check
echo -e "${BLUE}Step 5: Creating test config (endstop bypassed)...${NC}"
cp ~/printer.cfg ~/printer.cfg.backup
echo "✓ Backup created: ~/printer.cfg.backup"

# Create a minimal test config
cat > /tmp/test_movement.cfg <<EOF
# Test config for movement - endstop bypassed
[mcu]
serial: /dev/serial/by-id/usb-Klipper_stm32g0b1xx_2000080012504B4633373520-if00

[stepper_y]
step_pin: PF12
dir_pin: PF11
enable_pin: !PB3
microsteps: 16
rotation_distance: 1.0
# Temporarily bypass endstop for testing
endstop_pin: tmc2209_stepper_y:virtual_endstop
position_endstop: 0
position_min: 0
position_max: 93
homing_speed: 10
homing_retract_dist: 5.0
homing_retract_speed: 5

[tmc2209 stepper_y]
uart_pin: PF13
run_current: 0.400
hold_current: 0.100
stealthchop_threshold: 0

[printer]
kinematics: winder
max_velocity: 200
max_accel: 300

[winder]
spindle_hall_pin: ^PF6
angle_sensor_pin: PA0
motor_pwm_pin: PC9
motor_dir_pin: PC8
motor_brake_pin: !PD1
EOF

echo "Test config created at /tmp/test_movement.cfg"
echo ""

# Step 6: Instructions
echo -e "${BLUE}Step 6: Next steps...${NC}"
echo ""
echo "Option A: Test with virtual endstop (bypass physical endstop)"
echo "  1. Copy test config: cp /tmp/test_movement.cfg ~/printer.cfg"
echo "  2. Restart Klipper: sudo systemctl restart klipper"
echo "  3. Wait 5 seconds"
echo "  4. Try movement: python3 ~/klipper/scripts/klipper_interface.py -g 'G91'"
echo "  5. Try movement: python3 ~/klipper/scripts/klipper_interface.py -g 'G1 Y5 F100'"
echo ""
echo "Option B: Fix physical endstop"
echo "  1. Check endstop wiring (PF3 pin)"
echo "  2. Try inverting: endstop_pin: ^PF3"
echo "  3. Or try: endstop_pin: !PF3"
echo ""
echo "Option C: Test TMC2209 communication"
echo "  1. Check UART wiring (PF13 pin)"
echo "  2. Try disabling TMC2209 temporarily (comment out [tmc2209] section)"
echo "  3. Use direct stepper control"
echo ""
echo -e "${YELLOW}Which option do you want to try first?${NC}"
echo "  A = Virtual endstop (recommended for testing)"
echo "  B = Fix physical endstop"
echo "  C = Test TMC2209"

