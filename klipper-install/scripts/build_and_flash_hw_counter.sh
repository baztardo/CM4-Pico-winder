#!/bin/bash
# Build and Flash Hardware Counter Firmware
#
# This script:
# 1. Copies hw_counter.c to CM4
# 2. Copies hw_counter.py to CM4
# 3. Builds new firmware on CM4
# 4. Flashes firmware to M4P

set -e  # Exit on error

CM4_HOST="winder@winder.local"
LOCAL_DIR="/Users/ssnow/Documents/GitHub/CM4-Pico-winder"

echo "========================================="
echo "Hardware Counter Build and Flash Script"
echo "========================================="
echo ""

# Step 1: Copy files to CM4
echo "Step 1: Copying files to CM4..."
scp "${LOCAL_DIR}/src/hw_counter.c" "${CM4_HOST}:~/klipper/src/" || {
    echo "ERROR: Failed to copy hw_counter.c"
    exit 1
}

scp "${LOCAL_DIR}/klipper-install/extras/hw_counter.py" "${CM4_HOST}:~/klipper/klippy/extras/" || {
    echo "ERROR: Failed to copy hw_counter.py"
    exit 1
}

echo "✓ Files copied successfully"
echo ""

# Step 2: Build firmware on CM4
echo "Step 2: Building firmware on CM4..."
ssh "${CM4_HOST}" << 'EOF'
cd ~/klipper

# Clean previous build
echo "Cleaning previous build..."
make clean

# Build firmware
echo "Building firmware..."
make -j4 || {
    echo "ERROR: Firmware build failed!"
    exit 1
}

echo "✓ Firmware built successfully"
EOF

echo ""
echo "Step 3: Flash firmware to M4P"
echo ""
echo "MANUAL STEP REQUIRED:"
echo "1. Put M4P in DFU mode:"
echo "   - Hold BOOT button"
echo "   - Press RESET button"
echo "   - Release both buttons"
echo ""
echo "2. Then run on CM4:"
echo "   cd ~/klipper"
echo "   make flash FLASH_DEVICE=/dev/serial/by-id/usb-Klipper_stm32g0b1xx_5700170005504E5238363120-if00"
echo ""
echo "   OR use: sudo service klipper stop"
echo "           make flash FLASH_DEVICE=/dev/serial/by-id/usb-Klipper_stm32g0b1xx_*"
echo "           sudo service klipper start"
echo ""
echo "3. After flashing, restart Klipper:"
echo "   sudo systemctl restart klipper"
echo ""
echo "========================================="
echo "Build complete! Ready to flash."
echo "========================================="


