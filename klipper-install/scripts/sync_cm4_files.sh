#!/bin/bash
# Sync files between CM4 and local klipper-install
# Usage: ./sync_cm4_files.sh [pull|push|compare]

set -e

CM4_HOST="winder@winder.local"
CM4_DIR="~/klipper-install"
LOCAL_DIR="./klipper-install"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

ACTION="${1:-compare}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}CM4 File Sync Tool${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

case "$ACTION" in
    compare)
        echo -e "${YELLOW}Comparing CM4 vs Local (dry run)...${NC}"
        echo ""
        echo "Files that would be pulled from CM4:"
        rsync -avn "$CM4_HOST:$CM4_DIR/" "$LOCAL_DIR/" 2>/dev/null | grep -E "^>" || echo "  (none)"
        echo ""
        echo "Files that would be pushed to CM4:"
        rsync -avn "$LOCAL_DIR/" "$CM4_HOST:$CM4_DIR/" 2>/dev/null | grep -E "^>" || echo "  (none)"
        echo ""
        echo "Usage:"
        echo "  $0 pull   - Pull files FROM CM4 TO local"
        echo "  $0 push   - Push files FROM local TO CM4"
        ;;
    pull)
        echo -e "${YELLOW}Pulling files FROM CM4 TO local...${NC}"
        read -p "This will overwrite local files. Continue? [y/N]: " answer
        if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
            rsync -av --delete "$CM4_HOST:$CM4_DIR/" "$LOCAL_DIR/"
            echo -e "${GREEN}✓ Files pulled from CM4${NC}"
        else
            echo "Cancelled."
        fi
        ;;
    push)
        echo -e "${YELLOW}Pushing files FROM local TO CM4...${NC}"
        read -p "This will overwrite CM4 files. Continue? [y/N]: " answer
        if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
            rsync -av --delete "$LOCAL_DIR/" "$CM4_HOST:$CM4_DIR/"
            echo -e "${GREEN}✓ Files pushed to CM4${NC}"
        else
            echo "Cancelled."
        fi
        ;;
    *)
        echo "Usage: $0 [compare|pull|push]"
        echo "  compare - Show differences (default)"
        echo "  pull    - Pull FROM CM4 TO local"
        echo "  push    - Push FROM local TO CM4"
        exit 1
        ;;
esac

