#!/bin/bash
# Install KlipperScreen for Winder GUI
# Touchscreen interface for the winder system

set -e

echo "=========================================="
echo "Installing KlipperScreen"
echo "=========================================="

# Check if running as winder user
if [ "$USER" != "winder" ]; then
    echo "ERROR: Must run as 'winder' user"
    exit 1
fi

cd ~

# Clone KlipperScreen if not exists
if [ ! -d "KlipperScreen" ]; then
    echo "Cloning KlipperScreen..."
    git clone https://github.com/jordanruthe/KlipperScreen.git
else
    echo "KlipperScreen directory exists, updating..."
    cd KlipperScreen
    git pull
    cd ~
fi

# Install dependencies
echo "Installing dependencies..."
cd ~/KlipperScreen/scripts
./KlipperScreen-install.sh

# Create KlipperScreen config
echo "Creating KlipperScreen configuration..."
mkdir -p ~/printer_data/config

cat > ~/printer_data/config/KlipperScreen.conf << 'EOF'
[main]
moonraker_host: 127.0.0.1
moonraker_port: 7125

# Winder-specific theme
theme: winder_dark
screen_blanking: 300
show_heater_power: False
show_scroll_steppers: False

[printer Winder]
moonraker_host: 127.0.0.1
moonraker_port: 7125

# Custom panels for winder
[menu __main]
name: Main Menu

[menu __main winding]
name: Winding
icon: extruder
panel: winding_panel

[menu __main calibration]
name: Calibration
icon: settings
panel: calibration_panel

[menu __main sensors]
name: Sensors
icon: info
panel: sensors_panel

# Hide 3D printer specific menus
[menu __main temperature]
enable: False

[menu __main extrude]
enable: False

[menu __main bed_mesh]
enable: False
EOF

echo ""
echo "=========================================="
echo "KlipperScreen Installation Complete"
echo "=========================================="
echo ""
echo "To start KlipperScreen:"
echo "  sudo systemctl start KlipperScreen"
echo ""
echo "To enable on boot:"
echo "  sudo systemctl enable KlipperScreen"
echo ""
echo "Note: Requires a display connected to the CM4"
echo ""

