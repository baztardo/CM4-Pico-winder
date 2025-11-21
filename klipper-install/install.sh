#!/bin/bash
# Main Installation Script
# Handles prerequisites, system setup, then calls Python script for complex tasks

set -e

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KLIPPER_DIR="$HOME/klipper"
PYTHON_SCRIPT="$INSTALL_DIR/setup_cm4.py"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Parse arguments (pass through to Python script)
ARGS="$@"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Klipper Winder Installation${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check prerequisites
check_prerequisites() {
    echo -e "${GREEN}Checking prerequisites...${NC}"
    local missing=0
    
    # Check Python3
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}  ✗ Python3 not found${NC}"
        missing=1
    else
        PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
        echo -e "${GREEN}  ✓ Python3: $PYTHON_VERSION${NC}"
    fi
    
    # Check sudo
    if ! command -v sudo &> /dev/null; then
        echo -e "${RED}  ✗ sudo not found${NC}"
        missing=1
    else
        echo -e "${GREEN}  ✓ sudo available${NC}"
    fi
    
    # Check git
    if ! command -v git &> /dev/null; then
        echo -e "${YELLOW}  ⚠ git not found (will install)${NC}"
    else
        echo -e "${GREEN}  ✓ git available${NC}"
    fi
    
    if [ $missing -eq 1 ]; then
        echo ""
        echo -e "${RED}Missing prerequisites!${NC}"
        echo "Install Python3: sudo apt update && sudo apt install python3"
        exit 1
    fi
    
    echo ""
}

# Install system dependencies
install_dependencies() {
    echo -e "${GREEN}Step 1: Installing dependencies...${NC}"
    
    sudo apt update
    
    if [[ "$ARGS" != *"--skip-upgrade"* ]] && [[ "$ARGS" != *"--non-interactive"* ]]; then
        read -p "Upgrade system packages? [Y/n]: " upgrade_answer
        if [ -z "$upgrade_answer" ] || [ "$upgrade_answer" = "y" ] || [ "$upgrade_answer" = "Y" ]; then
            sudo apt upgrade -y
            echo "  ✓ System upgraded"
        else
            echo "  ⏭ Skipping system upgrade"
        fi
    fi
    
    sudo apt install -y \
        build-essential \
        git \
        python3 \
        python3-pip \
        python3-dev \
        python3-setuptools \
        python3-venv \
        libncurses-dev \
        libusb-1.0-0-dev \
        gcc-arm-none-eabi \
        binutils-arm-none-eabi \
        python3-serial \
        dfu-util \
        screen
    
    echo -e "${GREEN}✓ Dependencies installed${NC}"
    echo ""
}

# Cleanup old installation
cleanup_old() {
    echo -e "${GREEN}Step 2: Cleaning up old installation...${NC}"
    
    [ -d "$KLIPPER_DIR" ] && rm -rf "$KLIPPER_DIR"
    sudo systemctl stop klipper 2>/dev/null || true
    sudo systemctl disable klipper 2>/dev/null || true
    sudo rm -f /etc/systemd/system/klipper.service /etc/default/klipper
    sudo systemctl daemon-reload
    rm -f ~/printer.cfg ~/printer.cfg.backup ~/printer.cfg.old /tmp/klippy.log /tmp/klippy.log.old
    
    echo -e "${GREEN}✓ Cleanup complete${NC}"
    echo ""
}

# Clone Klipper - choose between dev environment or minimal install
clone_klipper() {
    echo -e "${GREEN}Step 3: Setting up Klipper...${NC}"
    
    # Check if user wants dev environment
    if [[ "$ARGS" == *"--dev"* ]] || [[ "$ARGS" == *"--development"* ]]; then
        echo "  → Setting up DEVELOPMENT environment..."
        "$INSTALL_DIR/scripts/setup_dev_environment.sh"
        return
    fi
    
    # Otherwise, minimal install (production)
    echo "  → Setting up MINIMAL installation..."
    
    TEMP_KLIPPER="$INSTALL_DIR/tmp-klipper"
    
    # Clean up any existing temp clone
    [ -d "$TEMP_KLIPPER" ] && rm -rf "$TEMP_KLIPPER"
    
    # Clone to temp directory within klipper-install
    echo "  → Cloning to temp directory: $TEMP_KLIPPER"
    cd "$INSTALL_DIR"
    git clone https://github.com/Klipper3d/klipper.git "$TEMP_KLIPPER"
    
    echo "  → Copying essential files only..."
    
    # Create target directory
    mkdir -p "$KLIPPER_DIR"
    
    # Essential directories/files for Klipper to work
    ESSENTIAL_DIRS=(
        "klippy"           # Python runtime (required)
        "lib"              # Libraries (chelper, rp2040_flash, etc.)
        "scripts"          # Build/flash scripts
        "src"              # Firmware source (needed for build)
        ".github"          # GitHub config (for version info)
    )
    
    ESSENTIAL_FILES=(
        "Makefile"
        ".gitignore"
        "COPYING"
        "README.md"
    )
    
    # Copy essential directories
    for dir in "${ESSENTIAL_DIRS[@]}"; do
        if [ -d "$TEMP_KLIPPER/$dir" ]; then
            cp -r "$TEMP_KLIPPER/$dir" "$KLIPPER_DIR/"
            echo "    ✓ Copied: $dir/"
        fi
    done
    
    # Copy essential files
    for file in "${ESSENTIAL_FILES[@]}"; do
        if [ -f "$TEMP_KLIPPER/$file" ]; then
            cp "$TEMP_KLIPPER/$file" "$KLIPPER_DIR/"
            echo "    ✓ Copied: $file"
        fi
    done
    
    # Copy klippy-requirements.txt if it exists
    if [ -f "$TEMP_KLIPPER/scripts/klippy-requirements.txt" ]; then
        mkdir -p "$KLIPPER_DIR/scripts"
        cp "$TEMP_KLIPPER/scripts/klippy-requirements.txt" "$KLIPPER_DIR/scripts/"
        echo "    ✓ Copied: scripts/klippy-requirements.txt"
    fi
    
    # Clean up unused source files after copying (if config exists)
    if [ -f "$INSTALL_DIR/.config.winder-minimal" ]; then
        echo "  → Cleaning up unused source files..."
        cp "$INSTALL_DIR/.config.winder-minimal" "$KLIPPER_DIR/.config.winder-minimal"
        "$INSTALL_DIR/scripts/cleanup_unused_src_files.sh" "$KLIPPER_DIR" "$KLIPPER_DIR/.config.winder-minimal" || true
        
        # Patch Kconfig and Makefile to handle missing files/directories
        echo "  → Patching Kconfig and Makefile for conditional sourcing..."
        "$INSTALL_DIR/scripts/patch_kconfig_conditional.sh" "$KLIPPER_DIR" || true
        "$INSTALL_DIR/scripts/patch_makefile_conditional.sh" "$KLIPPER_DIR" || true
    fi
    
    # Keep temp clone for development/debugging (can be cleaned up later)
    echo ""
    echo -e "${YELLOW}  ℹ Temp clone kept at: $TEMP_KLIPPER${NC}"
    echo -e "${YELLOW}  ℹ You can add missing files during development${NC}"
    echo -e "${YELLOW}  ℹ Clean up later with: rm -rf $TEMP_KLIPPER${NC}"
    echo -e "${YELLOW}  ℹ For dev environment, use: ./install.sh --dev${NC}"
    
    echo -e "${GREEN}✓ Klipper installed (minimal - essential files only)${NC}"
    echo ""
}

# Setup Python virtual environment
setup_python_env() {
    echo -e "${GREEN}Step 4: Setting up Python virtual environment...${NC}"
    
    cd "$KLIPPER_DIR"
    [ ! -d "klippy-env" ] && python3 -m venv klippy-env
    source klippy-env/bin/activate
    pip install --upgrade pip
    
    # Install Klipper Python requirements
    if [ -f "scripts/klippy-requirements.txt" ]; then
        pip install -r scripts/klippy-requirements.txt
    else
        pip install cffi pyserial
    fi
    
    echo -e "${GREEN}✓ Python environment ready${NC}"
    echo ""
}

# Compile chelper
compile_chelper() {
    echo -e "${GREEN}Step 5: Compiling chelper files...${NC}"
    
    cd "$KLIPPER_DIR/klippy/chelper"
    if [ -f "setup.py" ]; then
        python3 setup.py build_ext --inplace && echo "  ✓ chelper compiled" || echo -e "${YELLOW}  ⚠ chelper compilation skipped${NC}"
    else
        echo -e "${YELLOW}  ⚠ chelper setup.py not found${NC}"
    fi
    
    cd "$KLIPPER_DIR"
    echo -e "${GREEN}✓ chelper complete${NC}"
    echo ""
}

# Install custom files
install_custom_files() {
    echo -e "${GREEN}Step 6: Installing custom winder files...${NC}"
    
    cd "$INSTALL_DIR"
    
    # Check for custom installer script (different name to avoid recursion)
    if [ -f "install_custom_files.sh" ]; then
        ./install_custom_files.sh "$KLIPPER_DIR"
    else
        copy_files_manually
    fi
    
    echo -e "${GREEN}✓ Custom files installed${NC}"
    echo ""
}

copy_files_manually() {
    mkdir -p "$KLIPPER_DIR/klippy/extras" "$KLIPPER_DIR/klippy/kinematics"
    
    [ -f "extras/winder.py" ] && cp extras/winder.py "$KLIPPER_DIR/klippy/extras/" && echo "  ✓ winder.py"
    [ -f "kinematics/winder.py" ] && cp kinematics/winder.py "$KLIPPER_DIR/klippy/kinematics/" && echo "  ✓ kinematics/winder.py"
    [ -f ".config.winder-minimal" ] && cp .config.winder-minimal "$KLIPPER_DIR/.config.winder-minimal" && echo "  ✓ .config preset"
    
    # Copy scripts
    if [ -d "scripts" ]; then
        mkdir -p "$KLIPPER_DIR/scripts"
        for script in scripts/*.py scripts/*.sh; do
            if [ -f "$script" ]; then
                cp "$script" "$KLIPPER_DIR/scripts/" 2>/dev/null && echo "  ✓ $(basename $script)" || true
            fi
        done
    fi
}

# Create systemd service
create_service() {
    echo -e "${GREEN}Step 7: Creating systemd service...${NC}"
    
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
    echo ""
}

# Main execution
main() {
    echo "This script will:"
    echo "  1. Check prerequisites"
    echo "  2. Install system dependencies"
    if [[ "$ARGS" == *"--dev"* ]] || [[ "$ARGS" == *"--development"* ]]; then
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
    echo "  ./install.sh --dev                    # Dev environment, auto-detect MCU"
    echo "  ./install.sh --mcu=AUTO               # Minimal install, auto-detect MCU"
    echo "  ./install.sh --dev --mcu=STM32G0B1     # Dev environment, STM32G0B1 MCU"
    echo "  ./install.sh --mcu=RP2040 --non-interactive  # Minimal, RP2040, no prompts"
    echo ""
    
    if [[ "$ARGS" != *"--non-interactive"* ]]; then
        read -p "Continue? [Y/n]: " answer
        if [ -n "$answer" ] && [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
            echo "Cancelled."
            exit 0
        fi
    fi
    
    check_prerequisites
    install_dependencies
    cleanup_old
    clone_klipper
    setup_python_env
    compile_chelper
    install_custom_files
    create_service
    
    # Now call Python script for complex tasks
    echo -e "${GREEN}Step 8: Running Python setup script...${NC}"
    echo ""
    
    if [ ! -f "$PYTHON_SCRIPT" ]; then
        echo -e "${RED}  ✗ Python script not found: $PYTHON_SCRIPT${NC}"
        echo "  → Continuing with manual setup..."
        exit 1
    fi
    
    # Pass through arguments to Python script (filter out --dev/--development)
    FILTERED_ARGS=""
    for arg in $ARGS; do
        if [[ "$arg" != "--dev" ]] && [[ "$arg" != "--development" ]]; then
            FILTERED_ARGS="$FILTERED_ARGS $arg"
        fi
    done
    python3 "$PYTHON_SCRIPT" $FILTERED_ARGS
    
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}Installation Complete!${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

main "$@"
