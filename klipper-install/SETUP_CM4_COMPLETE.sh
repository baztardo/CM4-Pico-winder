#!/bin/bash
# Complete CM4 Setup Script - Automated Version
# Handles: Dependencies, Klipper clone, Python venv, chelper compilation, custom files
# Usage: ./SETUP_CM4_COMPLETE.sh [--mcu=STM32G0B1|RP2040|AUTO] [--non-interactive]

set -e

# Setup logging
LOG_FILE="$HOME/klipper-install-setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

KLIPPER_DIR="$HOME/klipper"
INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Parse arguments
MCU_TYPE=""
NON_INTERACTIVE=false
SKIP_UPGRADE=false
DEV_MODE=false

for arg in "$@"; do
    case $arg in
        --mcu=*)
            MCU_TYPE="${arg#*=}"
            # Normalize to uppercase
            MCU_TYPE=$(echo "$MCU_TYPE" | tr '[:lower:]' '[:upper:]')
            ;;
        --dev|--development)
            DEV_MODE=true
            ;;
        --non-interactive)
            NON_INTERACTIVE=true
            ;;
        --skip-upgrade)
            SKIP_UPGRADE=true
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "This script will:"
            echo "  1. Check prerequisites"
            echo "  2. Install system dependencies"
            echo "  3. Clone Klipper (minimal install)"
            echo "  4. Set up Python virtual environment"
            echo "  5. Compile chelper files"
            echo "  6. Install custom winder files"
            echo "  7. Create systemd service"
            echo "  8. Run Python script for MCU/config setup"
            echo ""
            echo "Options:"
            echo "  --dev, --development  - Set up full development environment (default: minimal)"
            echo "  --mcu=AUTO|STM32G0B1|RP2040  - MCU type (default: AUTO - auto-detect)"
            echo "  --skip-upgrade        - Skip system upgrade prompt"
            echo "  --non-interactive     - Skip all prompts"
            echo ""
            echo "Examples:"
            echo "  $0 --dev                    # Dev environment, auto-detect MCU"
            echo "  $0 --mcu=AUTO               # Minimal install, auto-detect MCU"
            echo "  $0 --dev --mcu=STM32G0B1     # Dev environment, STM32G0B1 MCU"
            echo "  $0 --mcu=RP2040 --non-interactive  # Minimal, RP2040, no prompts"
            exit 0
            ;;
    esac
done

# Auto-detect MCU from USB device
detect_mcu_from_usb() {
    echo -e "${BLUE}Auto-detecting MCU from USB devices...${NC}" >&2
    
    # Check for STM32 (Klipper USB ID)
    if lsusb 2>/dev/null | grep -q "1d50:614e"; then
        echo "  ✓ Found STM32 device (Klipper USB ID)" >&2
        # Try to determine STM32 variant from serial port name
        if ls -la /dev/serial/by-id/ 2>/dev/null | grep -qi "stm32g0"; then
            echo "  → Detected: STM32G0B1 (likely Manta MP8 or similar)" >&2
            echo "STM32G0B1"
            return 0
        else
            echo "  → Detected: STM32 (generic, defaulting to G0B1)" >&2
            echo "STM32G0B1"  # Default to G0B1
            return 0
        fi
    fi
    
    # Check for RP2040 (Raspberry Pi USB ID)
    if lsusb 2>/dev/null | grep -q "2e8a:0003\|2e8a:000a\|2e8a:000b"; then
        echo "  ✓ Found RP2040 device (Raspberry Pi USB ID)" >&2
        echo "RP2040"
        return 0
    fi
    
    # Check serial ports for hints
    if ls -la /dev/serial/by-id/ 2>/dev/null | grep -qi "rp2040\|pico"; then
        echo "  → Detected: RP2040 (from serial port name)" >&2
        echo "RP2040"
        return 0
    fi
    
    # Check for any Klipper device
    if ls -la /dev/serial/by-id/ 2>/dev/null | grep -qi "Klipper"; then
        echo "  → Found Klipper device (defaulting to STM32G0B1)" >&2
        echo "STM32G0B1"
        return 0
    fi
    
    echo -e "${YELLOW}  ⚠ Could not auto-detect MCU from USB devices${NC}" >&2
    echo -e "${YELLOW}  → Defaulting to STM32G0B1 (you can change in menuconfig)${NC}" >&2
    echo "STM32G0B1"  # Default fallback
    return 1
}

# Apply MCU preset config
apply_mcu_preset() {
    local mcu="$1"
    local config_file="$KLIPPER_DIR/.config"
    
    echo -e "${GREEN}Applying MCU preset: $mcu${NC}"
    
    if [ "$mcu" = "STM32G0B1" ]; then
        # Copy minimal STM32G0B1 config
        if [ -f "$INSTALL_DIR/.config.winder-minimal" ]; then
            cp "$INSTALL_DIR/.config.winder-minimal" "$config_file"
            echo "  ✓ Applied STM32G0B1 minimal config"
            echo "  → Config file: $INSTALL_DIR/.config.winder-minimal"
            return 0
        else
            echo -e "${YELLOW}  ⚠ Minimal config not found at: $INSTALL_DIR/.config.winder-minimal${NC}"
            echo -e "${YELLOW}  → Checking alternative locations...${NC}"
            # Try alternative locations
            if [ -f "$KLIPPER_DIR/.config.winder-minimal" ]; then
                cp "$KLIPPER_DIR/.config.winder-minimal" "$config_file"
                echo "  ✓ Found and applied config from Klipper directory"
                return 0
            elif [ -f "$HOME/klipper-install/.config.winder-minimal" ]; then
                cp "$HOME/klipper-install/.config.winder-minimal" "$config_file"
                echo "  ✓ Found and applied config from ~/klipper-install"
                return 0
            else
                echo -e "${RED}  ✗ Config file not found in any location${NC}"
                echo "  → Will use menuconfig instead"
                return 1
            fi
        fi
    elif [ "$mcu" = "RP2040" ]; then
        # Create RP2040 minimal config
        cat > "$config_file" <<'EOF'
# RP2040 Minimal Config for Winder
CONFIG_MACH_RPXXXX=y
CONFIG_MACH_RP2040=y
CONFIG_MACH_RP2040_E5=y
CONFIG_BOARD_DIRECTORY="rp2040"
CONFIG_MCU="rp2040"
CONFIG_CLOCK_FREQ=12000000
CONFIG_USB_SERIAL_NUMBER_CHIPID=y
CONFIG_WANT_STEPPER=y
CONFIG_WANT_ADC=y
CONFIG_WANT_SPI=y
CONFIG_WANT_SOFTWARE_SPI=y
CONFIG_WANT_I2C=y
CONFIG_WANT_SOFTWARE_I2C=y
CONFIG_WANT_HARD_PWM=y
CONFIG_WANT_BUTTONS=y
CONFIG_WANT_TMCUART=y
CONFIG_WANT_PULSE_COUNTER=y
# Disabled features (smaller firmware)
# CONFIG_WANT_NEOPIXEL is not set
# CONFIG_WANT_THERMOCOUPLE is not set
# CONFIG_WANT_ST7920 is not set
# CONFIG_WANT_HD44780 is not set
# CONFIG_WANT_ADXL345 is not set
# CONFIG_WANT_LIS2DW is not set
# CONFIG_WANT_MPU9250 is not set
# CONFIG_WANT_ICM20948 is not set
# CONFIG_WANT_HX71X is not set
# CONFIG_WANT_ADS1220 is not set
# CONFIG_WANT_LDC1612 is not set
# CONFIG_WANT_LOAD_CELL_PROBE is not set
EOF
        echo "  ✓ Applied RP2040 minimal config"
    else
        echo -e "${YELLOW}  ⚠ Unknown MCU type: $mcu${NC}"
        return 1
    fi
}

# Main script
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Complete CM4 Setup (Automated)${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Install log: $LOG_FILE"
echo ""
echo "This script will:"
echo "  1. Check prerequisites"
echo "  2. Install system dependencies"
if [ "$DEV_MODE" = true ]; then
    echo "  3. Set up DEVELOPMENT environment (full Klipper + git workflow)"
else
    echo "  3. Clone Klipper (minimal install)"
fi
echo "  4. Set up Python virtual environment"
echo "  5. Compile chelper files"
echo "  6. Install custom winder files"
echo "  7. Create systemd service"
echo "  8. Run Python script for MCU/config setup"
echo ""
echo "Options:"
echo "  --dev, --development  - Set up full development environment (default: minimal)"
echo "  --mcu=AUTO|STM32G0B1|RP2040  - MCU type (default: AUTO - auto-detect)"
echo "  --skip-upgrade        - Skip system upgrade prompt"
echo "  --non-interactive     - Skip all prompts"
echo ""
echo "Examples:"
echo "  $0 --dev                    # Dev environment, auto-detect MCU"
echo "  $0 --mcu=AUTO               # Minimal install, auto-detect MCU"
echo "  $0 --dev --mcu=STM32G0B1     # Dev environment, STM32G0B1 MCU"
echo "  $0 --mcu=RP2040 --non-interactive  # Minimal, RP2040, no prompts"
echo ""

if [ "$NON_INTERACTIVE" = false ]; then
    read -p "Continue? [y/N]: " answer
    if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
        echo "Cancelled."
        exit 0
    fi
fi

echo ""
echo -e "${GREEN}Step 1: Installing dependencies...${NC}"
sudo apt update
if [ "$SKIP_UPGRADE" = false ] && [ "$NON_INTERACTIVE" = false ]; then
    read -p "Upgrade system packages? [y/N]: " upgrade_answer
    if [ "$upgrade_answer" = "y" ] || [ "$upgrade_answer" = "Y" ]; then
        sudo apt upgrade -y
        echo "  ✓ System upgraded"
    fi
elif [ "$SKIP_UPGRADE" = false ] && [ "$NON_INTERACTIVE" = true ]; then
    echo "  → Skipping upgrade (non-interactive mode)"
fi
sudo apt install -y build-essential git python3 python3-pip python3-dev python3-setuptools python3-venv libncurses-dev libusb-1.0-0-dev gcc-arm-none-eabi binutils-arm-none-eabi python3-serial dfu-util screen
echo -e "${GREEN}✓ Dependencies installed${NC}"

echo ""
echo -e "${GREEN}Step 2: Cleaning up old installation...${NC}"
[ -d "$KLIPPER_DIR" ] && rm -rf "$KLIPPER_DIR"
sudo systemctl stop klipper 2>/dev/null || true
sudo systemctl disable klipper 2>/dev/null || true
sudo rm -f /etc/systemd/system/klipper.service /etc/default/klipper
sudo systemctl daemon-reload
rm -f ~/printer.cfg ~/printer.cfg.backup ~/printer.cfg.old /tmp/klippy.log /tmp/klippy.log.old
echo -e "${GREEN}✓ Cleanup complete${NC}"

echo ""
echo -e "${GREEN}Step 3: Setting up Klipper...${NC}"
if [ "$DEV_MODE" = true ]; then
    echo "  → Setting up DEVELOPMENT environment..."
    if [ -f "$INSTALL_DIR/scripts/setup_dev_environment.sh" ]; then
        "$INSTALL_DIR/scripts/setup_dev_environment.sh"
    else
        echo -e "${YELLOW}  ⚠ Dev environment script not found, using full clone...${NC}"
        cd ~ && git clone https://github.com/Klipper3d/klipper.git "$KLIPPER_DIR"
        echo -e "${GREEN}✓ Klipper cloned (dev mode)${NC}"
    fi
else
    echo "  → Setting up MINIMAL installation..."
    cd ~ && git clone https://github.com/Klipper3d/klipper.git "$KLIPPER_DIR"
    echo -e "${GREEN}✓ Klipper cloned${NC}"
fi

echo ""
echo -e "${GREEN}Step 4: Setting up Python virtual environment...${NC}"
cd "$KLIPPER_DIR"
[ ! -d "klippy-env" ] && python3 -m venv klippy-env
source klippy-env/bin/activate
pip install --upgrade pip
[ -f "scripts/klippy-requirements.txt" ] && pip install -r scripts/klippy-requirements.txt || pip install cffi pyserial
echo -e "${GREEN}✓ Python environment ready${NC}"

echo ""
echo -e "${GREEN}Step 5: Compiling chelper files...${NC}"
cd "$KLIPPER_DIR/klippy/chelper"
[ -f "setup.py" ] && python3 setup.py build_ext --inplace && echo "  ✓ chelper compiled" || echo -e "${YELLOW}  ⚠ chelper compilation skipped${NC}"
cd "$KLIPPER_DIR"
echo -e "${GREEN}✓ chelper complete${NC}"

echo ""
echo -e "${GREEN}Step 6: Installing custom winder files...${NC}"
cd "$INSTALL_DIR"
[ -f "install.sh" ] && ./install.sh "$KLIPPER_DIR" || {
    mkdir -p "$KLIPPER_DIR/klippy/extras" "$KLIPPER_DIR/klippy/kinematics"
    [ -f "extras/winder.py" ] && cp extras/winder.py "$KLIPPER_DIR/klippy/extras/" && echo "  ✓ winder.py"
    [ -f "kinematics/winder.py" ] && cp kinematics/winder.py "$KLIPPER_DIR/klippy/kinematics/" && echo "  ✓ kinematics/winder.py"
    [ -f ".config.winder-minimal" ] && cp .config.winder-minimal "$KLIPPER_DIR/.config.winder-minimal" && echo "  ✓ .config preset"
}
echo -e "${GREEN}✓ Custom files installed${NC}"

echo ""
echo -e "${GREEN}Step 7: Configuring build...${NC}"
cd "$KLIPPER_DIR"

# Determine MCU type
if [ -z "$MCU_TYPE" ] || [ "$MCU_TYPE" = "AUTO" ]; then
    # Try interactive board selection first
    if [ "$NON_INTERACTIVE" = false ] && [ -f "$INSTALL_DIR/scripts/select_board.sh" ]; then
        echo -e "${BLUE}Opening board selector...${NC}"
        source "$INSTALL_DIR/scripts/select_board.sh"
        if [ -n "$SELECTED_MCU" ]; then
            MCU_TYPE="$SELECTED_MCU"
            SELECTED_CONFIG_FILE="$SELECTED_CONFIG"
            echo -e "${GREEN}  → Selected from board database: $MCU_TYPE${NC}"
            [ -n "$SELECTED_CONFIG_FILE" ] && echo "  → Config file: $SELECTED_CONFIG_FILE"
        else
            # Fall back to USB detection
            echo -e "${BLUE}Auto-detecting MCU from USB...${NC}"
            MCU_TYPE=$(detect_mcu_from_usb)
            if [ -z "$MCU_TYPE" ]; then
                MCU_TYPE="STM32G0B1"  # Safe default
                echo -e "${YELLOW}  → Using default: STM32G0B1${NC}"
            else
                echo -e "${GREEN}  → Detected: $MCU_TYPE${NC}"
            fi
        fi
    else
        # Non-interactive or no board selector - use USB detection
        echo -e "${BLUE}Auto-detecting MCU from USB...${NC}"
        MCU_TYPE=$(detect_mcu_from_usb)
        if [ -z "$MCU_TYPE" ]; then
            MCU_TYPE="STM32G0B1"  # Safe default
            echo -e "${YELLOW}  → Using default: STM32G0B1${NC}"
        else
            echo -e "${GREEN}  → Detected: $MCU_TYPE${NC}"
        fi
    fi
else
    echo -e "${BLUE}Using specified MCU: $MCU_TYPE${NC}"
fi

# Normalize MCU type (uppercase)
MCU_TYPE=$(echo "$MCU_TYPE" | tr '[:lower:]' '[:upper:]')
echo -e "${BLUE}MCU Type: $MCU_TYPE${NC}"

# Apply preset if available
if apply_mcu_preset "$MCU_TYPE"; then
    echo "  ✓ MCU preset applied: $MCU_TYPE"
    if [ "$NON_INTERACTIVE" = false ]; then
        echo ""
        echo "Opening menuconfig to verify/change MCU settings..."
        echo "  Current preset: $MCU_TYPE"
        echo "  Minimal features are disabled (LCD, neopixel, etc.)"
        echo ""
        read -p "Press Enter to open menuconfig (or Ctrl+C to skip)..."
        make menuconfig
    else
        echo "  → Skipping menuconfig (non-interactive mode)"
        echo "  → To change settings later: cd ~/klipper && make menuconfig"
    fi
else
    echo -e "${YELLOW}  ⚠ Preset not available, opening menuconfig...${NC}"
    if [ "$NON_INTERACTIVE" = false ]; then
        make menuconfig
    else
        echo -e "${RED}  ✗ Cannot proceed without menuconfig in non-interactive mode${NC}"
        exit 1
    fi
fi
echo "  ✓ Configuration saved"

echo ""
echo -e "${GREEN}Step 8: Creating systemd service...${NC}"
KLIPPER_USER="$USER"
KLIPPER_LOG="/tmp/klippy.log"
SYSTEMD_FILE="/etc/systemd/system/klipper.service"

# Create systemd service file
sudo /bin/sh -c "cat > $SYSTEMD_FILE" <<EOF
[Unit]
Description=Klipper 3D Printer Firmware
After=network.target

[Service]
Type=simple
User=$KLIPPER_USER
RemainAfterExit=yes
WorkingDirectory=$KLIPPER_DIR
Environment="PATH=$KLIPPER_DIR/klippy-env/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=$KLIPPER_DIR/klippy-env/bin/python3 $KLIPPER_DIR/klippy/klippy.py $HOME/printer.cfg -l $KLIPPER_LOG --api-server /tmp/klippy_uds
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create /etc/default/klipper (for compatibility)
DEFAULTS_FILE="/etc/default/klipper"
[ ! -f "$DEFAULTS_FILE" ] && sudo /bin/sh -c "cat > $DEFAULTS_FILE" <<EOF
# Configuration for Klipper service
KLIPPY_USER=$KLIPPER_USER
KLIPPY_EXEC=$KLIPPER_DIR/klippy-env/bin/python3
KLIPPY_ARGS="$KLIPPER_DIR/klippy/klippy.py $HOME/printer.cfg -l $KLIPPER_LOG --api-server /tmp/klippy_uds"
EOF

sudo systemctl daemon-reload
sudo systemctl enable klipper
echo "  ✓ Service created and enabled"

# Auto-detect and update serial port in config
update_serial_port() {
    local config_file="$1"
    
    if [ ! -f "$config_file" ]; then
        echo -e "${YELLOW}  ⚠ Config file not found: $config_file${NC}"
        return 1
    fi
    
    echo ""
    echo -e "${GREEN}Detecting serial port...${NC}"
    
    # Find Klipper device in /dev/serial/by-id/
    local serial_port=""
    if [ -d "/dev/serial/by-id" ]; then
        # Look for Klipper device first
        serial_port=$(ls -1 /dev/serial/by-id/ 2>/dev/null | grep -i "Klipper\|stm32\|rp2040\|pico" | head -1)
        
        if [ -n "$serial_port" ]; then
            serial_port="/dev/serial/by-id/$serial_port"
            echo "  ✓ Found device: $serial_port"
        else
            # Fallback to any serial device
            serial_port=$(ls -1 /dev/serial/by-id/ 2>/dev/null | head -1)
            if [ -n "$serial_port" ]; then
                serial_port="/dev/serial/by-id/$serial_port"
                echo -e "${YELLOW}  ⚠ Using first available device: $serial_port${NC}"
            fi
        fi
    fi
    
    if [ -z "$serial_port" ]; then
        echo -e "${YELLOW}  ⚠ No serial device found${NC}"
        echo "  → You'll need to update the config manually after connecting the MCU"
        return 1
    fi
    
    # Update config file
    if grep -q "^\[mcu" "$config_file" || grep -q "^\[mcu " "$config_file"; then
        # Check if serial is already set
        if grep -q "^serial:" "$config_file"; then
            # Replace existing serial line (handles "serial: /dev/..." format)
            # Escape the serial_port for sed
            local escaped_port=$(echo "$serial_port" | sed 's/[[\.*^$()+?{|]/\\&/g')
            if sed -i.bak "s|^serial:.*|serial: $escaped_port|" "$config_file" 2>/dev/null; then
                echo "  ✓ Updated serial port in config"
                echo "     Old: $(grep '^serial:' "${config_file}.bak" 2>/dev/null | head -1)"
                echo "     New: serial: $serial_port"
                rm -f "${config_file}.bak"
                return 0
            else
                echo -e "${YELLOW}  ⚠ Could not update serial port (permission issue?)${NC}"
                echo "  → Manual update needed: serial: $serial_port"
                return 1
            fi
        else
            # Add serial line after [mcu] section
            local escaped_port=$(echo "$serial_port" | sed 's/[[\.*^$()+?{|]/\\&/g')
            if sed -i.bak "/^\[mcu/a serial: $escaped_port" "$config_file" 2>/dev/null; then
                echo "  ✓ Added serial port to config: $serial_port"
                rm -f "${config_file}.bak"
                return 0
            else
                echo -e "${YELLOW}  ⚠ Could not add serial port (permission issue?)${NC}"
                echo "  → Manual update needed: Add 'serial: $serial_port' after [mcu] section"
                return 1
            fi
        fi
    else
        echo -e "${YELLOW}  ⚠ No [mcu] section found in config${NC}"
        echo "  → Add [mcu] section with: serial: $serial_port"
        return 1
    fi
}

# Copy and update config file (do this right after service creation)
echo ""
echo -e "${GREEN}Step 8.5: Setting up printer config...${NC}"

if [ -n "$SELECTED_CONFIG_FILE" ] && [ -f "$INSTALL_DIR/config/$SELECTED_CONFIG_FILE" ]; then
    echo "  → Using selected config: $SELECTED_CONFIG_FILE"
    cp "$INSTALL_DIR/config/$SELECTED_CONFIG_FILE" "$HOME/printer.cfg"
    echo "  ✓ Copied: $SELECTED_CONFIG_FILE → ~/printer.cfg"
    update_serial_port "$HOME/printer.cfg"
elif [ -f "$INSTALL_DIR/config/generic-bigtreetech-manta-m8p-V1_1.cfg" ]; then
    echo "  → Using default config: generic-bigtreetech-manta-m8p-V1_1.cfg"
    cp "$INSTALL_DIR/config/generic-bigtreetech-manta-m8p-V1_1.cfg" "$HOME/printer.cfg"
    echo "  ✓ Copied default config → ~/printer.cfg"
    update_serial_port "$HOME/printer.cfg"
else
    echo -e "${YELLOW}  ⚠ No config file found${NC}"
    echo "  → You'll need to copy a config file manually"
    echo "  → Available configs in: $INSTALL_DIR/config/"
fi

if [ -f "$HOME/printer.cfg" ]; then
    echo ""
    echo -e "${GREEN}  ✓ Config file ready: ~/printer.cfg${NC}"
    if grep -q "^serial:" "$HOME/printer.cfg" 2>/dev/null; then
        echo "     Serial port: $(grep '^serial:' "$HOME/printer.cfg" | cut -d' ' -f2)"
    fi
fi

# Build firmware
build_firmware() {
    echo ""
    echo -e "${GREEN}Step 9: Building firmware...${NC}"
    cd "$KLIPPER_DIR"
    
    if [ ! -f ".config" ]; then
        echo -e "${RED}  ✗ No .config file found!${NC}"
        echo "  → Run: cd ~/klipper && make menuconfig"
        return 1
    fi
    
    echo "  → Building firmware for $MCU_TYPE..."
    if make -j$(nproc) 2>&1 | tee /tmp/klipper-build.log; then
        echo ""
        echo -e "${GREEN}  ✓ Firmware built successfully!${NC}"
        
        # Find the firmware file
        if [ -f "out/klipper.bin" ]; then
            FIRMWARE_FILE="$KLIPPER_DIR/out/klipper.bin"
            FIRMWARE_SIZE=$(du -h "$FIRMWARE_FILE" | cut -f1)
            echo "  → Firmware: $FIRMWARE_FILE ($FIRMWARE_SIZE)"
            return 0
        else
            echo -e "${YELLOW}  ⚠ Firmware file not found at expected location${NC}"
            return 1
        fi
    else
        echo -e "${RED}  ✗ Firmware build failed!${NC}"
        echo "  → Check build log: /tmp/klipper-build.log"
        return 1
    fi
}

# Flash firmware (interactive)
flash_firmware() {
    local firmware_file="$1"
    local mcu_type="$2"
    
    if [ ! -f "$firmware_file" ]; then
        echo -e "${RED}  ✗ Firmware file not found: $firmware_file${NC}"
        return 1
    fi
    
    echo ""
    echo -e "${GREEN}Step 10: Flashing firmware...${NC}"
    echo ""
    echo "Firmware ready: $firmware_file"
    echo "MCU Type: $mcu_type"
    echo ""
    echo "Flashing methods:"
    echo "  1) SD Card (Recommended for STM32 - most reliable)"
    echo "  2) USB/DFU (STM32 bootloader mode)"
    echo "  3) ST-Link (Hardware programmer)"
    echo "  4) USB Serial (RP2040 - hold BOOTSEL button)"
    echo "  5) Skip flashing (do it manually later)"
    echo ""
    
    if [ "$NON_INTERACTIVE" = true ]; then
        echo "  → Skipping flash (non-interactive mode)"
        echo "  → Firmware saved at: $firmware_file"
        return 0
    fi
    
    read -p "Select flashing method [1-5]: " flash_method
    
    case $flash_method in
        1)
            flash_via_sd_card "$firmware_file" "$mcu_type"
            ;;
        2)
            flash_via_dfu "$firmware_file" "$mcu_type"
            ;;
        3)
            flash_via_stlink "$firmware_file" "$mcu_type"
            ;;
        4)
            flash_via_usb_serial "$firmware_file" "$mcu_type"
            ;;
        5)
            echo "  → Skipping flash"
            echo "  → Firmware saved at: $firmware_file"
            echo ""
            echo "To flash manually:"
            show_flash_instructions "$firmware_file" "$mcu_type"
            ;;
        *)
            echo -e "${YELLOW}  ⚠ Invalid selection, skipping flash${NC}"
            show_flash_instructions "$firmware_file" "$mcu_type"
            ;;
    esac
}

# Flash via SD card (STM32)
flash_via_sd_card() {
    local firmware_file="$1"
    local mcu_type="$2"
    
    echo ""
    echo -e "${BLUE}SD Card Flashing (STM32)${NC}"
    echo ""
    echo "Steps:"
    echo "  1. Copy firmware.bin to SD card root"
    echo "  2. Rename to: FIRMWARE.bin (uppercase)"
    echo "  3. Insert SD card into board"
    echo "  4. Power cycle board"
    echo ""
    
    # Detect SD card
    local sd_card=""
    if lsblk | grep -q "mmcblk"; then
        sd_card=$(lsblk | grep "mmcblk" | grep "disk" | awk '{print $1}' | head -1)
        echo "Detected SD card: /dev/$sd_card"
    fi
    
    read -p "Copy firmware to SD card now? [y/N]: " copy_sd
    if [ "$copy_sd" = "y" ] || [ "$copy_sd" = "Y" ]; then
        if [ -n "$sd_card" ] && [ -b "/dev/$sd_card" ]; then
            # Check if mounted
            local mount_point=$(mount | grep "$sd_card" | awk '{print $3}' | head -1)
            if [ -n "$mount_point" ]; then
                echo "  → SD card mounted at: $mount_point"
                cp "$firmware_file" "$mount_point/FIRMWARE.bin"
                echo "  ✓ Copied firmware to SD card"
                echo ""
                echo "Next steps:"
                echo "  1. Safely eject SD card: sudo umount $mount_point"
                echo "  2. Insert SD card into board"
                echo "  3. Power cycle board"
                echo "  4. Wait for firmware to flash (LED will blink)"
            else
                echo -e "${YELLOW}  ⚠ SD card not mounted${NC}"
                echo "  → Mount it first, or copy manually"
            fi
        else
            echo -e "${YELLOW}  ⚠ SD card not detected${NC}"
            echo "  → Insert SD card and try again"
        fi
    else
        echo ""
        echo "Manual SD card flash:"
        echo "  cp $firmware_file /path/to/sd/FIRMWARE.bin"
    fi
}

# Flash via DFU (STM32 bootloader)
flash_via_dfu() {
    local firmware_file="$1"
    local mcu_type="$2"
    
    echo ""
    echo -e "${BLUE}DFU Flashing (STM32 Bootloader)${NC}"
    echo ""
    echo "Entering bootloader mode..."
    echo "  - Hold BOOT0 button and press RESET"
    echo "  - Or use: make flash FLASH_DEVICE=/dev/serial/by-id/..."
    echo ""
    
    # Try to enter bootloader
    local serial_port=$(ls -1 /dev/serial/by-id/ 2>/dev/null | grep -i "Klipper\|stm32" | head -1)
    if [ -n "$serial_port" ]; then
        echo "Found serial port: /dev/serial/by-id/$serial_port"
        read -p "Enter bootloader mode now, then press Enter..." dummy
        
        # Check for DFU device
        if lsusb | grep -q "0483:df11\|1209:beba"; then
            echo "  ✓ DFU device detected"
            echo "  → Flashing firmware..."
            cd "$KLIPPER_DIR"
            if make flash FLASH_DEVICE=/dev/serial/by-id/$serial_port 2>&1; then
                echo -e "${GREEN}  ✓ Firmware flashed successfully!${NC}"
            else
                echo -e "${RED}  ✗ Flash failed${NC}"
                echo "  → Try SD card method instead"
            fi
        else
            echo -e "${YELLOW}  ⚠ DFU device not detected${NC}"
            echo "  → Make sure board is in bootloader mode"
        fi
    else
        echo -e "${YELLOW}  ⚠ Serial port not found${NC}"
        echo "  → Connect board and try again"
    fi
}

# Flash via ST-Link
flash_via_stlink() {
    local firmware_file="$1"
    local mcu_type="$2"
    
    echo ""
    echo -e "${BLUE}ST-Link Flashing${NC}"
    echo ""
    echo "ST-Link hardware programmer required"
    echo ""
    
    if command -v st-flash >/dev/null 2>&1; then
        echo "  → st-flash found"
        echo "  → Flashing to address 0x8002000 (8KiB bootloader)..."
        if sudo st-flash --reset write "$firmware_file" 0x8002000; then
            echo -e "${GREEN}  ✓ Firmware flashed successfully!${NC}"
        else
            echo -e "${RED}  ✗ Flash failed${NC}"
        fi
    else
        echo -e "${YELLOW}  ⚠ st-flash not installed${NC}"
        echo "  → Install: sudo apt install stlink-tools"
        echo "  → Or use SD card method"
    fi
}

# Flash via USB Serial (RP2040)
flash_via_usb_serial() {
    local firmware_file="$1"
    local mcu_type="$2"
    
    echo ""
    echo -e "${BLUE}USB Serial Flashing (RP2040)${NC}"
    echo ""
    echo "RP2040 bootloader mode:"
    echo "  1. Hold BOOTSEL button"
    echo "  2. Connect USB cable"
    echo "  3. Release BOOTSEL button"
    echo ""
    
    read -p "Enter bootloader mode now, then press Enter..." dummy
    
    if lsusb | grep -q "2e8a:0003"; then
        echo "  ✓ RP2040 bootloader detected"
        cd "$KLIPPER_DIR"
        if python3 lib/rp2040_flash/flash_usb.py "$firmware_file" 2>&1; then
            echo -e "${GREEN}  ✓ Firmware flashed successfully!${NC}"
        else
            echo -e "${RED}  ✗ Flash failed${NC}"
            echo "  → Check bootloader mode"
        fi
    else
        echo -e "${YELLOW}  ⚠ RP2040 bootloader not detected${NC}"
        echo "  → Make sure board is in bootloader mode"
    fi
}

# Show flash instructions
show_flash_instructions() {
    local firmware_file="$1"
    local mcu_type="$2"
    
    echo ""
    echo -e "${BLUE}Manual Flash Instructions:${NC}"
    echo ""
    echo "Firmware location: $firmware_file"
    echo ""
    
    if [[ "$mcu_type" == *"STM32"* ]]; then
        echo "STM32 Flashing:"
        echo "  SD Card: cp $firmware_file /path/to/sd/FIRMWARE.bin"
        echo "  DFU: make flash FLASH_DEVICE=/dev/serial/by-id/..."
        echo "  ST-Link: sudo st-flash write $firmware_file 0x8002000"
    elif [[ "$mcu_type" == *"RP2040"* ]] || [[ "$mcu_type" == *"RP2350"* ]]; then
        echo "RP2040/RP2350 Flashing:"
        echo "  USB: python3 ~/klipper/lib/rp2040_flash/flash_usb.py $firmware_file"
        echo "  (Hold BOOTSEL button while connecting USB)"
    fi
    echo ""
}

# Build firmware if requested
if [ "$NON_INTERACTIVE" = false ]; then
    read -p "Build firmware now? [Y/n]: " build_answer
    if [ "$build_answer" != "n" ] && [ "$build_answer" != "N" ]; then
        if build_firmware; then
            read -p "Flash firmware now? [y/N]: " flash_answer
            if [ "$flash_answer" = "y" ] || [ "$flash_answer" = "Y" ]; then
                flash_firmware "$FIRMWARE_FILE" "$MCU_TYPE"
            else
                show_flash_instructions "$FIRMWARE_FILE" "$MCU_TYPE"
            fi
        fi
    else
        echo ""
        echo "Skipping firmware build"
        echo "Build later: cd ~/klipper && make"
    fi
else
    echo ""
    echo -e "${BLUE}Skipping firmware build (non-interactive mode)${NC}"
    echo "Build later: cd ~/klipper && make"
fi


# Step 8: Run Python script for MCU/config setup
echo ""
echo -e "${GREEN}Step 8: Running Python setup script...${NC}"
PYTHON_SCRIPT="$INSTALL_DIR/setup_cm4.py"
if [ -f "$PYTHON_SCRIPT" ]; then
    # Pass through arguments to Python script (filter out --dev/--development)
    FILTERED_ARGS=""
    for arg in "$@"; do
        if [[ "$arg" != "--dev" ]] && [[ "$arg" != "--development" ]]; then
            FILTERED_ARGS="$FILTERED_ARGS $arg"
        fi
    done
    python3 "$PYTHON_SCRIPT" $FILTERED_ARGS
else
    echo -e "${YELLOW}  ⚠ Python script not found: $PYTHON_SCRIPT${NC}"
    echo "  → Continuing with manual setup..."
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "MCU Configuration: $MCU_TYPE"
[ -n "$SELECTED_CONFIG_FILE" ] && echo "Config File: $SELECTED_CONFIG_FILE"
echo ""
echo "Next steps:"
echo "  1. Build firmware: cd ~/klipper && make"
echo "  2. Flash firmware to MCU"
if [ -f "$HOME/printer.cfg" ]; then
    echo "  3. ✓ Config file ready: ~/printer.cfg"
    if grep -q "^serial:" "$HOME/printer.cfg" 2>/dev/null; then
        echo "     → Serial port: $(grep '^serial:' "$HOME/printer.cfg" | cut -d' ' -f2)"
    else
        echo "     → Serial port needs to be updated manually"
    fi
else
    echo "  3. Copy config: cp ~/klipper-install/config/generic-bigtreetech-manta-m8p-V1_1.cfg ~/printer.cfg"
    echo "  4. Edit config: nano ~/printer.cfg (update serial port)"
fi
echo "  5. Start service: sudo systemctl start klipper"
echo ""
if [ "$NON_INTERACTIVE" = false ]; then
    echo "Note: To change MCU settings, run: cd ~/klipper && make menuconfig"
fi
echo ""
