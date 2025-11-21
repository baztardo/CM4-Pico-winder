#!/bin/bash
# Restore broken Makefile from backup
# Usage: ./scripts/fix_broken_makefile.sh [klipper_dir]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

KLIPPER_DIR="${1:-$HOME/klipper}"
MAKEFILE="$KLIPPER_DIR/src/Makefile"
BACKUP="$MAKEFILE.backup"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

if [ ! -f "$BACKUP" ]; then
    echo -e "${RED}Error: Makefile backup not found: $BACKUP${NC}"
    echo "  Cannot restore - need to get original from Klipper repo"
    exit 1
fi

echo "Restoring Makefile from backup..."
cp "$BACKUP" "$MAKEFILE"
echo -e "${GREEN}✓ Makefile restored${NC}"
echo ""
echo "Now run the patch script again (it's been fixed):"
echo "  ./scripts/patch_makefile_conditional.sh ~/klipper"

