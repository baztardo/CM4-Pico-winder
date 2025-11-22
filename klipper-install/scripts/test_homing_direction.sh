#!/bin/bash
# Test homing direction and diagnose why stepper doesn't reach switch

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KLIPPER_INTERFACE="$SCRIPT_DIR/klipper_interface.py"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Homing Direction Test${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${BLUE}Step 1: Check current position...${NC}"
CURRENT_POS=$(python3 "$KLIPPER_INTERFACE" --query toolhead 2>/dev/null | grep -o '"position":\[[^]]*\]' | head -1)
echo "  Current position: $CURRENT_POS"
echo ""

echo -e "${BLUE}Step 2: Check endstop state...${NC}"
ENDSTOP_STATE=$(python3 "$KLIPPER_INTERFACE" --query toolhead 2>/dev/null | grep -o '"homed_axes":"[^"]*"' | head -1)
echo "  Endstop state: $ENDSTOP_STATE"
echo ""

echo -e "${BLUE}Step 3: Try homing...${NC}"
echo "  WATCH THE MOTOR - which direction does it move?"
echo "  - Toward the switch (correct)"
echo "  - Away from the switch (wrong - need to reverse direction)"
echo ""
read -p "  Press Enter to start homing..."
python3 "$KLIPPER_INTERFACE" -g "G28 Y"
echo ""

echo -e "${BLUE}Step 4: Check position after homing...${NC}"
sleep 1
NEW_POS=$(python3 "$KLIPPER_INTERFACE" --query toolhead 2>/dev/null | grep -o '"position":\[[^]]*\]' | head -1)
echo "  Position after homing: $NEW_POS"
echo ""

echo -e "${BLUE}Diagnosis:${NC}"
echo "  If motor moved AWAY from switch:"
echo "    - Add '!' to dir_pin: dir_pin: !PB2"
echo "    - OR change homing_positive_dir: True"
echo ""
echo "  If motor moved TOWARD switch but stopped early:"
echo "    - Check endstop wiring (PC1)"
echo "    - Check endstop switch is working (LED should turn on when pressed)"
echo "    - Check endstop inversion (^PC1 means pull-up, NO switch)"

