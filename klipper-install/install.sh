#!/bin/bash
# Install custom files from klipper-install to Klipper installation
# Usage: ./install.sh [KLIPPER_DIR]

set -e

KLIPPER_DIR="${1:-~/klipper}"
INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Expand paths
KLIPPER_DIR=$(eval echo "$KLIPPER_DIR")

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Install Custom Files to Klipper${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Klipper directory: $KLIPPER_DIR"
echo "Install package: $INSTALL_DIR"
echo ""

# Check if Klipper directory exists
if [ ! -d "$KLIPPER_DIR" ]; then
    echo -e "${RED}ERROR: Klipper directory not found: $KLIPPER_DIR${NC}"
    echo ""
    echo "Usage: $0 [KLIPPER_DIR]"
    echo "Example: $0 ~/klipper"
    exit 1
fi

# Function to copy file
copy_file() {
    local src="$1"
    local dst="$2"
    local desc="${3:-$src}"
    
    if [ ! -f "$src" ]; then
        echo -e "${YELLOW}  ⚠ Skipping (not found): $desc${NC}"
        return 1
    fi
    
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    echo -e "${GREEN}  ✓ Copied: $desc${NC}"
    return 0
}

# Step 1: Required Python modules
echo -e "${GREEN}Step 1: Copying required Python modules...${NC}"
copy_file "$INSTALL_DIR/extras/winder.py" \
    "$KLIPPER_DIR/klippy/extras/winder.py" \
    "extras/winder.py"

copy_file "$INSTALL_DIR/kinematics/winder.py" \
    "$KLIPPER_DIR/klippy/kinematics/winder.py" \
    "kinematics/winder.py"

echo ""

# Step 2: Build configuration
echo -e "${GREEN}Step 2: Copying build configuration...${NC}"
if [ -f "$INSTALL_DIR/.config.winder-minimal" ]; then
    copy_file "$INSTALL_DIR/.config.winder-minimal" \
        "$KLIPPER_DIR/.config.winder-minimal" \
        ".config.winder-minimal"
    echo "  → To use: cp $KLIPPER_DIR/.config.winder-minimal $KLIPPER_DIR/.config"
else
    echo -e "${YELLOW}  ⚠ .config.winder-minimal not found${NC}"
fi

echo ""

# Step 3: Optional scripts
echo -e "${GREEN}Step 3: Copying optional scripts...${NC}"
if [ -d "$INSTALL_DIR/scripts" ]; then
    for script in "$INSTALL_DIR/scripts"/*.py; do
        if [ -f "$script" ]; then
            script_name=$(basename "$script")
            copy_file "$script" \
                "$KLIPPER_DIR/scripts/$script_name" \
                "scripts/$script_name"
            chmod +x "$KLIPPER_DIR/scripts/$script_name" 2>/dev/null || true
        fi
    done
else
    echo -e "${YELLOW}  ⚠ Scripts directory not found${NC}"
fi

echo ""

# Step 4: Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Files installed to: $KLIPPER_DIR"
echo ""
echo "Next steps:"
echo "  1. cd $KLIPPER_DIR"
echo "  2. Apply build config (if desired):"
echo "     cp .config.winder-minimal .config"
echo "  3. Build firmware:"
echo "     make menuconfig  # Or use existing .config"
echo "     make"
echo "  4. Copy config to CM4:"
echo "     scp config/generic-bigtreetech-manta-m8p-V1_1.cfg winder@winder.local:~/printer.cfg"
echo ""

