#!/bin/bash
# Apply working config to CM4
# This copies the complete working config from klipper-install to ~/printer.cfg

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$INSTALL_DIR/config/generic-bigtreetech-manta-m8p-V1_1.cfg"
TARGET_CONFIG="$HOME/printer.cfg"

echo "============================================================"
echo "Applying Working Config to CM4"
echo "============================================================"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Config file not found: $CONFIG_FILE"
    exit 1
fi

# Backup existing config
if [ -f "$TARGET_CONFIG" ]; then
    BACKUP="$TARGET_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
    echo "📦 Backing up existing config to: $BACKUP"
    cp "$TARGET_CONFIG" "$BACKUP"
fi

# Copy config
echo "📋 Copying config..."
cp "$CONFIG_FILE" "$TARGET_CONFIG"

# Update serial port if needed
SERIAL_PORT=$(ls /dev/serial/by-id/usb-Klipper_stm32g0b1xx_* 2>/dev/null | head -1)
if [ -n "$SERIAL_PORT" ]; then
    echo "🔌 Updating serial port to: $SERIAL_PORT"
    sed -i "s|serial:.*|serial: $SERIAL_PORT|" "$TARGET_CONFIG"
else
    echo "⚠️  No MCU serial port found - config may need manual update"
fi

echo "✅ Config applied: $TARGET_CONFIG"
echo ""
echo "Next steps:"
echo "  1. sudo systemctl restart klipper"
echo "  2. tail -f /tmp/klippy.log"
echo "  3. Check for 'Klipper state: Ready'"

