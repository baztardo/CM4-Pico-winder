#!/bin/bash
# Test motor with direct step pulses (bypass TMC2209)

echo "============================================================"
echo "DIRECT STEP PULSE TEST"
echo "============================================================"
echo ""
echo "This test bypasses TMC2209 and sends step pulses directly"
echo "to verify motor wiring and power."
echo ""

# Create temporary config with output_pin for step
echo "Creating test config..."
cat > /tmp/test_direct_steps.cfg << 'EOF'
[mcu]
serial: /dev/serial/by-id/usb-Klipper_stm32g0b1xx_2000080012504B4633373520-if00

[printer]
kinematics: winder
max_velocity: 200
max_accel: 300

[stepper_y]
step_pin: PF12
dir_pin: PF11
enable_pin: !PB3
endstop_pin: ^PF3
position_endstop: 0
position_min: -10
position_max: 93
homing_speed: 10
homing_retract_dist: 5.0
homing_retract_speed: 5
EOF

echo "⚠️  WARNING: This will temporarily change your config!"
echo "   Backup will be created: ~/printer.cfg.backup"
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 1
fi

# Backup
cp ~/printer.cfg ~/printer.cfg.backup.$(date +%Y%m%d_%H%M%S)

# Use test config
cp /tmp/test_direct_steps.cfg ~/printer.cfg

echo ""
echo "Restarting Klipper..."
sudo systemctl restart klipper
sleep 5

echo ""
echo "Testing direct step pulses..."
echo "👀 WATCH THE MOTOR - does it move now?"
echo ""

# Enable stepper
python3 ~/klipper/scripts/klipper_interface.py -g "SET_STEPPER_ENABLE STEPPER=stepper_y ENABLE=1"
sleep 0.5

# Try movement
python3 ~/klipper/scripts/klipper_interface.py -g "G91"
python3 ~/klipper/scripts/klipper_interface.py -g "G1 Y1 F10"

sleep 2

# Disable
python3 ~/klipper/scripts/klipper_interface.py -g "SET_STEPPER_ENABLE STEPPER=stepper_y ENABLE=0"

echo ""
echo "============================================================"
echo "RESTORE CONFIG:"
echo "============================================================"
echo ""
echo "To restore your original config:"
echo "  cp ~/printer.cfg.backup.* ~/printer.cfg"
echo "  sudo systemctl restart klipper"

