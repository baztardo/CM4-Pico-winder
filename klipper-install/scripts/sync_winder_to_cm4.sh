#!/bin/bash
# Copy updated winder.py to CM4
# This fixes the log spam issue

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_WINDER="$SCRIPT_DIR/../extras/winder.py"
CM4_HOST="${1:-winder@winder.local}"
CM4_WINDER="~/klipper/klippy/extras/winder.py"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Sync winder.py to CM4${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if local file exists
if [ ! -f "$LOCAL_WINDER" ]; then
    echo -e "${RED}✗ Local winder.py not found: $LOCAL_WINDER${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Local file found: $LOCAL_WINDER${NC}"
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
echo -e "${BLUE}Backing up existing winder.py on CM4...${NC}"
ssh "$CM4_HOST" "
    if [ -f ~/klipper/klippy/extras/winder.py ]; then
        cp ~/klipper/klippy/extras/winder.py ~/klipper/klippy/extras/winder.py.backup.\$(date +%s)
        echo '  ✓ Backup created'
    else
        echo '  ⚠️  No existing file to backup'
    fi
"

# Copy file to CM4
echo ""
echo -e "${BLUE}Copying updated winder.py to CM4...${NC}"
scp "$LOCAL_WINDER" "$CM4_HOST:$CM4_WINDER"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ File copied successfully${NC}"
else
    echo -e "${RED}✗ Failed to copy file${NC}"
    exit 1
fi

# Verify file was copied
echo ""
echo -e "${BLUE}Verifying file on CM4...${NC}"
REMOTE_SIZE=$(ssh "$CM4_HOST" "wc -c < ~/klipper/klippy/extras/winder.py" 2>/dev/null || echo "0")
LOCAL_SIZE=$(wc -c < "$LOCAL_WINDER" 2>/dev/null || echo "0")

if [ "$REMOTE_SIZE" -eq "$LOCAL_SIZE" ] && [ "$REMOTE_SIZE" -gt 0 ]; then
    echo -e "${GREEN}✓ File verified (${REMOTE_SIZE} bytes)${NC}"
else
    echo -e "${YELLOW}⚠️  File size mismatch (local: ${LOCAL_SIZE}, remote: ${REMOTE_SIZE})${NC}"
fi

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
    else
        echo -e "${RED}✗ Klipper is not running - check logs${NC}"
        echo "  Run: ssh $CM4_HOST 'tail -50 /tmp/klippy.log'"
    fi
else
    echo "  Skipped - restart manually with: ssh $CM4_HOST 'sudo systemctl restart klipper'"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Sync complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Next steps:"
echo "  1. Check logs: ssh $CM4_HOST 'tail -f /tmp/klippy.log | grep -v analog_in_state'"
echo "  2. Verify log spam is reduced"
echo "  3. Test hardware: ssh $CM4_HOST 'python3 ~/klipper-install/scripts/klipper_interface.py --info'"

