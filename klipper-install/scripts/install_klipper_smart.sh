#!/bin/bash
# Smart Klipper Installation Script
# Clones to temp folder, copies only needed files, optionally keeps master install
#
# Usage: ./install_klipper_smart.sh [TARGET_DIR] [KEEP_MASTER]

set -e

TARGET_DIR="${1:-~/klipper}"
KEEP_MASTER="${2:-ask}"
INSTALL_DIR="~/install-klipper"
KLIPPER_REPO="https://github.com/Klipper3d/klipper.git"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Expand paths
TARGET_DIR=$(eval echo "$TARGET_DIR")
INSTALL_DIR=$(eval echo "$INSTALL_DIR")

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Smart Klipper Installation${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to ask yes/no questions
ask_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    local answer
    
    if [ "$default" = "y" ]; then
        read -p "$prompt [Y/n]: " answer
        answer="${answer:-y}"
    else
        read -p "$prompt [y/N]: " answer
        answer="${answer:-n}"
    fi
    
    if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
        return 0
    else
        return 1
    fi
}

# Function to detect what features are needed
detect_features() {
    echo -e "${YELLOW}Detecting required features...${NC}"
    
    # Check config file for features
    if [ -f "config/generic-bigtreetech-manta-m8p-V1_1.cfg" ]; then
        CONFIG_FILE="config/generic-bigtreetech-manta-m8p-V1_1.cfg"
    elif [ -f "config/printer.cfg" ]; then
        CONFIG_FILE="config/printer.cfg"
    else
        CONFIG_FILE=""
    fi
    
    NEED_TMC2209=false
    NEED_ADC=false
    NEED_PWM=false
    NEED_PULSE_COUNTER=false
    
    if [ -n "$CONFIG_FILE" ]; then
        if grep -q "tmc2209" "$CONFIG_FILE"; then
            NEED_TMC2209=true
        fi
        if grep -q "angle_sensor_pin\|adc_temperature" "$CONFIG_FILE"; then
            NEED_ADC=true
        fi
        if grep -q "motor_pwm_pin\|pwm" "$CONFIG_FILE"; then
            NEED_PWM=true
        fi
        if grep -q "hall_pin\|pulse_counter" "$CONFIG_FILE"; then
            NEED_PULSE_COUNTER=true
        fi
    fi
    
    echo "  TMC2209: $NEED_TMC2209"
    echo "  ADC: $NEED_ADC"
    echo "  PWM: $NEED_PWM"
    echo "  Pulse Counter: $NEED_PULSE_COUNTER"
    echo ""
}

# Step 1: Clone Klipper to install folder
echo -e "${GREEN}Step 1: Cloning Klipper repository...${NC}"
if [ -d "$INSTALL_DIR" ]; then
    if ask_yes_no "Install folder exists. Remove and re-clone?" "n"; then
        rm -rf "$INSTALL_DIR"
    else
        echo -e "${YELLOW}Using existing install folder${NC}"
    fi
fi

if [ ! -d "$INSTALL_DIR" ]; then
    echo "Cloning to $INSTALL_DIR..."
    git clone --depth 1 "$KLIPPER_REPO" "$INSTALL_DIR"
    echo -e "${GREEN}✓ Cloned successfully${NC}"
else
    echo -e "${YELLOW}Install folder exists, skipping clone${NC}"
fi
echo ""

# Step 2: Detect features
detect_features

# Step 3: Ask what to keep
echo -e "${GREEN}Step 2: Select features to include...${NC}"
KEEP_TMC2209=$NEED_TMC2209
KEEP_ADC=$NEED_ADC
KEEP_PWM=$NEED_PWM
KEEP_PULSE_COUNTER=$NEED_PULSE_COUNTER

if ! ask_yes_no "Use auto-detected features?" "y"; then
    KEEP_TMC2209=false
    KEEP_ADC=false
    KEEP_PWM=false
    KEEP_PULSE_COUNTER=false
    
    if ask_yes_no "Keep TMC2209 support?" "$(echo $NEED_TMC2209 | tr '[:upper:]' '[:lower:]')"; then
        KEEP_TMC2209=true
    fi
    if ask_yes_no "Keep ADC support (for angle sensor)?" "$(echo $NEED_ADC | tr '[:upper:]' '[:lower:]')"; then
        KEEP_ADC=true
    fi
    if ask_yes_no "Keep PWM support (for BLDC motor)?" "$(echo $NEED_PWM | tr '[:upper:]' '[:lower:]')"; then
        KEEP_PWM=true
    fi
    if ask_yes_no "Keep pulse counter (for Hall sensors)?" "$(echo $NEED_PULSE_COUNTER | tr '[:upper:]' '[:lower:]')"; then
        KEEP_PULSE_COUNTER=true
    fi
fi

# Always keep essential features
KEEP_STEPPER=true
KEEP_GPIO=true
KEEP_ENDPSTOP=true

echo ""
echo -e "${GREEN}Selected features:${NC}"
echo "  Stepper: ✓ (required)"
echo "  GPIO: ✓ (required)"
echo "  Endstop: ✓ (required)"
echo "  TMC2209: $([ "$KEEP_TMC2209" = true ] && echo '✓' || echo '✗')"
echo "  ADC: $([ "$KEEP_ADC" = true ] && echo '✓' || echo '✗')"
echo "  PWM: $([ "$KEEP_PWM" = true ] && echo '✓' || echo '✗')"
echo "  Pulse Counter: $([ "$KEEP_PULSE_COUNTER" = true ] && echo '✓' || echo '✗')"
echo ""

# Step 4: Copy files
echo -e "${GREEN}Step 3: Copying files to $TARGET_DIR...${NC}"

# Create target directory
mkdir -p "$TARGET_DIR"

# Copy essential directories
echo "Copying essential directories..."
cp -r "$INSTALL_DIR/klippy" "$TARGET_DIR/"
cp -r "$INSTALL_DIR/lib" "$TARGET_DIR/"
cp -r "$INSTALL_DIR/scripts" "$TARGET_DIR/"
cp -r "$INSTALL_DIR/docs" "$TARGET_DIR/" 2>/dev/null || true

# Copy build system
echo "Copying build system..."
cp "$INSTALL_DIR/Makefile" "$TARGET_DIR/"
cp "$INSTALL_DIR/.gitignore" "$TARGET_DIR/" 2>/dev/null || true
cp "$INSTALL_DIR/COPYING" "$TARGET_DIR/" 2>/dev/null || true
cp "$INSTALL_DIR/README.md" "$TARGET_DIR/" 2>/dev/null || true

# Copy source files selectively
echo "Copying source files..."
mkdir -p "$TARGET_DIR/src"

# Always copy core system files
CORE_FILES=(
    "sched.c" "sched.h"
    "command.c" "command.h"
    "basecmd.c" "basecmd.h"
    "initial_pins.c" "initial_pins.h"
    "stepper.c" "stepper.h"
    "endstop.c" "endstop.h"
    "trsync.c" "trsync.h"
    "gpiocmds.c" "gpiocmds.h"
)

for file in "${CORE_FILES[@]}"; do
    if [ -f "$INSTALL_DIR/src/$file" ]; then
        cp "$INSTALL_DIR/src/$file" "$TARGET_DIR/src/"
    fi
done

# Copy STM32-specific files
echo "Copying STM32 files..."
mkdir -p "$TARGET_DIR/src/stm32"
cp -r "$INSTALL_DIR/src/stm32"/* "$TARGET_DIR/src/stm32/"

# Copy generic ARM files
echo "Copying generic ARM files..."
mkdir -p "$TARGET_DIR/src/generic"
cp -r "$INSTALL_DIR/src/generic"/* "$TARGET_DIR/src/generic/"

# Copy feature-specific files
if [ "$KEEP_TMC2209" = true ]; then
    echo "Copying TMC2209 files..."
    cp "$INSTALL_DIR/src/tmcuart.c" "$TARGET_DIR/src/" 2>/dev/null || true
    cp "$INSTALL_DIR/src/tmcuart.h" "$TARGET_DIR/src/" 2>/dev/null || true
fi

if [ "$KEEP_ADC" = true ]; then
    echo "Copying ADC files..."
    cp "$INSTALL_DIR/src/adccmds.c" "$TARGET_DIR/src/" 2>/dev/null || true
    cp "$INSTALL_DIR/src/adccmds.h" "$TARGET_DIR/src/" 2>/dev/null || true
fi

if [ "$KEEP_PWM" = true ]; then
    echo "Copying PWM files..."
    cp "$INSTALL_DIR/src/pwmcmds.c" "$TARGET_DIR/src/" 2>/dev/null || true
    cp "$INSTALL_DIR/src/pwmcmds.h" "$TARGET_DIR/src/" 2>/dev/null || true
fi

if [ "$KEEP_PULSE_COUNTER" = true ]; then
    echo "Copying pulse counter files..."
    cp "$INSTALL_DIR/src/pulse_counter.c" "$TARGET_DIR/src/" 2>/dev/null || true
    cp "$INSTALL_DIR/src/pulse_counter.h" "$TARGET_DIR/src/" 2>/dev/null || true
fi

# Copy SPI/I2C if needed (for TMC2209)
if [ "$KEEP_TMC2209" = true ]; then
    echo "Copying SPI/I2C files..."
    cp "$INSTALL_DIR/src/spicmds.c" "$TARGET_DIR/src/" 2>/dev/null || true
    cp "$INSTALL_DIR/src/spicmds.h" "$TARGET_DIR/src/" 2>/dev/null || true
    cp "$INSTALL_DIR/src/i2ccmds.c" "$TARGET_DIR/src/" 2>/dev/null || true
    cp "$INSTALL_DIR/src/i2ccmds.h" "$TARGET_DIR/src/" 2>/dev/null || true
    cp "$INSTALL_DIR/src/spi_software.c" "$TARGET_DIR/src/" 2>/dev/null || true
    cp "$INSTALL_DIR/src/i2c_software.c" "$TARGET_DIR/src/" 2>/dev/null || true
fi

# Copy your custom files using the dedicated script
echo "Copying custom winder files..."
if [ -f "$PROJECT_ROOT/scripts/add_custom_files_to_klipper.sh" ]; then
    # Use the dedicated script to copy all custom files
    cd "$PROJECT_ROOT"
    "$PROJECT_ROOT/scripts/add_custom_files_to_klipper.sh" "$TARGET_DIR" 2>/dev/null || {
        # Fallback: manual copy if script fails
        echo "Using fallback copy method..."
        if [ -f "klippy/extras/winder.py" ]; then
            mkdir -p "$TARGET_DIR/klippy/extras"
            cp "klippy/extras/winder.py" "$TARGET_DIR/klippy/extras/"
        fi
        if [ -f "klippy/kinematics/winder.py" ]; then
            mkdir -p "$TARGET_DIR/klippy/kinematics"
            cp "klippy/kinematics/winder.py" "$TARGET_DIR/klippy/kinematics/"
        fi
        if [ -f ".config.winder-minimal" ]; then
            cp ".config.winder-minimal" "$TARGET_DIR/.config.winder-minimal"
        fi
    }
else
    # Fallback: manual copy
    if [ -f "klippy/extras/winder.py" ]; then
        mkdir -p "$TARGET_DIR/klippy/extras"
        cp "klippy/extras/winder.py" "$TARGET_DIR/klippy/extras/"
    fi
    if [ -f "klippy/kinematics/winder.py" ]; then
        mkdir -p "$TARGET_DIR/klippy/kinematics"
        cp "klippy/kinematics/winder.py" "$TARGET_DIR/klippy/kinematics/"
    fi
    if [ -f ".config.winder-minimal" ]; then
        cp ".config.winder-minimal" "$TARGET_DIR/.config.winder-minimal"
    fi
fi

echo -e "${GREEN}✓ Files copied${NC}"
echo ""

# Step 5: Cleanup
if [ "$KEEP_MASTER" = "ask" ]; then
    if ask_yes_no "Keep master install folder for future use?" "y"; then
        KEEP_MASTER="y"
    else
        KEEP_MASTER="n"
    fi
fi

if [ "$KEEP_MASTER" != "y" ]; then
    echo -e "${YELLOW}Removing install folder...${NC}"
    rm -rf "$INSTALL_DIR"
    echo -e "${GREEN}✓ Cleanup complete${NC}"
else
    echo -e "${GREEN}Keeping master install at: $INSTALL_DIR${NC}"
    echo "  You can reuse this for future installations"
fi
echo ""

# Step 6: Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Klipper installed to: $TARGET_DIR"
echo ""
echo "Next steps:"
echo "  1. cd $TARGET_DIR"
echo "  2. make menuconfig  # Configure for your MCU"
echo "  3. make             # Build firmware"
echo ""
if [ "$KEEP_MASTER" = "y" ]; then
    echo "Master install kept at: $INSTALL_DIR"
    echo "  Run this script again to create another installation"
fi

