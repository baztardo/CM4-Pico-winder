#!/bin/bash
# Fix log spam and TMC2209 communication issue
# 1. Sync updated winder.py to CM4 (with logging disabled)
# 2. Restart Klipper
# 3. Check TMC2209 communication

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KLIPPER_DIR="$HOME/klipper"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Fix Log Spam & TMC2209${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Step 1: Check if we're on CM4 or local
if [ -f "/home/winder/klipper/klippy/extras/winder.py" ]; then
    echo -e "${BLUE}Step 1: Copying updated winder.py (with logging disabled)...${NC}"
    
    # Backup current file
    if [ -f "/home/winder/klipper/klippy/extras/winder.py" ]; then
        cp /home/winder/klipper/klippy/extras/winder.py /home/winder/klipper/klippy/extras/winder.py.backup.$(date +%s)
        echo "  ✓ Backup created"
    fi
    
    # Copy updated file from klipper-install
    if [ -f "$SCRIPT_DIR/../extras/winder.py" ]; then
        cp "$SCRIPT_DIR/../extras/winder.py" /home/winder/klipper/klippy/extras/winder.py
        echo "  ✓ Updated winder.py copied"
    else
        echo -e "${RED}✗ winder.py not found in klipper-install/extras/${NC}"
        echo "  Run this from the klipper-install directory or sync files first"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠️  Not on CM4 - skipping file copy${NC}"
    echo "  Run this script on the CM4 to fix log spam"
fi

# Step 2: Restart Klipper
echo ""
echo -e "${BLUE}Step 2: Restarting Klipper service...${NC}"
sudo systemctl restart klipper
echo "  ✓ Klipper restarted"
echo "  Waiting 5 seconds for startup..."
sleep 5

# Step 3: Check TMC2209
echo ""
echo -e "${BLUE}Step 3: Checking TMC2209 communication...${NC}"
echo "  The error 'Unable to read tmc uart register IFCNT' indicates:"
echo "    - UART pin (PF13) may be incorrect"
echo "    - TMC2209 may not be responding"
echo "    - Wiring issue"
echo ""
echo "  Checking logs for TMC2209 errors..."
TMC_ERRORS=$(tail -100 /tmp/klippy.log 2>/dev/null | grep -i "tmc.*failed\|tmc.*error\|unable.*read.*tmc" || echo "")
if [ -n "$TMC_ERRORS" ]; then
    echo -e "${YELLOW}⚠️  TMC2209 errors found:${NC}"
    echo "$TMC_ERRORS" | tail -3
    echo ""
    echo "  Troubleshooting steps:"
    echo "    1. Check UART pin (PF13) wiring"
    echo "    2. Verify TMC2209 is powered"
    echo "    3. Check TMC2209 UART address (default should work)"
    echo "    4. Try commenting out [tmc2209 stepper_y] temporarily to test stepper without driver"
else
    echo -e "${GREEN}✓ No recent TMC2209 errors${NC}"
fi

# Step 4: Check log spam
echo ""
echo -e "${BLUE}Step 4: Checking log spam...${NC}"
sleep 2
ADC_SPAM=$(tail -50 /tmp/klippy.log 2>/dev/null | grep -c "Winder: ADC debug\|Winder: Angle sensor - angle" || echo "0")
if [ "$ADC_SPAM" -gt 10 ]; then
    echo -e "${YELLOW}⚠️  Still seeing log spam (${ADC_SPAM} messages in last 50 lines)${NC}"
    echo "  The updated file may not have been loaded yet"
    echo "  Try: sudo systemctl restart klipper"
else
    echo -e "${GREEN}✓ Log spam reduced (${ADC_SPAM} messages in last 50 lines)${NC}"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Fix complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Next steps:"
echo "  1. Check logs: tail -f /tmp/klippy.log | grep -v analog_in_state"
echo "  2. Test TMC2209: python3 $SCRIPT_DIR/diagnose_tmc2209.py"
echo "  3. Test traverse: python3 $SCRIPT_DIR/klipper_interface.py -g 'G28 Y'"

