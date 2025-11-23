#!/bin/bash
# Fix MCU Shutdown and Reduce Log Spam
# Addresses both MCU shutdown state and angle sensor log spam

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Fix MCU Shutdown & Log Spam${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Step 1: Check current state
echo -e "${BLUE}Step 1: Checking Klipper status...${NC}"
if sudo systemctl is-active --quiet klipper; then
    echo -e "${GREEN}✓ Klipper service is running${NC}"
else
    echo -e "${RED}✗ Klipper service is not running${NC}"
    echo "  Starting Klipper..."
    sudo systemctl start klipper
    sleep 3
fi

# Step 2: Check for MCU shutdown in logs
echo ""
echo -e "${BLUE}Step 2: Checking for MCU shutdown...${NC}"
SHUTDOWN_COUNT=$(tail -100 /tmp/klippy.log 2>/dev/null | grep -c "shutdown\|MCU.*shutdown" || echo "0")
if [ "$SHUTDOWN_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Found shutdown messages in logs${NC}"
    echo "  Recent shutdown messages:"
    tail -100 /tmp/klippy.log 2>/dev/null | grep -i "shutdown" | tail -3
else
    echo -e "${GREEN}✓ No recent shutdown messages${NC}"
fi

# Step 3: Check for log spam
echo ""
echo -e "${BLUE}Step 3: Checking for log spam...${NC}"
ANALOG_COUNT=$(tail -100 /tmp/klippy.log 2>/dev/null | grep -c "analog_in_state" || echo "0")
if [ "$ANALOG_COUNT" -gt 50 ]; then
    echo -e "${YELLOW}⚠️  Angle sensor log spam detected (${ANALOG_COUNT} messages in last 100 lines)${NC}"
    echo "  This is normal but can be reduced"
else
    echo -e "${GREEN}✓ Log spam is manageable${NC}"
fi

# Step 4: Try firmware restart via API
echo ""
echo -e "${BLUE}Step 4: Attempting firmware restart...${NC}"
if python3 "$(dirname "$0")/klipper_interface.py" -g "FIRMWARE_RESTART" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ FIRMWARE_RESTART command sent${NC}"
    echo "  Waiting 5 seconds for MCU to restart..."
    sleep 5
else
    echo -e "${YELLOW}⚠️  Could not send FIRMWARE_RESTART (MCU may be completely down)${NC}"
    echo "  Will try service restart instead"
fi

# Step 5: Restart Klipper service if needed
echo ""
echo -e "${BLUE}Step 5: Restarting Klipper service...${NC}"
echo "  This will clear the shutdown state"
read -p "  Restart Klipper service? [Y/n]: " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    sudo systemctl restart klipper
    echo -e "${GREEN}✓ Klipper service restarted${NC}"
    echo "  Waiting 5 seconds for startup..."
    sleep 5
else
    echo "  Skipped"
fi

# Step 6: Check if MCU is now ready
echo ""
echo -e "${BLUE}Step 6: Verifying MCU connection...${NC}"
sleep 2
if python3 "$(dirname "$0")/klipper_interface.py" --info > /dev/null 2>&1; then
    INFO=$(python3 "$(dirname "$0")/klipper_interface.py" --info 2>/dev/null)
    STATE=$(echo "$INFO" | grep -o '"state":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
    if [ "$STATE" = "ready" ]; then
        echo -e "${GREEN}✓ MCU is ready!${NC}"
        echo "  State: $STATE"
    else
        echo -e "${YELLOW}⚠️  MCU state: $STATE${NC}"
        echo "  May need more time or manual intervention"
    fi
else
    echo -e "${RED}✗ Still cannot connect to MCU${NC}"
    echo ""
    echo "Troubleshooting steps:"
    echo "  1. Check USB connection: lsusb | grep -i stm"
    echo "  2. Check serial port: ls -l /dev/serial/by-id/"
    echo "  3. Check Klipper logs: tail -50 /tmp/klippy.log"
    echo "  4. Try power cycling the board"
fi

# Step 7: Address log spam (informational)
echo ""
echo -e "${BLUE}Step 7: Log Spam Reduction${NC}"
echo "  The angle sensor sends ADC updates every 10ms"
echo "  This is normal but creates many log entries"
echo ""
echo "  To reduce spam:"
echo "    - Angle sensor logging is already disabled in the module"
echo "    - The 'analog_in_state' messages are from MCU, not Python"
echo "    - These are normal and don't indicate a problem"
echo ""
echo "  If logs are too verbose, you can filter them:"
echo "    tail -f /tmp/klippy.log | grep -v analog_in_state"

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Fix complete!${NC}"
echo -e "${BLUE}========================================${NC}"

