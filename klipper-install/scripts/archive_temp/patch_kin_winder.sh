#!/bin/bash
# Patch Klipper to add winder kinematics C helper
#
# This script patches the Klipper chelper to include kin_winder.c
# It modifies klippy/chelper/__init__.py to:
#   1. Add 'kin_winder.c' to SOURCE_FILES
#   2. Add defs_kin_winder function definitions
#   3. Add defs_kin_winder to defs_all list
#
# Usage: ./patch_kin_winder.sh [KLIPPER_DIR]
#   KLIPPER_DIR: Path to Klipper source directory (default: ~/klipper)

set -e

KLIPPER_DIR="${1:-~/klipper}"
KLIPPER_DIR="${KLIPPER_DIR/#\~/$HOME}"  # Expand ~
CHELPER_DIR="${KLIPPER_DIR}/klippy/chelper"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "=========================================="
echo "Patching Klipper for Winder Kinematics C Helper"
echo "=========================================="
echo "Klipper directory: $KLIPPER_DIR"
echo "Chelper directory: $CHELPER_DIR"
echo ""

# Check if Klipper directory exists
if [ ! -d "$KLIPPER_DIR" ]; then
    echo -e "${RED}ERROR: Klipper directory not found: $KLIPPER_DIR${NC}"
    exit 1
fi

# Check if chelper directory exists
if [ ! -d "$CHELPER_DIR" ]; then
    echo -e "${RED}ERROR: Chelper directory not found: $CHELPER_DIR${NC}"
    echo "Is this a valid Klipper installation?"
    exit 1
fi

# Check if __init__.py exists
if [ ! -f "$CHELPER_DIR/__init__.py" ]; then
    echo -e "${RED}ERROR: $CHELPER_DIR/__init__.py not found${NC}"
    exit 1
fi

# Check if kin_winder.c already exists
if [ -f "$CHELPER_DIR/kin_winder.c" ]; then
    echo -e "${YELLOW}WARNING: kin_winder.c already exists in $CHELPER_DIR${NC}"
    read -p "Overwrite? [y/N]: " answer
    if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
        echo "Skipping kin_winder.c copy"
    else
        echo -e "${GREEN}Copying kin_winder.c...${NC}"
        cp "$PROJECT_ROOT/klippy/chelper/kin_winder.c" "$CHELPER_DIR/kin_winder.c"
    fi
else
    echo -e "${GREEN}Copying kin_winder.c...${NC}"
    cp "$PROJECT_ROOT/klippy/chelper/kin_winder.c" "$CHELPER_DIR/kin_winder.c"
fi

# Backup __init__.py
BACKUP_FILE="${CHELPER_DIR}/__init__.py.backup.$(date +%Y%m%d_%H%M%S)"
echo -e "${GREEN}Creating backup: $BACKUP_FILE${NC}"
cp "$CHELPER_DIR/__init__.py" "$BACKUP_FILE"

# Check if already patched
if grep -q "kin_winder.c" "$CHELPER_DIR/__init__.py"; then
    echo -e "${YELLOW}WARNING: __init__.py appears to already be patched${NC}"
    read -p "Re-patch anyway? [y/N]: " answer
    if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
        echo "Skipping __init__.py patching"
        exit 0
    fi
fi

# Patch SOURCE_FILES list
echo -e "${GREEN}Patching SOURCE_FILES list...${NC}"
if ! grep -q "'kin_winder.c'" "$CHELPER_DIR/__init__.py"; then
    # Add kin_winder.c to SOURCE_FILES (after kin_generic.c)
    sed -i.tmp "s/'kin_generic.c'$/'kin_generic.c',\n    'kin_winder.c'/g" "$CHELPER_DIR/__init__.py"
    rm -f "${CHELPER_DIR}/__init__.py.tmp"
    echo "  ✓ Added 'kin_winder.c' to SOURCE_FILES"
else
    echo "  ✓ 'kin_winder.c' already in SOURCE_FILES"
fi

# Patch defs_kin_winder (add after defs_kin_generic_cartesian)
echo -e "${GREEN}Patching function definitions...${NC}"
if ! grep -q "defs_kin_winder" "$CHELPER_DIR/__init__.py"; then
    # Find the line with defs_kin_generic_cartesian closing """
    # Add defs_kin_winder after it
    python3 << PYTHON_SCRIPT
import sys
import re

file_path = sys.argv[1]
with open(file_path, 'r') as f:
    content = f.read()

# Check if defs_kin_winder already exists
if 'defs_kin_winder' in content:
    print("  ✓ defs_kin_winder already exists")
    sys.exit(0)

# Find the end of defs_kin_generic_cartesian and add defs_kin_winder after it
pattern = r'(defs_kin_generic_cartesian = """[^"]*""")'
replacement = r'''\1
defs_kin_winder = """
    struct stepper_kinematics *winder_stepper_alloc(char axis);
"""'''

new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)

if new_content != content:
    with open(file_path, 'w') as f:
        f.write(new_content)
    print("  ✓ Added defs_kin_winder function definitions")
else:
    print("  ⚠ Could not find insertion point for defs_kin_winder")
    sys.exit(1)
PYTHON_SCRIPT
    "$CHELPER_DIR/__init__.py"
else
    echo "  ✓ defs_kin_winder already exists"
fi

# Patch defs_all list
echo -e "${GREEN}Patching defs_all list...${NC}"
if ! grep -q "defs_kin_winder" "$CHELPER_DIR/__init__.py" || ! grep -A 20 "defs_all = \[" "$CHELPER_DIR/__init__.py" | grep -q "defs_kin_winder"; then
    # Add defs_kin_winder to defs_all list (after defs_kin_generic_cartesian)
    sed -i.tmp "s/defs_kin_generic_cartesian,$/defs_kin_generic_cartesian, defs_kin_winder,/g" "$CHELPER_DIR/__init__.py"
    rm -f "${CHELPER_DIR}/__init__.py.tmp"
    echo "  ✓ Added defs_kin_winder to defs_all list"
else
    echo "  ✓ defs_kin_winder already in defs_all list"
fi

echo ""
echo -e "${GREEN}=========================================="
echo "Patch complete!"
echo "==========================================${NC}"
echo ""
echo "Next steps:"
echo "  1. Klipper will automatically compile c_helper.so on next start"
echo "  2. Or manually compile: cd $CHELPER_DIR && python3 -c 'from chelper import get_ffi; get_ffi()'"
echo ""
echo "Backup saved to: $BACKUP_FILE"

