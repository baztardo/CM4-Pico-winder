#!/bin/bash
# Diagnose why stepper doesn't move far enough during homing

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KLIPPER_INTERFACE="$SCRIPT_DIR/klipper_interface.py"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Homing Distance Diagnosis${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${BLUE}Step 1: Check current position before homing...${NC}"
BEFORE_POS=$(python3 "$KLIPPER_INTERFACE" --query toolhead 2>/dev/null | python3 -c 'import sys, json; try: data = json.load(sys.stdin); toolhead = data.get("result", {}).get("status", {}).get("toolhead", {}); pos = toolhead.get("position", [0,0,0,0]); print(f"Y: {pos[1]:.2f}mm"); except: print("Could not parse position")' 2>/dev/null || echo "Unknown")
echo "  Position before: $BEFORE_POS"
echo ""

echo -e "${BLUE}Step 2: Force stepper to far position (82mm)...${NC}"
echo "  This ensures stepper starts from max position before homing"
python3 "$KLIPPER_INTERFACE" -g "G90" > /dev/null 2>&1
python3 "$KLIPPER_INTERFACE" -g "G1 Y82 F1000" > /dev/null 2>&1
sleep 2
echo "  ✓ Moved to Y82"
echo ""

echo -e "${BLUE}Step 3: Check position after move...${NC}"
AFTER_MOVE=$(python3 "$KLIPPER_INTERFACE" --query toolhead 2>/dev/null | python3 -c 'import sys, json; try: data = json.load(sys.stdin); toolhead = data.get("result", {}).get("status", {}).get("toolhead", {}); pos = toolhead.get("position", [0,0,0,0]); print(f"Y: {pos[1]:.2f}mm"); except: print("Could not parse position")' 2>/dev/null || echo "Unknown")
echo "  Position after move: $AFTER_MOVE"
echo ""

echo -e "${BLUE}Step 4: Now try homing (should move ~82mm toward switch)...${NC}"
echo "  👀 WATCH THE MOTOR - measure how far it moves!"
read -p "  Press Enter to start homing..."
python3 "$KLIPPER_INTERFACE" -g "G28 Y"
echo ""

echo -e "${BLUE}Step 5: Check position after homing...${NC}"
sleep 1
AFTER_HOME=$(python3 "$KLIPPER_INTERFACE" --query toolhead 2>/dev/null | python3 -c 'import sys, json; try: data = json.load(sys.stdin); toolhead = data.get("result", {}).get("status", {}).get("toolhead", {}); pos = toolhead.get("position", [0,0,0,0]); print(f"Y: {pos[1]:.2f}mm"); except: print("Could not parse position")' 2>/dev/null || echo "Unknown")
echo "  Position after homing: $AFTER_HOME"
echo ""

echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Diagnosis:${NC}"
echo "  If motor only moved 5-10mm:"
echo "    - Stepper may be starting from wrong position"
echo "    - Check if endstop is triggering early (false trigger)"
echo "    - Check endstop wiring/pin"
echo ""
echo "  If motor moved ~82mm but didn't hit switch:"
echo "    - Switch may be further than 82mm from start"
echo "    - Increase position_max in config"
echo ""
echo "  If motor moved correct distance and hit switch:"
echo "    - Homing is working correctly!"

