#!/bin/bash
# Test homing speed from 50mm position

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KLIPPER_INTERFACE="$SCRIPT_DIR/klipper_interface.py"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Homing Speed Test (from 50mm)${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${BLUE}Step 1: Clear homed state and move to Y=50mm...${NC}"
python3 "$KLIPPER_INTERFACE" -g "SET_KINEMATIC_POSITION Y=50 CLEAR_HOMED=y" > /dev/null 2>&1
sleep 0.5
python3 "$KLIPPER_INTERFACE" -g "G1 Y50 F1000" > /dev/null 2>&1
sleep 2

echo -e "${BLUE}Step 2: Verify position...${NC}"
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

echo "  Starting position: $START_POS mm"
if [[ "$START_POS" == *"error"* ]] || (( $(echo "$START_POS < 40" | bc -l 2>/dev/null || echo "1") )); then
    echo -e "${RED}❌ Failed to set position to 50mm!${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}Step 3: Starting homing and measuring time...${NC}"
echo -e "${YELLOW}⏱️  Starting timer...${NC}"
START_TIME=$(date +%s.%N)

python3 "$KLIPPER_INTERFACE" -g "G28 Y" 2>&1 | grep -v "^Connected to" || true

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

echo "  Final position: $END_POS mm"
echo ""

# Calculate
DISTANCE=$(echo "$START_POS - $END_POS" | bc -l 2>/dev/null || echo "0")
DISTANCE=$(echo "if ($DISTANCE < 0) -($DISTANCE) else $DISTANCE" | bc -l 2>/dev/null || echo "$DISTANCE")
TIME=$(echo "$END_TIME - $START_TIME" | bc -l 2>/dev/null || echo "0")

if (( $(echo "$TIME < 0.1" | bc -l 2>/dev/null || echo "1") )); then
    echo -e "${RED}❌ Measurement error - time too short${NC}"
    exit 1
fi

ACTUAL_SPEED=$(echo "scale=2; $DISTANCE / $TIME" | bc -l 2>/dev/null || echo "0")

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Measurement Results:${NC}"
echo "  Distance traveled: $DISTANCE mm"
echo "  Time elapsed: ${TIME}s"
echo "  Actual homing speed: $ACTUAL_SPEED mm/s"
echo "  Expected homing speed: 10 mm/s (from config)"
echo ""

# Check if speed matches
SPEED_RATIO=$(echo "scale=2; $ACTUAL_SPEED / 10" | bc -l 2>/dev/null || echo "0")
SPEED_ERROR=$(echo "scale=1; (($ACTUAL_SPEED - 10) / 10) * 100" | bc -l 2>/dev/null || echo "0")

if (( $(echo "$ACTUAL_SPEED > 40" | bc -l 2>/dev/null || echo "0") )); then
    echo -e "${RED}❌ PROBLEM CONFIRMED: Homing speed is ${SPEED_RATIO}x faster than expected!${NC}"
    echo "  Expected: 10 mm/s"
    echo "  Actual: $ACTUAL_SPEED mm/s"
    echo "  Difference: ${SPEED_ERROR}%"
    echo ""
    echo -e "${YELLOW}Possible causes:${NC}"
    echo "  1. Klipper not restarted after config change"
    echo "  2. homing_speed config not being read (check for syntax errors)"
    echo "  3. max_velocity (120) might be overriding homing_speed"
    echo ""
    echo -e "${BLUE}Try:${NC}"
    echo "  1. Restart Klipper: FIRMWARE_RESTART"
    echo "  2. Verify config has: homing_speed: 10 in [stepper_y] section"
    echo "  3. Check Klipper logs for config errors"
elif (( $(echo "$ACTUAL_SPEED > 15" | bc -l 2>/dev/null || echo "0") )); then
    echo -e "${YELLOW}⚠ Homing speed is faster than expected (${SPEED_ERROR}% difference)${NC}"
else
    echo -e "${GREEN}✓ Homing speed matches expected (within 50%)${NC}"
fi

echo ""
echo -e "${BLUE}========================================${NC}"

