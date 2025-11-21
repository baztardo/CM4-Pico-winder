#!/bin/bash
# Setup remote development environment on CM4
# Usage: ./scripts/remote_dev_setup.sh [CM4_HOST] [CM4_USER]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

CM4_HOST="${1:-winder.local}"
CM4_USER="${2:-winder}"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}Setting up remote development on CM4...${NC}"
echo "  Host: $CM4_HOST"
echo "  User: $CM4_USER"
echo ""

# Check connection
if ! ssh -o ConnectTimeout=5 "$CM4_USER@$CM4_HOST" "echo 'Connected'" >/dev/null 2>&1; then
    echo -e "${YELLOW}Error: Cannot connect to $CM4_USER@$CM4_HOST${NC}"
    exit 1
fi

# Sync klipper-install to CM4
echo -e "${GREEN}Step 1: Syncing klipper-install to CM4...${NC}"
"$INSTALL_DIR/scripts/sync_to_cm4.sh" "$CM4_HOST" "$CM4_USER"

# Run install on CM4
echo ""
echo -e "${GREEN}Step 2: Running installation on CM4...${NC}"
echo -e "${YELLOW}This will install Klipper on the CM4${NC}"
read -p "Continue? [Y/n]: " answer
if [ -n "$answer" ] && [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
    echo "Cancelled."
    exit 0
fi

ssh "$CM4_USER@$CM4_HOST" <<'REMOTE_SCRIPT'
cd ~/klipper-install
chmod +x install.sh
./install.sh --dev --non-interactive
REMOTE_SCRIPT

echo ""
echo -e "${GREEN}✓ Remote development environment ready${NC}"
echo ""
echo "Connect to CM4:"
echo "  ssh $CM4_USER@$CM4_HOST"
echo ""
echo "On CM4:"
echo "  cd ~/klipper"
echo "  ./dev_build.sh"
echo "  ./dev_flash.sh"

