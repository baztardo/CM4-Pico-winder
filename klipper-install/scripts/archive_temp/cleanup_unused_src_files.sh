#!/bin/bash
# Remove unused source files based on .config
# Only keeps files needed for the configured MCU and enabled features
# Usage: ./scripts/cleanup_unused_src_files.sh [klipper_dir] [config_file]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# If run from ~/klipper/scripts/, use parent directory
if [ -f "$SCRIPT_DIR/../Makefile" ] && [ -d "$SCRIPT_DIR/../src" ]; then
    KLIPPER_DIR="${1:-$SCRIPT_DIR/..}"
else
    # Otherwise use provided path or default
    KLIPPER_DIR="${1:-$HOME/klipper}"
fi

CONFIG_FILE="${2:-$KLIPPER_DIR/.config.winder-minimal}"
[ ! -f "$CONFIG_FILE" ] && CONFIG_FILE="$KLIPPER_DIR/.config"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ ! -d "$KLIPPER_DIR/src" ]; then
    echo -e "${RED}Error: src/ directory not found in $KLIPPER_DIR${NC}"
    echo ""
    echo "Usage:"
    echo "  From klipper-install: ./scripts/cleanup_unused_src_files.sh [klipper_dir] [config_file]"
    echo "  From ~/klipper:       ./scripts/cleanup_unused_src_files.sh"
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}Warning: Config file not found: $CONFIG_FILE${NC}"
    echo "  Using default cleanup (STM32G0B1, minimal features)"
fi

echo -e "${BLUE}Cleaning up unused source files...${NC}"
echo "  Klipper dir: $KLIPPER_DIR"
echo "  Config file: $CONFIG_FILE"
echo ""

cd "$KLIPPER_DIR"

# Read config to determine what to keep
MCU_TYPE=""
BOARD_DIR=""
if [ -f "$CONFIG_FILE" ]; then
    MCU_TYPE=$(grep "^CONFIG_MCU=" "$CONFIG_FILE" | cut -d'"' -f2)
    BOARD_DIR=$(grep "^CONFIG_BOARD_DIRECTORY=" "$CONFIG_FILE" | cut -d'"' -f2)
fi

# Default to STM32G0B1 if not found
MCU_TYPE="${MCU_TYPE:-stm32g0b1xx}"
BOARD_DIR="${BOARD_DIR:-stm32}"

echo "Detected MCU: $MCU_TYPE"
echo "Detected board: $BOARD_DIR"
echo ""

# Files/directories to remove (based on disabled features)
REMOVE_LIST=()

# Remove other MCU directories completely (not needed for this MCU/board)
# Note: src/Kconfig should be patched to conditionally source MCU Kconfig files
# If a Kconfig file doesn't exist, menuconfig will simply skip those options
echo "Removing unused MCU directories..."
for mcu_dir in src/avr src/atsam src/atsamd src/lpc176x src/hc32f460 src/rp2040 src/pru src/ar100 src/linux src/simulator; do
    if [ -d "$mcu_dir" ] && [[ "$mcu_dir" != "src/$BOARD_DIR" ]]; then
        echo "  → Removing: $mcu_dir"
        REMOVE_LIST+=("$mcu_dir")
    fi
done

# Remove sensor files if disabled
if [ -f "$CONFIG_FILE" ]; then
    if ! grep -q "^CONFIG_WANT_ADXL345=y" "$CONFIG_FILE"; then
        [ -f "src/sensor_adxl345.c" ] && REMOVE_LIST+=("src/sensor_adxl345.c")
    fi
    if ! grep -q "^CONFIG_WANT_LIS2DW=y" "$CONFIG_FILE"; then
        [ -f "src/sensor_lis2dw.c" ] && REMOVE_LIST+=("src/sensor_lis2dw.c")
    fi
    if ! grep -q "^CONFIG_WANT_MPU9250=y" "$CONFIG_FILE"; then
        [ -f "src/sensor_mpu9250.c" ] && REMOVE_LIST+=("src/sensor_mpu9250.c")
    fi
    if ! grep -q "^CONFIG_WANT_ICM20948=y" "$CONFIG_FILE"; then
        [ -f "src/sensor_icm20948.c" ] && REMOVE_LIST+=("src/sensor_icm20948.c")
    fi
    if ! grep -q "^CONFIG_WANT_HX71X=y" "$CONFIG_FILE"; then
        [ -f "src/sensor_hx71x.c" ] && REMOVE_LIST+=("src/sensor_hx71x.c")
    fi
    if ! grep -q "^CONFIG_WANT_ADS1220=y" "$CONFIG_FILE"; then
        [ -f "src/sensor_ads1220.c" ] && REMOVE_LIST+=("src/sensor_ads1220.c")
    fi
    if ! grep -q "^CONFIG_WANT_LDC1612=y" "$CONFIG_FILE"; then
        [ -f "src/sensor_ldc1612.c" ] && REMOVE_LIST+=("src/sensor_ldc1612.c")
    fi
    
    # Remove display files if disabled
    if ! grep -q "^CONFIG_WANT_ST7920=y" "$CONFIG_FILE"; then
        [ -f "src/lcd_st7920.c" ] && REMOVE_LIST+=("src/lcd_st7920.c")
    fi
    if ! grep -q "^CONFIG_WANT_HD44780=y" "$CONFIG_FILE"; then
        [ -f "src/lcd_hd44780.c" ] && REMOVE_LIST+=("src/lcd_hd44780.c")
    fi
    
    # Remove neopixel if disabled
    if ! grep -q "^CONFIG_WANT_NEOPIXEL=y" "$CONFIG_FILE"; then
        [ -f "src/neopixel.c" ] && REMOVE_LIST+=("src/neopixel.c")
    fi
    
    # Remove thermocouple if disabled
    if ! grep -q "^CONFIG_WANT_THERMOCOUPLE=y" "$CONFIG_FILE"; then
        [ -f "src/thermocouple.c" ] && REMOVE_LIST+=("src/thermocouple.c")
    fi
else
    # Default cleanup (assume minimal config)
    echo "  → No config file, using default cleanup..."
    REMOVE_LIST+=(
        "src/sensor_adxl345.c"
        "src/sensor_lis2dw.c"
        "src/sensor_mpu9250.c"
        "src/sensor_icm20948.c"
        "src/sensor_hx71x.c"
        "src/sensor_ads1220.c"
        "src/sensor_ldc1612.c"
        "src/lcd_st7920.c"
        "src/lcd_hd44780.c"
        "src/neopixel.c"
        "src/thermocouple.c"
    )
fi

# Remove files/directories
REMOVED_COUNT=0
TOTAL_SIZE=0

for item in "${REMOVE_LIST[@]}"; do
    if [ -e "$item" ]; then
        SIZE=$(du -sk "$item" 2>/dev/null | cut -f1)
        TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
        rm -rf "$item"
        REMOVED_COUNT=$((REMOVED_COUNT + 1))
        echo -e "${GREEN}  ✓ Removed: $item${NC}"
    fi
done

if [ $REMOVED_COUNT -eq 0 ]; then
    echo -e "${YELLOW}  No files to remove (already clean or not found)${NC}"
else
    echo ""
    echo -e "${GREEN}✓ Cleanup complete${NC}"
    echo "  Removed: $REMOVED_COUNT items"
    echo "  Space saved: ~${TOTAL_SIZE}KB"
fi

echo ""
echo "Remaining src/ structure:"
find src -maxdepth 2 -type d | sort | head -20
