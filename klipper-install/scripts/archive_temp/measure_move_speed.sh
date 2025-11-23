#!/bin/bash
# Measure actual speed of a regular move (not homing)

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KLIPPER_INTERFACE="$SCRIPT_DIR/klipper_interface.py"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Regular Move Speed Measurement${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${YELLOW}This measures the actual speed of a regular G1 move (not homing).${NC}"
echo ""

read -p "$(echo -e "${BLUE}Enter move distance (mm) [50]: ${NC}")" MOVE_DIST
MOVE_DIST=${MOVE_DIST:-50}

read -p "$(echo -e "${BLUE}Enter speed (F parameter, mm/s) [120]: ${NC}")" MOVE_SPEED
MOVE_SPEED=${MOVE_SPEED:-120}

echo ""
echo -e "${BLUE}Step 1: Home first...${NC}"
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

echo -e "${BLUE}Step 3: Moving $MOVE_DIST mm at F$MOVE_SPEED...${NC}"
echo -e "${YELLOW}⏱️  Starting timer...${NC}"
START_TIME=$(date +%s.%N)

python3 "$KLIPPER_INTERFACE" -g "G1 Y$MOVE_DIST F$MOVE_SPEED" 2>&1 | grep -v "^Connected to" || true

END_TIME=$(date +%s.%N)

echo ""
echo -e "${BLUE}Step 4: Get final position...${NC}"
sleep 0.5
END_POS_RAW=$(python3 "$KLIPPER_INTERFACE" --query toolhead 2>&1)
END_POS=$(echo "$END_POS_RAW" | grep -v "^Connected to" | python3 -c 'import sys, json; 
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

if [[ "$END_POS" == *"error"* ]]; then
    echo -e "${RED}❌ Could not get final position${NC}"
    exit 1
fi

echo "  Final position: $END_POS mm"
echo ""

# Calculate
DISTANCE=$(echo "$END_POS - $START_POS" | bc -l 2>/dev/null || echo "0")
TIME=$(echo "$END_TIME - $START_TIME" | bc -l 2>/dev/null || echo "0")

if (( $(echo "$TIME < 0.1" | bc -l 2>/dev/null || echo "1") )); then
    echo -e "${RED}❌ Measurement error - time too short${NC}"
    exit 1
fi

ACTUAL_SPEED=$(echo "scale=2; $DISTANCE / $TIME" | bc -l 2>/dev/null || echo "0")

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Measurement Results:${NC}"
echo "  Commanded distance: $MOVE_DIST mm"
echo "  Actual distance: $DISTANCE mm"
echo "  Commanded speed: $MOVE_SPEED mm/s (F$MOVE_SPEED)"
echo "  Time elapsed: ${TIME}s"
echo "  Actual average speed: $ACTUAL_SPEED mm/s"
echo ""

# Check if speed matches
SPEED_DIFF=$(echo "scale=2; $ACTUAL_SPEED - $MOVE_SPEED" | bc -l 2>/dev/null || echo "0")
SPEED_ERROR=$(echo "scale=1; ($SPEED_DIFF / $MOVE_SPEED) * 100" | bc -l 2>/dev/null || echo "0")

# Calculate if acceleration is limiting
# Distance needed to reach full speed: d = v²/(2a)
# With max_accel: 200, to reach 120 mm/s: d = 120²/(2*200) = 36mm
ACCEL_DIST=$(echo "scale=1; ($MOVE_SPEED * $MOVE_SPEED) / (2 * 200)" | bc -l 2>/dev/null || echo "0")

if (( $(echo "$MOVE_DIST < $ACCEL_DIST * 2" | bc -l 2>/dev/null || echo "0") )); then
    echo -e "${YELLOW}⚠ Acceleration limiting detected!${NC}"
    echo "  Move distance ($MOVE_DIST mm) is shorter than needed to reach full speed"
    echo "  Distance needed to reach ${MOVE_SPEED} mm/s: ~${ACCEL_DIST} mm (each direction)"
    echo "  For a ${MOVE_DIST} mm move, max speed is limited by acceleration"
    echo ""
    echo -e "${BLUE}To reach full speed, either:${NC}"
    echo "  1. Increase max_accel (if hardware supports it)"
    echo "  2. Make longer moves (>${ACCEL_DIST} mm each direction)"
fi

if (( $(echo "$SPEED_ERROR < -20" | bc -l 2>/dev/null || echo "0") )); then
    echo -e "${YELLOW}⚠ Speed is slower than commanded (${SPEED_ERROR}% difference)${NC}"
    echo "  This is likely due to acceleration limiting on short moves"
elif (( $(echo "$SPEED_ERROR > 20" | bc -l 2>/dev/null || echo "0") )); then
    echo -e "${RED}❌ Speed is faster than commanded (${SPEED_ERROR}% difference)${NC}"
    echo "  Check max_velocity setting"
else
    echo -e "${GREEN}✓ Speed matches commanded (within 20%)${NC}"
fi

echo ""
echo -e "${BLUE}========================================${NC}"

