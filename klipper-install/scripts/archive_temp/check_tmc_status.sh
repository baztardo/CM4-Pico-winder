#!/bin/bash
# Check TMC2209 driver status and stealthchop mode

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KLIPPER_INTERFACE="$SCRIPT_DIR/klipper_interface.py"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}TMC2209 Driver Status Check${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${BLUE}Step 1: Check TMC2209 status...${NC}"
echo -e "${YELLOW}This will show if stealthchop is active and other driver settings${NC}"
echo ""
python3 "$KLIPPER_INTERFACE" -g "QUERY_TMC stepper_y" 2>&1 | grep -v "^$" || echo "Error querying TMC status"
echo ""

echo -e "${BLUE}Step 2: Check stepper configuration...${NC}"
echo -e "${YELLOW}Current settings:${NC}"
echo "  - Microsteps: 16"
echo "  - Stealthchop threshold: 999999 (should always use stealthchop)"
echo "  - Run current: 0.400A"
echo "  - Interpolate: False"
echo ""

echo -e "${BLUE}Step 3: Test at different speeds...${NC}"
echo -e "${YELLOW}Try these commands and note the noise level:${NC}"
echo "  G1 Y10 F10   # Very slow (10mm/s)"
echo "  G1 Y10 F25   # Slow (25mm/s)"
echo "  G1 Y10 F50   # Medium (50mm/s)"
echo "  G1 Y10 F100  # Fast (100mm/s)"
echo ""
echo -e "${YELLOW}Which speed is loudest? This indicates resonant frequency.${NC}"
echo ""

echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Possible Solutions:${NC}"
echo "1. Increase microsteps to 32 or 64 (quieter, smoother)"
echo "2. Verify stealthchop is actually active (check TMC status above)"
echo "3. Adjust PWM settings for better stealthchop operation"
echo "4. Check for mechanical resonance (loose mounting, lead screw issues)"
echo "5. Try different current settings (may need more or less current)"

