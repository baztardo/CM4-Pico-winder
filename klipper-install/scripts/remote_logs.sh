#!/bin/bash
# Tail Klipper logs from CM4
# Usage: ./scripts/remote_logs.sh [CM4_HOST] [CM4_USER] [lines]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CM4_HOST="${1:-winder.local}"
CM4_USER="${2:-winder}"
LINES="${3:-100}"

BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Tailing Klipper logs from CM4...${NC}"
echo "  Host: $CM4_HOST"
echo "  Lines: $LINES"
echo ""
echo "Press Ctrl+C to exit"
echo ""

ssh "$CM4_USER@$CM4_HOST" "tail -n $LINES -f /tmp/klippy.log"

