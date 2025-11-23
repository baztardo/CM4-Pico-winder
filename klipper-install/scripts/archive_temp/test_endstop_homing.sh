#!/bin/bash
# Test endstop state and homing behavior

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KLIPPER_INTERFACE="$SCRIPT_DIR/klipper_interface.py"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Endstop and Homing Diagnostic${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${BLUE}Step 1: Check endstop state...${NC}"
echo -e "${YELLOW}👀 Manually press/release the endstop switch and watch the output${NC}"
echo ""
for i in {1..5}; do
    ENDSTOP_STATE=$(python3 "$KLIPPER_INTERFACE" --query endstops 2>/dev/null | python3 -c 'import sys, json; data = json.load(sys.stdin); endstops = data.get("result", {}).get("status", {}).get("endstops", {}); y_state = endstops.get("y", "unknown"); print("TRIGGERED" if y_state == "TRIGGERED" else "open")' 2>/dev/null || echo "unknown")
    echo "  Endstop state: $ENDSTOP_STATE"
    sleep 0.5
done
echo ""

echo -e "${BLUE}Step 2: Move stepper AWAY from endstop first...${NC}"
echo -e "${YELLOW}This ensures endstop is NOT triggered before homing${NC}"
python3 "$KLIPPER_INTERFACE" -g "SET_KINEMATIC_POSITION Y=82 CLEAR_HOMED=y" > /dev/null 2>&1
python3 "$KLIPPER_INTERFACE" -g "G1 Y82 F1000" > /dev/null 2>&1
sleep 2
echo -e "${GREEN}✓ Moved to Y=82mm${NC}"
echo ""

echo -e "${BLUE}Step 3: Check endstop state again (should be OPEN)...${NC}"
ENDSTOP_STATE=$(python3 "$KLIPPER_INTERFACE" --query endstops 2>/dev/null | python3 -c 'import sys, json; data = json.load(sys.stdin); endstops = data.get("result", {}).get("status", {}).get("endstops", {}); y_state = endstops.get("y", "unknown"); print("TRIGGERED" if y_state == "TRIGGERED" else "open")' 2>/dev/null || echo "unknown")
echo "  Endstop state: $ENDSTOP_STATE"
if [ "$ENDSTOP_STATE" = "TRIGGERED" ]; then
    echo -e "${RED}❌ PROBLEM: Endstop is TRIGGERED even though stepper is at far position!${NC}"
    echo -e "${RED}   This means the endstop wiring or configuration is wrong.${NC}"
    exit 1
fi
echo ""

echo -e "${BLUE}Step 4: Now try homing (should move ~82mm toward endstop)...${NC}"
read -p "$(echo -e "${YELLOW}Press Enter to start homing...${NC}")"
python3 "$KLIPPER_INTERFACE" -g "G28 Y"
echo ""

echo -e "${BLUE}Step 5: Check final position...${NC}"
sleep 1
FINAL_POS=$(python3 "$KLIPPER_INTERFACE" --query toolhead 2>/dev/null | python3 -c 'import sys, json; data = json.load(sys.stdin); toolhead = data.get("result", {}).get("status", {}).get("toolhead", {}); pos = toolhead.get("position", [0,0,0,0]); print(f"{pos[1]:.2f}")' 2>/dev/null || echo "Unknown")
echo "  Final Y position: $FINAL_POS mm"
echo ""

if [ "$FINAL_POS" != "Unknown" ]; then
    if (( $(echo "$FINAL_POS < 1.0" | bc -l 2>/dev/null || echo "0") )); then
        echo -e "${GREEN}✓ Homing successful! Stepper is at position 0.${NC}"
    else
        echo -e "${YELLOW}⚠ Stepper is at position $FINAL_POS mm (expected ~0 mm)${NC}"
        echo -e "${YELLOW}   Did the stepper move the full ~82mm distance?${NC}"
    fi
fi

echo ""
echo -e "${BLUE}========================================${NC}"


