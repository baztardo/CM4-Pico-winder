#!/bin/bash
# Check if BLDC motor module is loading correctly

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}BLDC Motor Module Diagnostic${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if file exists
echo -e "${BLUE}Step 1: Check if bldc_motor.py exists...${NC}"
if [ -f "~/klipper-install/extras/bldc_motor.py" ]; then
    echo -e "${GREEN}✓ File exists at ~/klipper-install/extras/bldc_motor.py${NC}"
elif [ -f "/home/pi/klipper-install/extras/bldc_motor.py" ]; then
    echo -e "${GREEN}✓ File exists at /home/pi/klipper-install/extras/bldc_motor.py${NC}"
else
    echo -e "${RED}✗ File NOT FOUND!${NC}"
    echo -e "${YELLOW}  Expected location: ~/klipper-install/extras/bldc_motor.py${NC}"
    echo -e "${YELLOW}  Or: /home/pi/klipper-install/extras/bldc_motor.py${NC}"
    echo ""
    echo -e "${YELLOW}  To copy the file, run:${NC}"
    echo -e "${YELLOW}  scp klipper-install/extras/bldc_motor.py pi@your-cm4-ip:~/klipper-install/extras/${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}Step 2: Check Python syntax...${NC}"
python3 -m py_compile ~/klipper-install/extras/bldc_motor.py 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Python syntax is valid${NC}"
else
    echo -e "${RED}✗ Python syntax error!${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}Step 3: Check if module can be imported...${NC}"
cd ~/klipper-install
python3 -c "
import sys
sys.path.insert(0, 'klippy')
try:
    import extras.bldc_motor
    print('✓ Module imports successfully')
    print('  load_config function:', hasattr(extras.bldc_motor, 'load_config'))
    print('  load_config_prefix function:', hasattr(extras.bldc_motor, 'load_config_prefix'))
except Exception as e:
    print('✗ Import error:', e)
    import traceback
    traceback.print_exc()
    sys.exit(1)
" 2>&1

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Module import failed!${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}Step 4: Check Klipper config...${NC}"
if grep -q "^\[bldc_motor\]" ~/printer_data/config/printer.cfg 2>/dev/null || \
   grep -q "^\[bldc_motor\]" ~/klipper-install/config/printer-manta-m4p.cfg 2>/dev/null; then
    echo -e "${GREEN}✓ [bldc_motor] section found in config${NC}"
else
    echo -e "${YELLOW}⚠ [bldc_motor] section NOT found in config${NC}"
    echo -e "${YELLOW}  Add [bldc_motor] section to your printer.cfg${NC}"
fi

echo ""
echo -e "${BLUE}Step 5: Check Klipper logs for errors...${NC}"
echo -e "${YELLOW}  Checking recent Klipper logs...${NC}"
if [ -f ~/printer_data/logs/klippy.log ]; then
    LOG_FILE=~/printer_data/logs/klippy.log
elif [ -f /tmp/klippy.log ]; then
    LOG_FILE=/tmp/klippy.log
else
    echo -e "${YELLOW}  Could not find Klipper log file${NC}"
    LOG_FILE=""
fi

if [ -n "$LOG_FILE" ]; then
    echo -e "${BLUE}  Last 20 lines mentioning 'bldc':${NC}"
    tail -n 100 "$LOG_FILE" | grep -i "bldc" | tail -n 20 || echo "  (no bldc mentions found)"
    echo ""
    echo -e "${BLUE}  Last 10 error lines:${NC}"
    tail -n 100 "$LOG_FILE" | grep -i "error\|exception\|traceback" | tail -n 10 || echo "  (no errors found)"
fi

echo ""
echo -e "${BLUE}Step 6: Test if commands are registered...${NC}"
echo -e "${YELLOW}  Run this command to test:${NC}"
echo -e "${YELLOW}  python3 ~/klipper-install/scripts/klipper_interface.py -g 'QUERY_BLDC'${NC}"

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}If module is not loading:${NC}"
echo -e "${YELLOW}1. Make sure file is copied to CM4${NC}"
echo -e "${YELLOW}2. Restart Klipper: sudo systemctl restart klipper${NC}"
echo -e "${YELLOW}3. Check Klipper logs: tail -f ~/printer_data/logs/klippy.log${NC}"
echo -e "${BLUE}========================================${NC}"

