#!/bin/bash
# Fix stepper position before homing - tell Klipper where the stepper actually is

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KLIPPER_INTERFACE="$SCRIPT_DIR/klipper_interface.py"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Fix Stepper Position Before Homing${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}This script tells Klipper where the stepper physically is.${NC}"
echo -e "${YELLOW}If you manually moved it to the end (near endstop), set Y=0${NC}"
echo -e "${YELLOW}If you manually moved it to the far position, set Y=82${NC}"
echo ""

read -p "$(echo -e "${BLUE}Where is the stepper physically? (0 = at endstop, 82 = far position) [0]: ${NC}")" PHYSICAL_POS
PHYSICAL_POS=${PHYSICAL_POS:-0}

echo ""
echo -e "${BLUE}Step 1: Clearing homed state...${NC}"
python3 "$KLIPPER_INTERFACE" -g "SET_KINEMATIC_POSITION Y=$PHYSICAL_POS CLEAR_HOMED=y" 2>&1 | grep -v "^$" || true
echo -e "${GREEN}✓ Position set to Y=$PHYSICAL_POS${NC}"

echo ""
echo -e "${BLUE}Step 2: Verifying position...${NC}"
CURRENT_POS=$(python3 "$KLIPPER_INTERFACE" --query toolhead 2>/dev/null | python3 -c 'import sys, json; data = json.load(sys.stdin); toolhead = data.get("result", {}).get("status", {}).get("toolhead", {}); pos = toolhead.get("position", [0,0,0,0]); print(f"{pos[1]:.2f}")' 2>/dev/null || echo "Unknown")
echo "  Current Y position: $CURRENT_POS mm"

echo ""
echo -e "${BLUE}Step 3: Now try homing...${NC}"
read -p "$(echo -e "${YELLOW}Run G28 Y now? [Y/n]: ${NC}")" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    echo -e "${BLUE}Running G28 Y...${NC}"
    python3 "$KLIPPER_INTERFACE" -g "G28 Y"
    echo ""
    echo -e "${BLUE}Step 4: Check final position...${NC}"
    sleep 1
    FINAL_POS=$(python3 "$KLIPPER_INTERFACE" --query toolhead 2>/dev/null | python3 -c 'import sys, json; data = json.load(sys.stdin); toolhead = data.get("result", {}).get("status", {}).get("toolhead", {}); pos = toolhead.get("position", [0,0,0,0]); print(f"{pos[1]:.2f}")' 2>/dev/null || echo "Unknown")
    echo "  Final Y position: $FINAL_POS mm"
    echo ""
    if [ "$FINAL_POS" != "Unknown" ]; then
        if (( $(echo "$FINAL_POS < 1.0" | bc -l) )); then
            echo -e "${GREEN}✓ Homing successful! Stepper is at position 0.${NC}"
        else
            echo -e "${YELLOW}⚠ Stepper is at position $FINAL_POS mm (expected ~0 mm)${NC}"
        fi
    fi
else
    echo -e "${YELLOW}Run 'G28 Y' manually when ready.${NC}"
fi

echo ""
echo -e "${BLUE}========================================${NC}"


