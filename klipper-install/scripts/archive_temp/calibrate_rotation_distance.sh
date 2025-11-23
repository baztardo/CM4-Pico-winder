#!/bin/bash
# Calibrate rotation_distance by measuring actual distance moved

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KLIPPER_INTERFACE="$SCRIPT_DIR/klipper_interface.py"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Rotation Distance Calibration${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}This script calibrates rotation_distance by measuring actual distance moved.${NC}"
echo -e "${YELLOW}Make a mark on your lead screw or carriage to measure movement.${NC}"
echo ""

read -p "$(echo -e "${BLUE}Press Enter when ready to start calibration...${NC}")"

echo ""
echo -e "${BLUE}Step 1: Home the stepper first...${NC}"
python3 "$KLIPPER_INTERFACE" -g "G28 Y" > /dev/null 2>&1
sleep 1

echo -e "${BLUE}Step 2: Get starting position...${NC}"
START_POS_RAW=$(python3 "$KLIPPER_INTERFACE" --query toolhead 2>&1)
START_POS=$(echo "$START_POS_RAW" | grep -v "^Connected to" | python3 -c 'import sys, json; 
try: 
    data = json.load(sys.stdin)
    toolhead = data.get("toolhead", {})
    pos = toolhead.get("position", [0,0,0,0])
    if isinstance(pos, list) and len(pos) > 1:
        print(f"{pos[1]:.3f}")
    else:
        print("error")
except Exception as e:
    print("error")
' 2>&1)

if [[ "$START_POS" == *"error"* ]]; then
    echo -e "${RED}❌ Could not get starting position${NC}"
    exit 1
fi

echo "  Starting position: $START_POS mm"
echo ""

echo -e "${BLUE}Step 3: Move stepper a known distance...${NC}"
echo -e "${YELLOW}👀 Make a mark on the lead screw/carriage NOW at the starting position${NC}"
read -p "$(echo -e "${BLUE}Press Enter after making your mark...${NC}")"

MOVE_DISTANCE=50
echo -e "${BLUE}  Moving $MOVE_DISTANCE mm...${NC}"
python3 "$KLIPPER_INTERFACE" -g "G1 Y$MOVE_DISTANCE F50" 2>&1 | grep -v "^Connected to" || true
sleep 2

echo ""
echo -e "${BLUE}Step 4: Measure actual distance moved...${NC}"
echo -e "${YELLOW}👀 Measure the ACTUAL distance your mark moved (use calipers/ruler)${NC}"
read -p "$(echo -e "${BLUE}Enter actual distance moved (in mm): ${NC}")" ACTUAL_DISTANCE

if [ -z "$ACTUAL_DISTANCE" ] || ! [[ "$ACTUAL_DISTANCE" =~ ^[0-9]+\.?[0-9]*$ ]]; then
    echo -e "${RED}❌ Invalid distance entered${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}Step 5: Calculate corrected rotation_distance...${NC}"
CURRENT_RD=1.0
CORRECTED_RD=$(echo "scale=4; $CURRENT_RD * $ACTUAL_DISTANCE / $MOVE_DISTANCE" | bc -l 2>/dev/null || echo "1.0")

echo "  Commanded distance: $MOVE_DISTANCE mm"
echo "  Actual distance: $ACTUAL_DISTANCE mm"
echo "  Current rotation_distance: $CURRENT_RD"
echo "  Corrected rotation_distance: $CORRECTED_RD"
echo ""

if (( $(echo "$CORRECTED_RD < 0.1 || $CORRECTED_RD > 10" | bc -l 2>/dev/null || echo "0") )); then
    echo -e "${RED}❌ Calculated rotation_distance seems wrong ($CORRECTED_RD)${NC}"
    echo -e "${YELLOW}   Please double-check your measurement${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Calibration complete!${NC}"
echo ""
echo -e "${BLUE}To apply this value, update your config:${NC}"
echo "  rotation_distance: $CORRECTED_RD"
echo ""
echo -e "${YELLOW}After updating, restart Klipper and test again.${NC}"

echo ""
echo -e "${BLUE}========================================${NC}"

