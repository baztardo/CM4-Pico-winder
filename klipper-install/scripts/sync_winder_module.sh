#!/bin/bash
# Quick sync of winder modules to CM4 (for rapid iteration)
# Usage: ./scripts/sync_winder_module.sh [CM4_HOST] [CM4_USER]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

CM4_HOST="${1:-winder.local}"
CM4_USER="${2:-winder}"
CM4_KLIPPER="~/klipper"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Syncing winder modules to CM4...${NC}"

# Sync winder.py modules
if [ -f "$INSTALL_DIR/extras/winder.py" ]; then
    echo "  → extras/winder.py"
    scp "$INSTALL_DIR/extras/winder.py" "$CM4_USER@$CM4_HOST:$CM4_KLIPPER/klippy/extras/"
fi

if [ -f "$INSTALL_DIR/kinematics/winder.py" ]; then
    echo "  → kinematics/winder.py"
    scp "$INSTALL_DIR/kinematics/winder.py" "$CM4_USER@$CM4_HOST:$CM4_KLIPPER/klippy/kinematics/"
fi

# Sync config if specified
if [ -f "$INSTALL_DIR/config/generic-bigtreetech-manta-m8p-V1_1.cfg" ]; then
    echo "  → printer.cfg"
    scp "$INSTALL_DIR/config/generic-bigtreetech-manta-m8p-V1_1.cfg" "$CM4_USER@$CM4_HOST:~/printer.cfg"
fi

echo -e "${GREEN}✓ Sync complete${NC}"
echo ""
echo "Restart Klipper on CM4:"
echo "  ssh $CM4_USER@$CM4_HOST 'sudo systemctl restart klipper'"

