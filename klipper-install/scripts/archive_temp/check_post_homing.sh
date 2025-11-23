#!/bin/bash
# Check why stepper won't move after homing

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KLIPPER_INTERFACE="$SCRIPT_DIR/klipper_interface.py"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Post-Homing Diagnostic${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${BLUE}Step 1: Check if Y-axis is homed...${NC}"
HOMED_AXES=$(python3 "$KLIPPER_INTERFACE" --query toolhead 2>/dev/null | python3 -c 'import sys, json; try: data = json.load(sys.stdin); toolhead = data.get("result", {}).get("status", {}).get("toolhead", {}); print(toolhead.get("homed_axes", "unknown")) except: print("error")' 2>/dev/null || echo "Unknown")
echo "  Homed axes: $HOMED_AXES"
if [[ "$HOMED_AXES" != *"y"* ]]; then
    echo -e "${RED}❌ Y-axis is NOT homed!${NC}"
    echo -e "${YELLOW}   Run G28 Y first${NC}"
    exit 1
else
    echo -e "${GREEN}✓ Y-axis is homed${NC}"
fi
echo ""

echo -e "${BLUE}Step 2: Check current position...${NC}"
CURRENT_POS=$(python3 "$KLIPPER_INTERFACE" --query toolhead 2>/dev/null | python3 -c 'import sys, json; try: data = json.load(sys.stdin); toolhead = data.get("result", {}).get("status", {}).get("toolhead", {}); pos = toolhead.get("position", [0,0,0,0]); print(f"{pos[1]:.2f}") except: print("error")' 2>/dev/null || echo "Unknown")
echo "  Current Y position: $CURRENT_POS mm"
echo ""

echo -e "${BLUE}Step 3: Check endstop state...${NC}"
ENDSTOP_STATE=$(python3 "$KLIPPER_INTERFACE" --query endstops 2>/dev/null | python3 -c 'import sys, json; try: data = json.load(sys.stdin); endstops = data.get("result", {}).get("status", {}).get("endstops", {}); y_state = endstops.get("y", "unknown"); print("TRIGGERED" if y_state == "TRIGGERED" else "open") except: print("error")' 2>/dev/null || echo "unknown")
echo "  Endstop state: $ENDSTOP_STATE"
if [ "$ENDSTOP_STATE" = "TRIGGERED" ]; then
    echo -e "${YELLOW}⚠ Endstop is still triggered - this might prevent movement${NC}"
    echo -e "${YELLOW}   Check endstop wiring/pin configuration${NC}"
else
    echo -e "${GREEN}✓ Endstop is open (not triggered)${NC}"
fi
echo ""

echo -e "${BLUE}Step 4: Try a small move (Y+5mm)...${NC}"
echo -e "${YELLOW}This will test if Klipper accepts the move command${NC}"
read -p "$(echo -e "${BLUE}Press Enter to try moving Y+5mm...${NC}")"
python3 "$KLIPPER_INTERFACE" -g "G1 Y5 F100" 2>&1
MOVE_RESULT=$?
sleep 1

echo ""
echo -e "${BLUE}Step 5: Check position after move attempt...${NC}"
AFTER_MOVE=$(python3 "$KLIPPER_INTERFACE" --query toolhead 2>/dev/null | python3 -c 'import sys, json; try: data = json.load(sys.stdin); toolhead = data.get("result", {}).get("status", {}).get("toolhead", {}); pos = toolhead.get("position", [0,0,0,0]); print(f"{pos[1]:.2f}") except: print("error")' 2>/dev/null || echo "Unknown")
echo "  Position after move attempt: $AFTER_MOVE mm"

if [ "$AFTER_MOVE" != "$CURRENT_POS" ]; then
    echo -e "${GREEN}✓ Move succeeded! Position changed from $CURRENT_POS to $AFTER_MOVE${NC}"
else
    echo -e "${RED}❌ Move failed! Position did not change${NC}"
    echo ""
    echo -e "${YELLOW}Possible causes:${NC}"
    echo "  1. Endstop still triggered (check Step 3)"
    echo "  2. Position limits not set correctly after homing"
    echo "  3. Stepper enable pin not configured correctly"
    echo "  4. Check Klipper logs for error messages"
fi
echo ""

echo -e "${BLUE}========================================${NC}"

