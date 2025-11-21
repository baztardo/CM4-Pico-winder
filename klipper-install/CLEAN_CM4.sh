#!/bin/bash
# Clean up CM4 - Remove Klipper installation for fresh start
# Usage: ./CLEAN_CM4.sh

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}CM4 Cleanup Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "This will remove:"
echo "  - Klipper installation (~/klipper)"
echo "  - Klipper service"
echo "  - Config files (~/printer.cfg)"
echo "  - Logs (/tmp/klippy.log)"
echo "  - Python virtual environment (~/klipper/klippy-env)"
echo ""
read -p "Continue? [y/N]: " answer

if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo -e "${GREEN}Stopping Klipper service...${NC}"
sudo systemctl stop klipper 2>/dev/null || echo "  (Service not running)"
sudo systemctl disable klipper 2>/dev/null || echo "  (Service not enabled)"

echo ""
echo -e "${GREEN}Removing Klipper installation...${NC}"
[ -d ~/klipper ] && rm -rf ~/klipper && echo "  ✓ Removed ~/klipper" || echo "  (Not found)"

echo ""
echo -e "${GREEN}Removing service files...${NC}"
sudo rm -f /etc/systemd/system/klipper.service
sudo rm -f /etc/default/klipper
sudo systemctl daemon-reload
echo "  ✓ Service files removed"

echo ""
echo -e "${GREEN}Removing config files...${NC}"
rm -f ~/printer.cfg ~/printer.cfg.backup ~/printer.cfg.old
echo "  ✓ Config files removed"

echo ""
echo -e "${GREEN}Cleaning logs...${NC}"
rm -f /tmp/klippy.log /tmp/klippy.log.old
echo "  ✓ Logs cleaned"

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Cleanup Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "CM4 is now clean and ready for fresh installation."
echo ""
echo "Next: Run SETUP_CM4_COMPLETE.sh"
echo ""

