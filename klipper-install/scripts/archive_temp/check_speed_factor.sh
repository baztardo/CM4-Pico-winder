#!/bin/bash
# Check and reset speed factor override

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KLIPPER_INTERFACE="$SCRIPT_DIR/klipper_interface.py"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Speed Factor Check${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${BLUE}Step 1: Setting speed factor for mm/s interpretation...${NC}"
echo -e "${YELLOW}Klipper interprets F as mm/min, so we need M220 S6000 to make F120 = 120 mm/s${NC}"
python3 "$KLIPPER_INTERFACE" -g "M220 S6000" 2>&1 | grep -v "^Connected to" || true
echo -e "${GREEN}✓ Speed factor set (F parameter will now be interpreted as mm/s)${NC}"

echo ""
echo -e "${BLUE}Step 2: Testing move speed...${NC}"
echo -e "${YELLOW}This will move Y from 0 to 50mm at F120 (should be fast)${NC}"
read -p "$(echo -e "${BLUE}Press Enter to test...${NC}")"

START_TIME=$(date +%s.%N)
python3 "$KLIPPER_INTERFACE" -g "G1 Y50 F120" 2>&1 | grep -v "^Connected to" || true
END_TIME=$(date +%s.%N)

TIME=$(echo "$END_TIME - $START_TIME" | bc -l 2>/dev/null || echo "0")
SPEED=$(echo "scale=2; 50 / $TIME" | bc -l 2>/dev/null || echo "0")

echo ""
echo -e "${BLUE}Results:${NC}"
echo "  Distance: 50 mm"
echo "  Time: ${TIME}s"
echo "  Actual speed: $SPEED mm/s"
echo "  Expected speed: 120 mm/s"
echo ""

if (( $(echo "$SPEED < 10" | bc -l 2>/dev/null || echo "1") )); then
    echo -e "${RED}❌ Still too slow! Speed factor reset didn't help.${NC}"
    echo -e "${YELLOW}Possible causes:${NC}"
    echo "  1. Default feedrate is very low"
    echo "  2. F parameter not being parsed correctly"
    echo "  3. Hardware limitation"
else
    echo -e "${GREEN}✓ Speed improved!${NC}"
fi

echo ""
echo -e "${BLUE}========================================${NC}"

