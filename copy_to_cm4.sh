#!/bin/bash
# Script to copy winder files to CM4
# Usage: ./copy_to_cm4.sh <CM4_IP> [winder_user]

CM4_IP="${1:-192.168.1.100}"
CM4_USER="${2:-winder}"
CM4_PATH="~/klipper"

echo "Copying files to CM4 at $CM4_USER@$CM4_IP..."

# Copy kinematics
echo "Copying winder kinematics..."
scp klippy/kinematics/winder.py $CM4_USER@$CM4_IP:$CM4_PATH/klippy/kinematics/

# Copy winder controller
echo "Copying winder controller..."
scp klippy/extras/winder.py $CM4_USER@$CM4_IP:$CM4_PATH/klippy/extras/

# Copy config
echo "Copying printer config..."
scp config/printer.cfg $CM4_USER@$CM4_IP:$CM4_PATH/config/

# Copy interface scripts
echo "Copying interface scripts..."
scp scripts/klipper_interface.py $CM4_USER@$CM4_IP:$CM4_PATH/scripts/
scp scripts/winder_control.py $CM4_USER@$CM4_IP:$CM4_PATH/scripts/
scp scripts/README_INTERFACE.md $CM4_USER@$CM4_IP:$CM4_PATH/scripts/ 2>/dev/null || true
ssh $CM4_USER@$CM4_IP "chmod +x $CM4_PATH/scripts/klipper_interface.py $CM4_PATH/scripts/winder_control.py"

echo ""
echo "Files copied! Now on CM4:"
echo "1. Update serial port in printer.cfg if needed:"
echo "   nano ~/klipper/config/printer.cfg"
echo ""
echo "2. Restart Klipper:"
echo "   sudo systemctl restart klipper"
echo ""
echo "3. Check log:"
echo "   tail -f /tmp/klippy.log"

