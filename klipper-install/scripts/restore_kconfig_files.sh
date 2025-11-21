#!/bin/bash
# Restore Kconfig files for unused MCUs (needed by make menuconfig)
# Usage: ./scripts/restore_kconfig_files.sh [klipper_dir] [source_dir]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

KLIPPER_DIR="${1:-$HOME/klipper}"
SOURCE_DIR="${2:-$INSTALL_DIR/klipper-dev}"
[ ! -d "$SOURCE_DIR" ] && SOURCE_DIR="$INSTALL_DIR/tmp-klipper"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ ! -d "$SOURCE_DIR/src" ]; then
    echo -e "${RED}Error: Source directory not found: $SOURCE_DIR${NC}"
    echo "  Need full Klipper clone to restore Kconfig files"
    exit 1
fi

echo -e "${BLUE}Restoring Kconfig files for unused MCUs...${NC}"
echo "  Klipper dir: $KLIPPER_DIR"
echo "  Source dir: $SOURCE_DIR"
echo ""

cd "$KLIPPER_DIR"

# List of MCU directories that need Kconfig files
MCU_DIRS=("avr" "atsam" "atsamd" "lpc176x" "hc32f460" "rp2040" "pru" "ar100" "linux" "simulator")

RESTORED=0
for mcu in "${MCU_DIRS[@]}"; do
    mcu_dir="src/$mcu"
    kconfig_file="$mcu_dir/Kconfig"
    source_kconfig="$SOURCE_DIR/src/$mcu/Kconfig"
    
    # Check if Kconfig is missing
    if [ ! -f "$kconfig_file" ]; then
        if [ -f "$source_kconfig" ]; then
            # Restore from source
            mkdir -p "$mcu_dir"
            cp "$source_kconfig" "$kconfig_file"
            echo -e "${GREEN}  ✓ Restored: $kconfig_file${NC}"
            RESTORED=$((RESTORED + 1))
        else
            # Create minimal Kconfig
            mkdir -p "$mcu_dir"
            cat > "$kconfig_file" <<EOF
# Kconfig for $mcu - disabled
# This file is kept for make menuconfig compatibility
# Source code has been removed to save space
EOF
            echo -e "${YELLOW}  ✓ Created minimal: $kconfig_file${NC}"
            RESTORED=$((RESTORED + 1))
        fi
    else
        echo "  → Already exists: $kconfig_file"
    fi
done

if [ $RESTORED -gt 0 ]; then
    echo ""
    echo -e "${GREEN}✓ Restored $RESTORED Kconfig files${NC}"
    echo ""
    echo "Now try:"
    echo "  cd ~/klipper"
    echo "  make menuconfig"
else
    echo ""
    echo "All Kconfig files already present"
fi

