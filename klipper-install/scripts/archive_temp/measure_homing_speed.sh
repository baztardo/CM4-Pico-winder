#!/bin/bash
# Measure actual homing speed and verify rotation_distance

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KLIPPER_INTERFACE="$SCRIPT_DIR/klipper_interface.py"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Homing Speed Measurement${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${YELLOW}This script will measure the actual homing speed.${NC}"
echo -e "${YELLOW}The stepper can start from any position (home or far).${NC}"
echo ""

# Check if debug mode requested
if [ "$1" = "--debug" ]; then
    echo -e "${BLUE}Debug mode: Testing JSON parsing...${NC}"
    RAW_JSON=$(python3 "$KLIPPER_INTERFACE" --query toolhead 2>&1)
    echo "Raw JSON response:"
    echo "$RAW_JSON" | grep -v "^Connected to" | python3 -m json.tool 2>/dev/null || echo "$RAW_JSON"
    echo ""
fi

read -p "$(echo -e "${BLUE}Press Enter when ready to start measurement...${NC}")"

echo ""
echo -e "${BLUE}Step 1: Get starting position...${NC}"
# Try to get position with better error handling
START_POS_RAW=$(python3 "$KLIPPER_INTERFACE" --query toolhead 2>&1)
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Error querying Klipper:${NC}"
    echo "$START_POS_RAW"
    exit 1
fi

START_POS=$(echo "$START_POS_RAW" | grep -v "^Connected to" | python3 -c 'import sys, json; 
try: 
    data = json.load(sys.stdin)
    # Handle different JSON structures
    toolhead = None
    if "toolhead" in data:
        # Direct structure: {"toolhead": {...}}
        toolhead = data["toolhead"]
    elif "result" in data:
        if "status" in data["result"]:
            # Nested structure: {"result": {"status": {"toolhead": {...}}}}
            toolhead = data["result"]["status"].get("toolhead", {})
        else:
            # Alternative: {"result": {"toolhead": {...}}}
            toolhead = data["result"].get("toolhead", {})
    
    if toolhead is None:
        print("error: no toolhead found", file=sys.stderr)
        print("error")
    else:
        pos = toolhead.get("position", [0,0,0,0])
        if isinstance(pos, list) and len(pos) > 1:
            print(f"{pos[1]:.3f}")
        else:
            print("error: invalid position", file=sys.stderr)
            print("error")
except Exception as e:
    print(f"error: {e}", file=sys.stderr)
    print("error")
' 2>&1)

if [[ "$START_POS" == *"error"* ]]; then
    echo -e "${RED}❌ Could not parse starting position${NC}"
    echo -e "${YELLOW}Raw JSON response:${NC}"
    echo "$START_POS_RAW" | head -20
    exit 1
fi

echo "  Starting position: $START_POS mm"

# Check if we need to move to far position first
if (( $(echo "$START_POS < 10" | bc -l 2>/dev/null || echo "1") )); then
    echo -e "${YELLOW}⚠ Stepper is at home position. Moving to far position first...${NC}"
    echo -e "${BLUE}  Step 1: Clearing homed state...${NC}"
    python3 "$KLIPPER_INTERFACE" -g "SET_KINEMATIC_POSITION Y=$START_POS CLEAR_HOMED=y" > /dev/null 2>&1
    sleep 0.5
    
    echo -e "${BLUE}  Step 2: Moving to Y=82...${NC}"
    python3 "$KLIPPER_INTERFACE" -g "G1 Y82 F100" 2>&1 | grep -v "^Connected to" || true
    sleep 3  # Wait for move to complete
    
    # Verify move succeeded
    START_POS_RAW2=$(python3 "$KLIPPER_INTERFACE" --query toolhead 2>&1)
    START_POS=$(echo "$START_POS_RAW2" | grep -v "^Connected to" | python3 -c 'import sys, json; 
try: 
    data = json.load(sys.stdin)
    toolhead = data.get("toolhead", {})
    pos = toolhead.get("position", [0,0,0,0])
    if isinstance(pos, list) and len(pos) > 1:
        print(f"{pos[1]:.3f}")
    else:
        print("error")
except Exception as e:
    print(f"error: {e}", file=sys.stderr)
    print("error")
' 2>&1)
    
    if [[ "$START_POS" == *"error"* ]] || (( $(echo "$START_POS < 10" | bc -l 2>/dev/null || echo "1") )); then
        echo -e "${RED}❌ Failed to move to far position!${NC}"
        echo -e "${YELLOW}  Current position: $START_POS mm${NC}"
        echo -e "${YELLOW}  Please manually move stepper to Y=82 and run script again${NC}"
        exit 1
    fi
    echo "  ✓ Moved to Y=$START_POS mm"
fi
echo ""

echo -e "${BLUE}Step 2: Starting homing and measuring time...${NC}"
echo -e "${YELLOW}⏱️  Starting timer...${NC}"
START_TIME=$(date +%s.%N)

# Start homing in background and capture output
python3 "$KLIPPER_INTERFACE" -g "G28 Y" > /dev/null 2>&1 &
HOMING_PID=$!

# Wait for homing to complete (check position periodically)
while kill -0 $HOMING_PID 2>/dev/null; do
    sleep 0.1
done

END_TIME=$(date +%s.%N)

echo ""
echo -e "${BLUE}Step 3: Get final position...${NC}"
sleep 0.5
END_POS_RAW=$(python3 "$KLIPPER_INTERFACE" --query toolhead 2>&1)
END_POS=$(echo "$END_POS_RAW" | grep -v "^Connected to" | python3 -c 'import sys, json; 
try: 
    data = json.load(sys.stdin)
    # Handle different JSON structures
    toolhead = None
    if "toolhead" in data:
        # Direct structure: {"toolhead": {...}}
        toolhead = data["toolhead"]
    elif "result" in data:
        if "status" in data["result"]:
            # Nested structure: {"result": {"status": {"toolhead": {...}}}}
            toolhead = data["result"]["status"].get("toolhead", {})
        else:
            # Alternative: {"result": {"toolhead": {...}}}
            toolhead = data["result"].get("toolhead", {})
    
    if toolhead is None:
        print("error: no toolhead found", file=sys.stderr)
        print("error")
    else:
        pos = toolhead.get("position", [0,0,0,0])
        if isinstance(pos, list) and len(pos) > 1:
            print(f"{pos[1]:.3f}")
        else:
            print("error: invalid position", file=sys.stderr)
            print("error")
except Exception as e:
    print(f"error: {e}", file=sys.stderr)
    print("error")
' 2>&1)

if [[ "$END_POS" == *"error"* ]]; then
    echo -e "${RED}❌ Could not parse final position${NC}"
    echo -e "${YELLOW}Raw JSON response:${NC}"
    echo "$END_POS_RAW" | head -20
    exit 1
fi

echo "  Final position: $END_POS mm"
echo ""

# Calculate distance and time
DISTANCE=$(echo "$START_POS - $END_POS" | bc -l 2>/dev/null || echo "0")
TIME=$(echo "$END_TIME - $START_TIME" | bc -l 2>/dev/null || echo "0")

if (( $(echo "$TIME < 0.1" | bc -l 2>/dev/null || echo "1") )); then
    echo -e "${RED}❌ Measurement error - time too short${NC}"
    exit 1
fi

# Calculate actual speed
ACTUAL_SPEED=$(echo "scale=2; $DISTANCE / $TIME" | bc -l 2>/dev/null || echo "0")

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Measurement Results:${NC}"
echo "  Distance traveled: $DISTANCE mm"
echo "  Time elapsed: ${TIME}s"
echo "  Actual speed: $ACTUAL_SPEED mm/s"
echo ""
echo -e "${YELLOW}Expected speed: 5 mm/s (from config)${NC}"
echo ""

# Compare with expected
EXPECTED_SPEED=5
SPEED_DIFF=$(echo "scale=2; $ACTUAL_SPEED - $EXPECTED_SPEED" | bc -l 2>/dev/null || echo "0")
SPEED_ERROR=$(echo "scale=1; ($SPEED_DIFF / $EXPECTED_SPEED) * 100" | bc -l 2>/dev/null || echo "0")

if (( $(echo "$SPEED_ERROR > 20 || $SPEED_ERROR < -20" | bc -l 2>/dev/null || echo "0") )); then
    echo -e "${RED}❌ Speed mismatch! Difference: ${SPEED_ERROR}%${NC}"
    echo ""
    echo -e "${YELLOW}Possible causes:${NC}"
    echo "  1. rotation_distance may be incorrect"
    echo "  2. Microsteps change may have affected calculation"
    echo "  3. Speed may be limited by max_velocity or acceleration"
    echo ""
    echo -e "${BLUE}To fix:${NC}"
    echo "  If actual speed is faster: rotation_distance may be too small"
    echo "  If actual speed is slower: rotation_distance may be too large"
    echo ""
    echo "  Calculate correct rotation_distance:"
    echo "    rotation_distance = (actual_distance / expected_distance) * current_rotation_distance"
    echo "    rotation_distance = ($DISTANCE / ($EXPECTED_SPEED * $TIME)) * 1.0"
    CORRECTED_RD=$(echo "scale=3; ($DISTANCE / ($EXPECTED_SPEED * $TIME)) * 1.0" | bc -l 2>/dev/null || echo "1.0")
    echo "    Suggested rotation_distance: $CORRECTED_RD"
else
    echo -e "${GREEN}✓ Speed matches expected (within 20%)${NC}"
fi

echo ""
echo -e "${BLUE}========================================${NC}"

