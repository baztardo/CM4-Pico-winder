#!/bin/bash
# Clone Klipper to temp directory and install custom files
# Usage: ./CLONE_AND_INSTALL.sh [TARGET_DIR]

set -e

TARGET_DIR="${1:-~/klipper-tmp}"
INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KLIPPER_REPO="https://github.com/Klipper3d/klipper.git"

# Expand paths
TARGET_DIR=$(eval echo "$TARGET_DIR")

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Clone Klipper and Install Custom Files${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "This will:"
echo "  1. Clone fresh Klipper to: $TARGET_DIR"
echo "  2. Copy custom files from: $INSTALL_DIR"
echo "  3. Set up Python virtual environment"
echo "  4. Compile chelper files"
echo ""
read -p "Continue? [y/N]: " answer

if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
    echo "Cancelled."
    exit 0
fi

# Step 1: Clone Klipper
echo ""
echo -e "${GREEN}Step 1: Cloning Klipper...${NC}"
if [ -d "$TARGET_DIR" ]; then
    echo -e "${YELLOW}  Directory exists, removing...${NC}"
    rm -rf "$TARGET_DIR"
fi

git clone "$KLIPPER_REPO" "$TARGET_DIR"
echo -e "${GREEN}✓ Klipper cloned to $TARGET_DIR${NC}"

# Step 2: Install custom files
echo ""
echo -e "${GREEN}Step 2: Installing custom files...${NC}"
cd "$INSTALL_DIR"

if [ -f "install.sh" ]; then
    ./install.sh "$TARGET_DIR"
else
    echo -e "${YELLOW}  install.sh not found, copying manually...${NC}"
    
    # Copy required files
    mkdir -p "$TARGET_DIR/klippy/extras"
    mkdir -p "$TARGET_DIR/klippy/kinematics"
    
    if [ -f "extras/winder.py" ]; then
        cp "extras/winder.py" "$TARGET_DIR/klippy/extras/"
        echo "  ✓ Copied extras/winder.py"
    fi
    
    if [ -f "kinematics/winder.py" ]; then
        cp "kinematics/winder.py" "$TARGET_DIR/klippy/kinematics/"
        echo "  ✓ Copied kinematics/winder.py"
    fi
    
    if [ -f ".config.winder-minimal" ]; then
        cp ".config.winder-minimal" "$TARGET_DIR/.config.winder-minimal"
        echo "  ✓ Copied .config.winder-minimal"
    fi
    
    # Copy scripts
    if [ -d "scripts" ]; then
        cp scripts/*.py "$TARGET_DIR/scripts/" 2>/dev/null || true
        echo "  ✓ Copied scripts"
    fi
fi

echo -e "${GREEN}✓ Custom files installed${NC}"

# Step 3: Set up Python environment
echo ""
echo -e "${GREEN}Step 3: Setting up Python virtual environment...${NC}"
cd "$TARGET_DIR"

if [ ! -d "klippy-env" ]; then
    python3 -m venv klippy-env
    echo "  ✓ Virtual environment created"
fi

source klippy-env/bin/activate
pip install --upgrade pip

if [ -f "scripts/klippy-requirements.txt" ]; then
    pip install -r scripts/klippy-requirements.txt
    echo "  ✓ Python packages installed"
else
    pip install cffi pyserial
    echo "  ✓ Basic packages installed"
fi

echo -e "${GREEN}✓ Python environment ready${NC}"

# Step 4: Compile chelper
echo ""
echo -e "${GREEN}Step 4: Compiling chelper files...${NC}"
cd "$TARGET_DIR/klippy/chelper"

if [ -f "setup.py" ]; then
    python3 setup.py build_ext --inplace
    echo "  ✓ chelper compiled"
else
    echo -e "${YELLOW}  ⚠ setup.py not found${NC}"
fi

cd "$TARGET_DIR"
echo -e "${GREEN}✓ chelper complete${NC}"

# Step 5: Configure build
echo ""
echo -e "${GREEN}Step 5: Configuring build...${NC}"
cd "$TARGET_DIR"

if [ -f ".config.winder-minimal" ]; then
    cp .config.winder-minimal .config
    echo "  ✓ Using minimal config"
else
    echo -e "${YELLOW}  ⚠ .config.winder-minimal not found${NC}"
fi

# Summary
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Klipper cloned and configured at: $TARGET_DIR"
echo ""
echo "Next steps:"
echo "  1. Build firmware:"
echo "     cd $TARGET_DIR"
echo "     make menuconfig  # Or use existing .config"
echo "     make"
echo ""
echo "  2. Flash firmware to MCU"
echo ""
echo "  3. Copy config:"
echo "     cp $INSTALL_DIR/config/generic-bigtreetech-manta-m8p-V1_1.cfg ~/printer.cfg"
echo ""
echo "  4. Install service:"
echo "     cd $TARGET_DIR/scripts"
echo "     sudo ./install-octopi.sh"
echo ""

