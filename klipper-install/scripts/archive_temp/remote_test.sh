#!/bin/bash
# Run tests remotely on CM4
# Usage: ./scripts/remote_test.sh [CM4_HOST] [CM4_USER] [test_command]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CM4_HOST="${1:-winder.local}"
CM4_USER="${2:-winder}"
TEST_CMD="${3:-./dev_test.sh}"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Running tests on CM4...${NC}"
echo "  Host: $CM4_HOST"
echo "  Command: $TEST_CMD"
echo ""

ssh "$CM4_USER@$CM4_HOST" "cd ~/klipper && $TEST_CMD"

