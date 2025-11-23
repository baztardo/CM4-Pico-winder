#!/bin/bash
# Copy BLDC motor module to CM4 - CORRECT paths

CM4_HOST="${1:-winder.local}"
CM4_USER="${2:-winder}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLDC_FILE="$SCRIPT_DIR/../extras/bldc_motor.py"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Copy BLDC Motor Module to CM4${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if [ ! -f "$BLDC_FILE" ]; then
    echo -e "${RED}✗ File not found: $BLDC_FILE${NC}"
    exit 1
fi

echo -e "${BLUE}Source file:${NC} $BLDC_FILE"
echo -e "${BLUE}Destination:${NC} $CM4_USER@$CM4_HOST:~/klipper/klippy/extras/bldc_motor.py"
echo ""

# Copy file
echo -e "${BLUE}Copying file...${NC}"
scp "$BLDC_FILE" "$CM4_USER@$CM4_HOST:~/klipper/klippy/extras/bldc_motor.py"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ File copied successfully${NC}"
else
    echo -e "${RED}✗ Copy failed${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Next steps on CM4:${NC}"
echo -e "${YELLOW}1. Add [bldc_motor] section to ~/printer.cfg${NC}"
echo -e "${YELLOW}2. Restart Klipper: sudo systemctl restart klipper${NC}"
echo -e "${BLUE}========================================${NC}"

