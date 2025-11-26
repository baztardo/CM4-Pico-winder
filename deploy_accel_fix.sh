#!/bin/bash
# Deploy acceleration fix to CM4

set -e

echo "=========================================="
echo "Deploying ACCELERATION FIX..."
echo "=========================================="

# Copy fixed winder_control.py
echo "📦 Copying winder_control.py with proper G-code moves..."
scp ~/Documents/GitHub/CM4-Pico-winder/klipper-install/extras/winder_control.py winder@winder.local:~/klipper/klippy/extras/

# Restart Klipper
echo ""
echo "🔄 Restarting Klipper..."
ssh winder@winder.local "sudo systemctl restart klipper"

echo ""
echo "=========================================="
echo "✅ ACCELERATION FIX DEPLOYED!"
echo "=========================================="
echo ""
echo "NOW your traverse will use proper trapezoid acceleration!"
echo "- Smooth acceleration from 0 to target speed"
echo "- Smooth deceleration back to 0"
echo "- Respects max_accel: 300 mm/s²"
echo ""
echo "Test it:"
echo "  ssh winder@winder.local"
echo "  python3 ~/klipper/scripts/klipper_interface.py -g \"START_WINDING RPM=300 LAYERS=2\""
echo ""

