#!/bin/bash
# Copy correct printer.cfg to CM4
# This fixes the config format mismatch

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_CFG="$SCRIPT_DIR/../config/printer-manta-m4p.cfg"
CM4_HOST="${1:-winder@winder.local}"
CM4_CFG="~/printer.cfg"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Copy printer.cfg to CM4${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if local file exists
if [ ! -f "$LOCAL_CFG" ]; then
    echo -e "${RED}✗ Local printer.cfg not found: $LOCAL_CFG${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Local file found: $LOCAL_CFG${NC}"
echo ""

# Check if CM4 is reachable
echo -e "${BLUE}Checking CM4 connection...${NC}"
if ! ssh -o ConnectTimeout=5 "$CM4_HOST" "echo 'Connected'" > /dev/null 2>&1; then
    echo -e "${RED}✗ Cannot connect to CM4 at $CM4_HOST${NC}"
    echo "  Check SSH connection and hostname"
    exit 1
fi

echo -e "${GREEN}✓ CM4 is reachable${NC}"
echo ""

# Backup existing file on CM4
echo -e "${BLUE}Backing up existing printer.cfg on CM4...${NC}"
ssh "$CM4_HOST" "
    if [ -f ~/printer.cfg ]; then
        cp ~/printer.cfg ~/printer.cfg.backup.\$(date +%s)
        echo '  ✓ Backup created'
    else
        echo '  ⚠️  No existing file to backup'
    fi
"

# Copy file to CM4
echo ""
echo -e "${BLUE}Copying printer.cfg to CM4...${NC}"
scp "$LOCAL_CFG" "$CM4_HOST:$CM4_CFG"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ File copied successfully${NC}"
else
    echo -e "${RED}✗ Failed to copy file${NC}"
    exit 1
fi

# Verify file was copied
echo ""
echo -e "${BLUE}Verifying file on CM4...${NC}"
REMOTE_SIZE=$(ssh "$CM4_HOST" "wc -c < ~/printer.cfg" 2>/dev/null || echo "0")
LOCAL_SIZE=$(wc -c < "$LOCAL_CFG" 2>/dev/null || echo "0")

if [ "$REMOTE_SIZE" -eq "$LOCAL_SIZE" ] && [ "$REMOTE_SIZE" -gt 0 ]; then
    echo -e "${GREEN}✓ File verified (${REMOTE_SIZE} bytes)${NC}"
else
    echo -e "${YELLOW}⚠️  File size mismatch (local: ${LOCAL_SIZE}, remote: ${REMOTE_SIZE})${NC}"
fi

# Show what changed
echo ""
echo -e "${BLUE}Key differences in new config:${NC}"
echo "  ✓ Uses [winder] section format (not modular)"
echo "  ✓ Motor pins: PC9 (PWM), PC8 (DIR), PD1 (BRAKE)"
echo "  ✓ Spindle Hall: PF6"
echo "  ✓ Angle sensor: PA0"
echo "  ✓ Traverse: PF12 (STEP), PF11 (DIR), PB3 (EN), PF13 (UART)"
echo "  ✓ Endstop: PF3"

# Restart Klipper on CM4
echo ""
echo -e "${BLUE}Restarting Klipper service on CM4...${NC}"
read -p "  Restart Klipper now? [Y/n]: " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    ssh "$CM4_HOST" "sudo systemctl restart klipper"
    echo -e "${GREEN}✓ Klipper restarted${NC}"
    echo "  Waiting 5 seconds for startup..."
    sleep 5
    
    # Check if Klipper started successfully
    echo ""
    echo -e "${BLUE}Checking Klipper status...${NC}"
    if ssh "$CM4_HOST" "sudo systemctl is-active --quiet klipper"; then
        echo -e "${GREEN}✓ Klipper is running${NC}"
        echo ""
        echo "  Check logs for errors:"
        echo "    ssh $CM4_HOST 'tail -50 /tmp/klippy.log | grep -i error'"
    else
        echo -e "${RED}✗ Klipper is not running - check logs${NC}"
        echo "  Run: ssh $CM4_HOST 'tail -50 /tmp/klippy.log'"
    fi
else
    echo "  Skipped - restart manually with: ssh $CM4_HOST 'sudo systemctl restart klipper'"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Copy complete!${NC}"
echo -e "${BLUE}========================================${NC}"

