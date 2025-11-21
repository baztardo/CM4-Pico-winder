#!/bin/bash
# Patch src/Kconfig to conditionally source MCU/feature Kconfig files
# This allows removing unused MCU directories and optional features while keeping menuconfig working
# Usage: ./scripts/patch_kconfig_conditional.sh [klipper_dir]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

KLIPPER_DIR="${1:-$HOME/klipper}"
KCONFIG_FILE="$KLIPPER_DIR/src/Kconfig"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ ! -f "$KCONFIG_FILE" ]; then
    echo -e "${RED}Error: Kconfig file not found: $KCONFIG_FILE${NC}"
    exit 1
fi

echo -e "${BLUE}Patching src/Kconfig for conditional sourcing...${NC}"
echo "  Klipper dir: $KLIPPER_DIR"
echo ""

cd "$KLIPPER_DIR"

# Check if already patched (look for commented source statements)
if grep -q "# source \"src/.*/Kconfig\"  # Disabled:" "$KCONFIG_FILE" 2>/dev/null; then
    echo -e "${YELLOW}  ⚠ Already patched - will update if needed${NC}"
fi

# Backup original
if [ ! -f "$KCONFIG_FILE.backup" ]; then
    cp "$KCONFIG_FILE" "$KCONFIG_FILE.backup"
    echo "  ✓ Backup created: $KCONFIG_FILE.backup"
fi

# Patch Kconfig: Comment out source statements for files/directories that don't exist
python3 <<PYTHON_PATCH
import sys
import os

kconfig_file = "$KCONFIG_FILE"
if not os.path.exists(kconfig_file):
    print("Error: Kconfig file not found")
    sys.exit(1)

with open(kconfig_file, 'r') as f:
    lines = f.readlines()

# All MCU directories that might be sourced
mcu_dirs = ['avr', 'atsam', 'atsamd', 'lpc176x', 'hc32f460', 'rp2040', 'pru', 'ar100', 'linux', 'simulator', 'stm32']

patched = False
src_dir = os.path.dirname(kconfig_file)
klipper_root = os.path.dirname(src_dir)

for i, line in enumerate(lines):
    line_stripped = line.strip()
    
    # Skip if already commented
    if line_stripped.startswith('#'):
        continue
    
    # Check for source statements
    if line_stripped.startswith('source "') and line_stripped.endswith('"'):
        # Extract the path
        source_path = line_stripped[8:-1]  # Remove 'source "' and '"'
        
        # Skip generic/common files (always needed)
        if 'generic' in source_path.lower() or 'common' in source_path.lower():
            continue
        
        # Resolve path relative to Klipper root
        if source_path.startswith('src/'):
            full_path = os.path.join(klipper_root, source_path)
        else:
            full_path = os.path.join(klipper_root, source_path)
        
        # Check if file/directory exists
        if not os.path.exists(full_path):
            # Comment out if doesn't exist
            lines[i] = f'# {line_stripped}  # Disabled: File/directory not installed\n'
            patched = True
            print(f"  → Commented out: {line_stripped}")

if patched:
    with open(kconfig_file, 'w') as f:
        f.writelines(lines)
    print("  ✓ Patched Kconfig")
else:
    print("  → No patching needed (all source files exist)")
PYTHON_PATCH

echo -e "${GREEN}✓ Kconfig patched${NC}"
echo ""
echo "Now you can safely remove unused MCU directories"
echo "make menuconfig will work - it just won't show options for removed MCUs"

