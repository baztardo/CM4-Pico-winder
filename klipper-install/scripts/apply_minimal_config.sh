#!/bin/bash
# Apply minimal Klipper configuration for winder project
# Usage: ./apply_minimal_config.sh [CM4_HOST]

CM4_HOST="${1:-winder@winder.local}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/.config.winder-minimal"

echo "Applying minimal Klipper configuration for winder..."
echo "Target: $CM4_HOST"
echo ""

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Config file not found: $CONFIG_FILE"
    exit 1
fi

# Copy config to CM4
echo "Copying minimal config to CM4..."
scp "$CONFIG_FILE" "$CM4_HOST:~/klipper/.config"

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Config copied successfully!"
    echo ""
    echo "Next steps on CM4:"
    echo "  1. cd ~/klipper"
    echo "  2. make clean"
    echo "  3. make"
    echo "  4. make flash FLASH_DEVICE=/dev/serial/by-id/usb-Klipper_stm32g0b1xx_*-if00"
    echo ""
    echo "Or run automatically:"
    echo "  ssh $CM4_HOST 'cd ~/klipper && make clean && make'"
else
    echo ""
    echo "✗ Failed to copy config"
    echo "  Make sure SSH is working: ssh $CM4_HOST"
    exit 1
fi

