#!/bin/bash
# Fix serial port in printer.cfg
# Detects actual STM32 serial port and updates config

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

CM4_HOST="${1:-winder@winder.local}"
CONFIG_FILE="~/printer.cfg"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Fix Serial Port in printer.cfg${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if we're running locally or on CM4
if [ "$CM4_HOST" = "local" ] || [ -z "$CM4_HOST" ]; then
    echo -e "${BLUE}Checking local serial ports...${NC}"
    SERIAL_PORTS=$(ls /dev/serial/by-id/usb-Klipper_stm32g0b1xx_* 2>/dev/null || echo "")
    CONFIG_FILE_LOCAL="klipper-install/config/printer-manta-m4p.cfg"
else
    echo -e "${BLUE}Checking serial ports on CM4 ($CM4_HOST)...${NC}"
    SERIAL_PORTS=$(ssh "$CM4_HOST" "ls /dev/serial/by-id/usb-Klipper_stm32g0b1xx_* 2>/dev/null" || echo "")
fi

if [ -z "$SERIAL_PORTS" ]; then
    echo -e "${RED}✗ No STM32 serial ports found!${NC}"
    echo ""
    echo "Troubleshooting:"
    if [ "$CM4_HOST" != "local" ]; then
        echo "  1. Check USB connection: ssh $CM4_HOST 'lsusb | grep -i stm'"
        echo "  2. Check all serial ports: ssh $CM4_HOST 'ls -l /dev/serial/by-id/'"
    else
        echo "  1. Check USB connection: lsusb | grep -i stm"
        echo "  2. Check all serial ports: ls -l /dev/serial/by-id/"
    fi
    exit 1
fi

# Get the first matching port
SERIAL_PORT=$(echo "$SERIAL_PORTS" | head -1)
echo -e "${GREEN}✓ Found serial port: $SERIAL_PORT${NC}"
echo ""

# Update config file
if [ "$CM4_HOST" = "local" ] || [ -z "$CM4_HOST" ]; then
    echo -e "${BLUE}Updating local config file...${NC}"
    if [ -f "$CONFIG_FILE_LOCAL" ]; then
        # Backup
        cp "$CONFIG_FILE_LOCAL" "$CONFIG_FILE_LOCAL.backup.$(date +%s)"
        echo "  ✓ Backup created"
        
        # Update serial port
        sed -i.bak "s|serial:.*|serial: $SERIAL_PORT|" "$CONFIG_FILE_LOCAL"
        rm -f "$CONFIG_FILE_LOCAL.bak"
        echo -e "${GREEN}✓ Config updated: $CONFIG_FILE_LOCAL${NC}"
    else
        echo -e "${RED}✗ Config file not found: $CONFIG_FILE_LOCAL${NC}"
        exit 1
    fi
else
    echo -e "${BLUE}Updating config file on CM4...${NC}"
    # Backup
    ssh "$CM4_HOST" "cp $CONFIG_FILE $CONFIG_FILE.backup.\$(date +%s) 2>/dev/null || echo 'No existing file to backup'"
    
    # Update serial port
    ssh "$CM4_HOST" "sed -i.bak 's|serial:.*|serial: $SERIAL_PORT|' $CONFIG_FILE && rm -f $CONFIG_FILE.bak"
    echo -e "${GREEN}✓ Config updated on CM4${NC}"
    
    # Verify
    echo ""
    echo -e "${BLUE}Verifying update...${NC}"
    UPDATED_SERIAL=$(ssh "$CM4_HOST" "grep '^serial:' $CONFIG_FILE | head -1")
    echo "  Current serial setting: $UPDATED_SERIAL"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Serial port fixed!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Next steps:"
if [ "$CM4_HOST" != "local" ]; then
    echo "  1. Restart Klipper: ssh $CM4_HOST 'sudo systemctl restart klipper'"
    echo "  2. Check logs: ssh $CM4_HOST 'tail -f /tmp/klippy.log'"
else
    echo "  1. Copy config to CM4: ./copy_printer_cfg_to_cm4.sh"
    echo "  2. Restart Klipper on CM4"
fi

