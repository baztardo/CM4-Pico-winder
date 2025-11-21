#!/bin/bash
# Setup SSH keys for passwordless access to CM4
# Run this on your Mac BEFORE copying files
# Usage: ./SETUP_SSH_KEYS.sh [CM4_HOST] [CM4_USER]

set -e

CM4_HOST="${1:-winder.local}"
CM4_USER="${2:-winder}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Setup SSH Keys for CM4${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "CM4: $CM4_USER@$CM4_HOST"
echo ""

# Check if SSH key exists
SSH_KEY="$HOME/.ssh/id_rsa"
SSH_PUB="$HOME/.ssh/id_rsa.pub"

if [ ! -f "$SSH_KEY" ]; then
    echo -e "${GREEN}Generating SSH key...${NC}"
    ssh-keygen -t rsa -b 4096 -f "$SSH_KEY" -N "" -C "klipper-install"
    echo "  ✓ SSH key generated"
else
    echo -e "${GREEN}SSH key already exists${NC}"
fi

# Copy public key to CM4
echo ""
echo -e "${GREEN}Copying public key to CM4...${NC}"
echo "  You'll be prompted for CM4 password (last time!)"

ssh-copy-id -i "$SSH_PUB" "$CM4_USER@$CM4_HOST" || {
    echo -e "${YELLOW}  ssh-copy-id failed, trying manual method...${NC}"
    
    # Manual method
    cat "$SSH_PUB" | ssh "$CM4_USER@$CM4_HOST" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
}

echo ""
echo -e "${GREEN}Testing passwordless SSH...${NC}"
if ssh -o BatchMode=yes -o ConnectTimeout=5 "$CM4_USER@$CM4_HOST" "echo 'SSH key works!'" 2>/dev/null; then
    echo -e "${GREEN}✓ Passwordless SSH configured!${NC}"
    echo ""
    echo "You can now copy files without password:"
    echo "  scp -r ~/Desktop/klipper-install $CM4_USER@$CM4_HOST:~/"
else
    echo -e "${YELLOW}⚠ SSH key test failed - you may still need password${NC}"
fi

echo ""

