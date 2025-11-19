#!/bin/bash
# Add all custom files to a Klipper installation
# Usage: ./add_custom_files_to_klipper.sh [KLIPPER_DIR]
#
# This script copies all custom files (not in master Klipper repo) to your Klipper installation

set -e

KLIPPER_DIR="${1:-~/klipper}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Expand paths
KLIPPER_DIR=$(eval echo "$KLIPPER_DIR")

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Add Custom Files to Klipper${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Klipper directory: $KLIPPER_DIR"
echo "Project root: $PROJECT_ROOT"
echo ""

# Check if Klipper directory exists
if [ ! -d "$KLIPPER_DIR" ]; then
    echo -e "${RED}ERROR: Klipper directory not found: $KLIPPER_DIR${NC}"
    echo "Usage: $0 [KLIPPER_DIR]"
    exit 1
fi

# Function to copy file with directory creation
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

echo -e "${GREEN}Step 1: Copying custom Python modules...${NC}"

# Custom Python modules
copy_file "$PROJECT_ROOT/klippy/extras/winder.py" \
    "$KLIPPER_DIR/klippy/extras/winder.py" \
    "klippy/extras/winder.py"

copy_file "$PROJECT_ROOT/klippy/kinematics/winder.py" \
    "$KLIPPER_DIR/klippy/kinematics/winder.py" \
    "klippy/kinematics/winder.py"

echo ""
echo -e "${GREEN}Step 2: Copying build configuration...${NC}"

# Build config
if [ -f "$PROJECT_ROOT/.config.winder-minimal" ]; then
    copy_file "$PROJECT_ROOT/.config.winder-minimal" \
        "$KLIPPER_DIR/.config.winder-minimal" \
        ".config.winder-minimal"
    echo "  → Use: cp $KLIPPER_DIR/.config.winder-minimal $KLIPPER_DIR/.config"
fi

echo ""
echo -e "${GREEN}Step 3: Copying custom scripts...${NC}"

# Custom scripts (optional - only if they don't exist in Klipper)
CUSTOM_SCRIPTS=(
    "scripts/klipper_interface.py"
    "scripts/simple_stepper_test.py"
    "scripts/check_traverse_status.py"
    "scripts/diagnose_everything.py"
    "scripts/test_winder.py"
    "scripts/fix_mcu_shutdown.py"
    "scripts/check_winder_logs.py"
    "scripts/diagnose_endstop.py"
)

for script in "${CUSTOM_SCRIPTS[@]}"; do
    if [ -f "$PROJECT_ROOT/$script" ]; then
        copy_file "$PROJECT_ROOT/$script" \
            "$KLIPPER_DIR/$script" \
            "$script"
        chmod +x "$KLIPPER_DIR/$script" 2>/dev/null || true
    fi
done

echo ""
echo -e "${GREEN}Step 4: Checking for core modifications...${NC}"

# Check for core modifications
if [ -f "$PROJECT_ROOT/src/stm32/hard_pwm.c" ]; then
    echo -e "${YELLOW}  ⚠ Found: src/stm32/hard_pwm.c${NC}"
    echo "     Check KLIPPER_CORE_MODIFICATIONS.md for modifications"
    echo "     Current status: No modifications (PD4 removed)"
    
    # Ask if user wants to copy modified file
    read -p "  Copy modified hard_pwm.c? [y/N]: " answer
    if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
        copy_file "$PROJECT_ROOT/src/stm32/hard_pwm.c" \
            "$KLIPPER_DIR/src/stm32/hard_pwm.c" \
            "src/stm32/hard_pwm.c (modified)"
    fi
else
    echo -e "${GREEN}  ✓ No core modifications found${NC}"
fi

echo ""
echo -e "${GREEN}Step 5: Copying documentation (optional)...${NC}"

# Copy documentation to a separate folder (optional)
if [ -d "$PROJECT_ROOT/docs" ]; then
    read -p "Copy documentation to $KLIPPER_DIR/docs-custom/? [y/N]: " answer
    if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
        mkdir -p "$KLIPPER_DIR/docs-custom"
        cp -r "$PROJECT_ROOT/docs"/* "$KLIPPER_DIR/docs-custom/" 2>/dev/null || true
        echo -e "${GREEN}  ✓ Documentation copied to docs-custom/${NC}"
    fi
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Custom files added to: $KLIPPER_DIR"
echo ""
echo "Next steps:"
echo "  1. cd $KLIPPER_DIR"
echo "  2. Review copied files"
echo "  3. Apply minimal config (if desired):"
echo "     cp .config.winder-minimal .config"
echo "  4. make menuconfig  # Configure for your MCU"
echo "  5. make             # Build firmware"
echo ""

