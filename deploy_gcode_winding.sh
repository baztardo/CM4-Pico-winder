#!/bin/bash
# Deploy G-code-based winding system

set -e

echo "=========================================="
echo "Deploying G-code Winding System..."
echo "=========================================="

# Copy G-code generator script
echo "📜 Copying G-code generator..."
scp ~/Documents/GitHub/CM4-Pico-winder/klipper-install/scripts/generate_winding_gcode.py winder@winder.local:~/
ssh winder@winder.local "chmod +x ~/generate_winding_gcode.py"

# Copy macros
echo "📝 Copying G-code winding macros..."
ssh winder@winder.local "mkdir -p ~/printer_data/config/macros"
scp ~/Documents/GitHub/CM4-Pico-winder/config/macros/gcode_winding.cfg winder@winder.local:~/printer_data/config/macros/

# Add include to printer.cfg if not already there
echo "⚙️  Updating printer.cfg..."
ssh winder@winder.local "grep -q 'gcode_winding.cfg' ~/printer_data/config/printer.cfg || echo '[include macros/gcode_winding.cfg]' >> ~/printer_data/config/printer.cfg"

# Create gcodes directory if it doesn't exist
echo "📁 Creating gcodes directory..."
ssh winder@winder.local "mkdir -p ~/printer_data/gcodes"

# Generate a test file
echo "🧪 Generating test G-code file..."
ssh winder@winder.local "python3 ~/generate_winding_gcode.py --rpm 100 --layers 2 --output ~/printer_data/gcodes/test_100rpm_2layers.gcode"

# Restart Klipper
echo ""
echo "🔄 Restarting Klipper..."
ssh winder@winder.local "sudo systemctl restart klipper"

echo ""
echo "=========================================="
echo "✅ G-code Winding System Deployed!"
echo "=========================================="
echo ""
echo "BENEFITS:"
echo "  ✅ Uses Klipper's FULL motion planning"
echo "  ✅ Proper trapezoid acceleration on EVERY move"
echo "  ✅ Lookahead optimization"
echo "  ✅ Can pause/resume/cancel like a print job"
echo "  ✅ Progress tracking"
echo "  ✅ Repeatable winding operations"
echo ""
echo "USAGE:"
echo ""
echo "1. Generate a winding file:"
echo "   ssh winder@winder.local"
echo "   python3 ~/generate_winding_gcode.py --rpm 300 --layers 10 --output ~/printer_data/gcodes/humbucker.gcode"
echo ""
echo "2. Run the file:"
echo "   python3 ~/klipper/scripts/klipper_interface.py -g \"SDCARD_PRINT_FILE FILENAME=humbucker.gcode\""
echo ""
echo "3. Or use the web interface:"
echo "   - Upload .gcode file to ~/printer_data/gcodes/"
echo "   - Click \"Print\" in Moonraker/Mainsail"
echo ""
echo "4. Control during winding:"
echo "   M24 - Resume/Start"
echo "   M25 - Pause"
echo "   M27 - Get progress"
echo ""
echo "Test file created: ~/printer_data/gcodes/test_100rpm_2layers.gcode"
echo ""

