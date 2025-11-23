#!/bin/bash
# Verify that F parameter is being interpreted as mm/s

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KLIPPER_INTERFACE="$SCRIPT_DIR/klipper_interface.py"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Feedrate Verification${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${BLUE}Checking speed_factor status...${NC}"
SPEED_FACTOR=$(python3 "$KLIPPER_INTERFACE" --query gcode_move 2>/dev/null | python3 -c 'import sys, json; json_lines = [line for line in sys.stdin.readlines() if not line.startswith("Connected to")]; json_str = "".join(json_lines); data = json.loads(json_str); gcode_move = data.get("gcode_move", data.get("result", {}).get("status", {}).get("gcode_move", {})); sf = gcode_move.get("speed_factor", None); print(f"{sf:.6f}" if sf is not None else "unknown")' 2>/dev/null || echo "unknown")

if [ "$SPEED_FACTOR" != "unknown" ]; then
    echo "  Current speed_factor: $SPEED_FACTOR"
    if (( $(echo "$SPEED_FACTOR > 0.99 && $SPEED_FACTOR < 1.01" | bc -l 2>/dev/null || echo "0") )); then
        echo -e "${GREEN}✓ speed_factor is ~1.0 (F parameter interpreted as mm/s)${NC}"
    else
        echo -e "${YELLOW}⚠ speed_factor is $SPEED_FACTOR (expected ~1.0)${NC}"
        echo -e "${YELLOW}   F parameter may still be interpreted as mm/min${NC}"
    fi
else
    echo -e "${RED}❌ Could not read speed_factor${NC}"
fi

echo ""
echo -e "${BLUE}Current config values:${NC}"
echo "  max_velocity: 120 mm/s"
echo "  max_accel: 500 mm/s²"
echo ""
echo -e "${YELLOW}Note: If speeds aren't exact, it may be due to:${NC}"
echo "  1. Acceleration limiting (short moves may not reach full speed)"
echo "  2. Speed ramping (takes time to accelerate/decelerate)"
echo ""
echo -e "${BLUE}To test actual speed, use:${NC}"
echo "  ./klipper-install/scripts/measure_move_speed.sh"

echo ""
echo -e "${BLUE}========================================${NC}"

