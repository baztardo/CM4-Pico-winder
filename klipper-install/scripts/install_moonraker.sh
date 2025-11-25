#!/bin/bash
# Install Moonraker for Klipper Winder
# Moonraker provides the web API and interface

set -e

echo "=========================================="
echo "Installing Moonraker"
echo "=========================================="

# Check if running as winder user
if [ "$USER" != "winder" ]; then
    echo "ERROR: Must run as 'winder' user"
    exit 1
fi

cd ~

# Clone Moonraker if not exists
if [ ! -d "moonraker" ]; then
    echo "Cloning Moonraker..."
    git clone https://github.com/Arksine/moonraker.git
else
    echo "Moonraker directory exists, updating..."
    cd moonraker
    git pull
    cd ~
fi

# Install dependencies
echo "Installing dependencies..."
cd ~/moonraker/scripts
./install-moonraker.sh

# Create Moonraker config
echo "Creating Moonraker configuration..."
mkdir -p ~/printer_data/config
mkdir -p ~/printer_data/logs
mkdir -p ~/printer_data/gcodes

cat > ~/printer_data/config/moonraker.conf << 'EOF'
[server]
host: 0.0.0.0
port: 7125
klippy_uds_address: /tmp/klippy_uds

[file_manager]
enable_object_processing: False

[authorization]
trusted_clients:
    10.0.0.0/8
    127.0.0.0/8
    169.254.0.0/16
    172.16.0.0/12
    192.168.0.0/16
    FE80::/10
    ::1/128
cors_domains:
    *.lan
    *.local
    *://localhost
    *://localhost:*
    *://my.mainsail.xyz
    *://app.fluidd.xyz

[octoprint_compat]

[history]

[update_manager]
channel: dev
refresh_interval: 168

[update_manager mainsail]
type: web
channel: stable
repo: mainsail-crew/mainsail
path: ~/mainsail

# Winder-specific configuration
[winder]
# Custom winder endpoints and functionality
EOF

echo ""
echo "=========================================="
echo "Moonraker Installation Complete"
echo "=========================================="
echo ""
echo "To start Moonraker:"
echo "  sudo systemctl start moonraker"
echo ""
echo "To enable on boot:"
echo "  sudo systemctl enable moonraker"
echo ""
echo "Web interface will be available at:"
echo "  http://$(hostname -I | awk '{print $1}'):7125"
echo ""

