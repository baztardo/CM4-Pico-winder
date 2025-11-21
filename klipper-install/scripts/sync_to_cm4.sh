#!/bin/bash
# Sync files from klipper-install to CM4 for remote development
# Usage: ./scripts/sync_to_cm4.sh [CM4_HOST] [CM4_USER]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default CM4 connection (can be overridden)
CM4_HOST="${1:-winder.local}"
CM4_USER="${2:-winder}"
CM4_KLIPPER_INSTALL="~/klipper-install"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}Syncing klipper-install to CM4...${NC}"
echo "  Host: $CM4_HOST"
echo "  User: $CM4_USER"
echo ""

# Check SSH connection
if ! ssh -o ConnectTimeout=5 "$CM4_USER@$CM4_HOST" "echo 'Connected'" >/dev/null 2>&1; then
    echo -e "${RED}Error: Cannot connect to $CM4_USER@$CM4_HOST${NC}"
    echo "  Check SSH access and hostname"
    exit 1
fi

# Create remote directory
echo -e "${GREEN}Creating remote directory...${NC}"
ssh "$CM4_USER@$CM4_HOST" "mkdir -p $CM4_KLIPPER_INSTALL"

# Sync essential files (exclude large dev clones)
echo -e "${GREEN}Syncing files...${NC}"
rsync -avz --progress \
    --exclude='klipper-dev/' \
    --exclude='docs-klipper/' \
    --exclude='tmp-klipper/' \
    --exclude='.git/' \
    --exclude='*.pyc' \
    --exclude='__pycache__/' \
    --exclude='.DS_Store' \
    "$INSTALL_DIR/" "$CM4_USER@$CM4_HOST:$CM4_KLIPPER_INSTALL/"

echo ""
echo -e "${GREEN}✓ Sync complete${NC}"
echo ""
echo "Next steps on CM4:"
echo "  ssh $CM4_USER@$CM4_HOST"
echo "  cd $CM4_KLIPPER_INSTALL"
echo "  ./install.sh --dev"

