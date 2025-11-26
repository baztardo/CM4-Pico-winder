#!/bin/bash
# Deploy fixed configuration to CM4

set -e

echo "=========================================="
echo "Deploying fixed winding configuration..."
echo "=========================================="

# Copy updated Python module (with reactor pause fix)
echo "📦 Copying hw_counter.py..."
scp ~/Documents/GitHub/CM4-Pico-winder/klipper-install/extras/hw_counter.py winder@winder.local:~/klipper/klippy/extras/

# Copy updated macros
echo "📜 Copying winding macros..."
scp ~/Documents/GitHub/CM4-Pico-winder/config/macros/winding.cfg winder@winder.local:~/printer_data/config/macros/

# Update printer.cfg with lower max_accel
echo "⚙️  Updating printer.cfg..."
ssh winder@winder.local "sed -i 's/max_accel: [0-9]*/max_accel: 20/' ~/printer_data/config/printer.cfg"

# Verify changes
echo ""
echo "✅ Verifying changes..."
ssh winder@winder.local "grep 'max_accel' ~/printer_data/config/printer.cfg"

# Restart Klipper
echo ""
echo "🔄 Restarting Klipper..."
ssh winder@winder.local "sudo systemctl restart klipper"

echo ""
echo "=========================================="
echo "✅ Deployment complete!"
echo "=========================================="
echo ""
echo "Test sequence:"
echo "  1. ssh winder@winder.local"
echo "  2. python3 ~/klipper/scripts/klipper_interface.py -g \"HOME_TRAVERSE\""
echo "  3. python3 ~/klipper/scripts/klipper_interface.py -g \"START_WINDING RPM=300 LAYERS=2\""
echo ""

