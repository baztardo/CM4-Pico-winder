#!/bin/bash
# Step-by-step traverse testing - start simple, add complexity

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Step-by-Step Traverse Testing ===${NC}"
echo ""

# Step 1: Test WITHOUT TMC2209 (direct stepper control)
echo -e "${BLUE}Step 1: Testing WITHOUT TMC2209 (direct control)...${NC}"
cat > /tmp/test_no_tmc.cfg <<EOF
[mcu]
serial: /dev/serial/by-id/usb-Klipper_stm32g0b1xx_2000080012504B4633373520-if00

[stepper_y]
step_pin: PF12
dir_pin: PF11
enable_pin: !PB3
microsteps: 16
rotation_distance: 1.0
# Virtual endstop - bypass physical endstop for testing
endstop_pin: tmc2209_stepper_y:virtual_endstop
position_endstop: 0
position_min: 0
position_max: 93
homing_speed: 10
homing_retract_dist: 5.0
homing_retract_speed: 5

# TMC2209 COMMENTED OUT - testing direct control
# [tmc2209 stepper_y]
# uart_pin: PF13
# run_current: 0.400
# hold_current: 0.100

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

echo "✓ Test config created: /tmp/test_no_tmc.cfg"
echo ""
echo "This config:"
echo "  - Bypasses physical endstop (uses virtual)"
echo "  - Disables TMC2209 (direct stepper control)"
echo "  - Tests basic movement"
echo ""
read -p "Apply this config and test? [Y/n] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    cp ~/printer.cfg ~/printer.cfg.backup.$(date +%s)
    cp /tmp/test_no_tmc.cfg ~/printer.cfg
    echo "✓ Config applied"
    echo ""
    echo "Restarting Klipper..."
    sudo systemctl restart klipper
    sleep 5
    echo ""
    echo "Now try movement:"
    echo "  python3 ~/klipper/scripts/klipper_interface.py -g 'G91'"
    echo "  python3 ~/klipper/scripts/klipper_interface.py -g 'G1 Y5 F100'"
    echo "  python3 ~/klipper/scripts/klipper_interface.py -g 'G90'"
fi

echo ""
echo -e "${BLUE}Step 2: If Step 1 works, test WITH TMC2209...${NC}"
cat > /tmp/test_with_tmc.cfg <<EOF
[mcu]
serial: /dev/serial/by-id/usb-Klipper_stm32g0b1xx_2000080012504B4633373520-if00

[stepper_y]
step_pin: PF12
dir_pin: PF11
enable_pin: !PB3
microsteps: 16
rotation_distance: 1.0
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

echo "✓ Test config with TMC2209 ready: /tmp/test_with_tmc.cfg"
echo ""

echo -e "${BLUE}Step 3: If movement works, fix physical endstop...${NC}"
echo "Try different endstop configurations:"
echo "  1. endstop_pin: PF3        (no inversion)"
echo "  2. endstop_pin: ^PF3       (inverted)"
echo "  3. endstop_pin: !PF3       (pull-down)"
echo "  4. endstop_pin: ^!PF3      (inverted + pull-down)"

