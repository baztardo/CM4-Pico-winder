#!/bin/bash
# Create a new Klipper installation from master install
# Usage: ./create_klipper_install.sh [TARGET_DIR]

set -e

INSTALL_DIR="~/install-klipper"
TARGET_DIR="${1:-~/klipper}"

# Expand paths
INSTALL_DIR=$(eval echo "$INSTALL_DIR")
TARGET_DIR=$(eval echo "$TARGET_DIR")

if [ ! -d "$INSTALL_DIR" ]; then
    echo "ERROR: Master install not found at $INSTALL_DIR"
    echo "Run install_klipper_smart.sh first to create master install"
    exit 1
fi

echo "Creating new Klipper installation from master..."
echo "Target: $TARGET_DIR"
echo ""

# Copy files
cp -r "$INSTALL_DIR" "$TARGET_DIR"

# Copy custom files
if [ -f "klippy/extras/winder.py" ]; then
    cp "klippy/extras/winder.py" "$TARGET_DIR/klippy/extras/"
fi
if [ -f "klippy/kinematics/winder.py" ]; then
    cp "klippy/kinematics/winder.py" "$TARGET_DIR/klippy/kinematics/"
fi

# Copy minimal config if exists
if [ -f ".config.winder-minimal" ]; then
    cp ".config.winder-minimal" "$TARGET_DIR/.config"
fi

echo "✓ Installation created at: $TARGET_DIR"
echo ""
echo "Next steps:"
echo "  cd $TARGET_DIR"
echo "  make menuconfig"
echo "  make"

