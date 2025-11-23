#!/bin/bash
# Quick fix for MCU shutdown state
# Restarts Klipper service to clear shutdown state

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Fixing MCU Shutdown ===${NC}"
echo ""

# Check if Klipper is running
if ! sudo systemctl is-active --quiet klipper; then
    echo -e "${YELLOW}Klipper service is not running - starting it...${NC}"
    sudo systemctl start klipper
    sleep 3
fi

# Restart Klipper service
echo -e "${BLUE}Restarting Klipper service to clear shutdown state...${NC}"
sudo systemctl restart klipper

echo -e "${GREEN}✓ Klipper service restarted${NC}"
echo ""
echo "Waiting 5 seconds for MCU to reconnect..."
sleep 5

# Check if MCU is ready
echo ""
echo -e "${BLUE}Checking MCU status...${NC}"
if python3 "$(dirname "$0")/klipper_interface.py" --info > /dev/null 2>&1; then
    INFO=$(python3 "$(dirname "$0")/klipper_interface.py" --info 2>/dev/null)
    STATE=$(echo "$INFO" | grep -o '"state":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
    
    if [ "$STATE" = "ready" ]; then
        echo -e "${GREEN}✓ MCU is ready!${NC}"
        echo "  State: $STATE"
        exit 0
    else
        echo -e "${YELLOW}⚠️  MCU state: $STATE${NC}"
        echo "  May need more time - check logs: tail -50 /tmp/klippy.log"
        exit 1
    fi
else
    echo -e "${RED}✗ Still cannot connect to MCU${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check USB: lsusb | grep -i stm"
    echo "  2. Check serial: ls -l /dev/serial/by-id/"
    echo "  3. Check logs: tail -50 /tmp/klippy.log"
    echo "  4. Try power cycling the board"
    exit 1
fi

