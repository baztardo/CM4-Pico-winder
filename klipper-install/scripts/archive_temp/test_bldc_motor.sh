#!/bin/bash
# Test BLDC motor step by step

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KLIPPER_INTERFACE="$SCRIPT_DIR/klipper_interface.py"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}BLDC Motor Diagnostic Test${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${BLUE}Step 1: Check current status...${NC}"
python3 "$KLIPPER_INTERFACE" -g "QUERY_BLDC" 2>&1 | grep -v "^Connected to"
echo ""

echo -e "${BLUE}Step 2: Enable power manually...${NC}"
python3 "$KLIPPER_INTERFACE" -g "BLDC_SET_POWER ENABLE=1" 2>&1 | grep -v "^Connected to"
sleep 0.5
echo ""

echo -e "${BLUE}Step 3: Release brake manually...${NC}"
python3 "$KLIPPER_INTERFACE" -g "BLDC_SET_BRAKE ENGAGE=0" 2>&1 | grep -v "^Connected to"
sleep 0.5
echo ""

echo -e "${BLUE}Step 4: Set direction to forward...${NC}"
python3 "$KLIPPER_INTERFACE" -g "BLDC_SET_DIR DIRECTION=forward" 2>&1 | grep -v "^Connected to"
sleep 0.5
echo ""

echo -e "${BLUE}Step 5: Start motor at low RPM (100)...${NC}"
python3 "$KLIPPER_INTERFACE" -g "BLDC_START RPM=100 DIRECTION=forward" 2>&1 | grep -v "^Connected to"
sleep 2
echo ""

echo -e "${BLUE}Step 6: Check status again...${NC}"
python3 "$KLIPPER_INTERFACE" -g "QUERY_BLDC" 2>&1 | grep -v "^Connected to"
echo ""

echo -e "${YELLOW}If motor still doesn't move, check:${NC}"
echo "  1. Power supply is connected to motor"
echo "  2. PB3 pin is PWM-capable (check M4P pinout)"
echo "  3. Wiring: PB3→PWM, PB4→DIR, PD5→BRAKE, PB7→POWER"
echo "  4. Motor controller is powered"
echo ""

read -p "$(echo -e "${BLUE}Press Enter to stop motor...${NC}")"
python3 "$KLIPPER_INTERFACE" -g "BLDC_STOP" 2>&1 | grep -v "^Connected to"

echo ""
echo -e "${BLUE}========================================${NC}"

