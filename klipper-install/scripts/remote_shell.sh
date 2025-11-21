#!/bin/bash
# Open interactive SSH shell to CM4 with Klipper environment
# Usage: ./scripts/remote_shell.sh [CM4_HOST] [CM4_USER]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CM4_HOST="${1:-winder.local}"
CM4_USER="${2:-winder}"

BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Opening SSH shell to CM4...${NC}"
echo "  Host: $CM4_HOST"
echo "  User: $CM4_USER"
echo ""
echo "Quick commands:"
echo "  cd ~/klipper              # Go to Klipper directory"
echo "  ./dev_build.sh            # Build firmware"
echo "  ./dev_flash.sh            # Flash firmware"
echo "  sudo systemctl restart klipper  # Restart Klipper"
echo "  tail -f /tmp/klippy.log   # View logs"
echo ""

ssh -t "$CM4_USER@$CM4_HOST" "cd ~/klipper && exec \$SHELL"

