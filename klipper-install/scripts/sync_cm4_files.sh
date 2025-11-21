#!/bin/bash
# Synchronize klipper-install folder between local and CM4
# Excludes Klipper source directories (tmp-klipper/, klipper-dev/, etc.)
# Usage: ./scripts/sync_cm4_files.sh [CM4_HOST] [push|pull|compare]

set -e

CM4_HOST="${1:-winder@winder.local}"
LOCAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REMOTE_DIR="~/klipper-install"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

if [ -z "$2" ]; then
    echo -e "${RED}ERROR: Missing command. Usage: $0 [CM4_HOST] [push|pull|compare]${NC}"
    echo ""
    echo "Examples:"
    echo "  $0 winder@winder.local push    # Push local → CM4"
    echo "  $0 winder@winder.local pull    # Pull CM4 → local"
    echo "  $0 winder@winder.local compare # Compare (dry run)"
    exit 1
fi

COMMAND="$2"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Klipper-Install File Sync${NC}"
echo -e "${BLUE}========================================${NC}"
echo "Local: $LOCAL_DIR"
echo "Remote: $CM4_HOST:$REMOTE_DIR"
echo ""
echo -e "${YELLOW}Excluding:${NC}"
echo "  - tmp-klipper/ (Klipper source - clone separately)"
echo "  - klipper-dev/ (Klipper dev clone - clone separately)"
echo "  - docs-klipper/ (Klipper docs - clone separately)"
echo "  - .git/ (git metadata)"
echo "  - .DS_Store (macOS files)"
echo ""

case "$COMMAND" in
    compare)
        echo -e "${GREEN}Comparing local and remote files (dry run)...${NC}"
        echo ""
        echo -e "${BLUE}Local → CM4 (would push):${NC}"
        rsync -avn \
            --exclude='tmp-klipper/' \
            --exclude='klipper-dev/' \
            --exclude='docs-klipper/' \
            --exclude='.git/' \
            --exclude='.DS_Store' \
            --exclude='*.pyc' \
            --exclude='__pycache__/' \
            "$LOCAL_DIR/" "$CM4_HOST:$REMOTE_DIR/" | head -30
        echo ""
        echo -e "${BLUE}CM4 → Local (would pull):${NC}"
        rsync -avn \
            --exclude='tmp-klipper/' \
            --exclude='klipper-dev/' \
            --exclude='docs-klipper/' \
            --exclude='.git/' \
            --exclude='.DS_Store' \
            --exclude='*.pyc' \
            --exclude='__pycache__/' \
            "$CM4_HOST:$REMOTE_DIR/" "$LOCAL_DIR/" | head -30
        ;;
    pull)
        read -p "Pulling files from CM4 to local. This will OVERWRITE local files. Continue? [y/N]: " answer
        if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
            echo -e "${GREEN}Pulling files from CM4 to local...${NC}"
            rsync -av \
                --exclude='tmp-klipper/' \
                --exclude='klipper-dev/' \
                --exclude='docs-klipper/' \
                --exclude='.git/' \
                --exclude='.DS_Store' \
                --exclude='*.pyc' \
                --exclude='__pycache__/' \
                "$CM4_HOST:$REMOTE_DIR/" "$LOCAL_DIR/"
            echo -e "${GREEN}✓ Files pulled from CM4${NC}"
        else
            echo "Cancelled."
        fi
        ;;
    push)
        read -p "Pushing files from local to CM4. This will OVERWRITE CM4 files. Continue? [y/N]: " answer
        if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
            echo -e "${GREEN}Pushing files from local to CM4...${NC}"
            rsync -av \
                --exclude='tmp-klipper/' \
                --exclude='klipper-dev/' \
                --exclude='docs-klipper/' \
                --exclude='.git/' \
                --exclude='.DS_Store' \
                --exclude='*.pyc' \
                --exclude='__pycache__/' \
                "$LOCAL_DIR/" "$CM4_HOST:$REMOTE_DIR/"
            echo -e "${GREEN}✓ Files pushed to CM4${NC}"
        else
            echo "Cancelled."
        fi
        ;;
    *)
        echo -e "${RED}ERROR: Invalid command. Use 'compare', 'pull', or 'push'.${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Sync operation complete.${NC}"
echo -e "${BLUE}========================================${NC}"

