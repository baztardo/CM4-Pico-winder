#!/bin/bash

# Build script for CM4-Pico-winder (STM32 + RP2040 CNC winder firmware)

set -e

echo "=== CM4-Pico-winder Build Script ==="
echo

# Check if we're in the right directory
if [ ! -f "Makefile" ]; then
    echo "ERROR: Makefile not found. Run this script from the project root."
    exit 1
fi

# Detect MCU from .config
if [ -f ".config" ]; then
    MCU=$(grep "^CONFIG_MCU=" .config | cut -d'=' -f2 | tr -d '"')
    if [ -z "$MCU" ]; then
        MCU="unknown"
    fi
else
    MCU="unknown"
fi

echo "MCU detected: $MCU"
echo

# Function to build for specific MCU
build_mcu() {
    local mcu=$1
    local config_file=$2

    echo "=== Building for $mcu ==="

    if [ -f "$config_file" ]; then
        echo "Using config file: $config_file"
        cp "$config_file" .config
    fi

    # Configure if needed
    if [ ! -f ".config" ] || ! grep -q "CONFIG_MACH_" .config; then
        echo "Running make menuconfig..."
        make menuconfig
    fi

    # Build
    echo "Building firmware..."
    make clean
    make -j$(nproc)

    # Check output
    if [ "$mcu" = "stm32" ]; then
        if [ -f "out/klipper.bin" ]; then
            echo "✅ SUCCESS: STM32 firmware built - out/klipper.bin"
            ls -la out/klipper.bin
        else
            echo "❌ ERROR: STM32 build failed - no klipper.bin found"
            exit 1
        fi
    elif [ "$mcu" = "rp2040" ]; then
        if [ -f "out/klipper.uf2" ]; then
            echo "✅ SUCCESS: RP2040 firmware built - out/klipper.uf2"
            ls -la out/klipper.uf2
        else
            echo "❌ ERROR: RP2040 build failed - no klipper.uf2 found"
            exit 1
        fi
    fi

    echo
}

# Build options
case "$1" in
    "stm32")
        build_mcu "stm32" ".config.stm32"
        ;;
    "rp2040")
        build_mcu "rp2040" ".config.rp2040"
        ;;
    "all")
        echo "Building all MCUs..."
        build_mcu "stm32" ".config.stm32"
        build_mcu "rp2040" ".config.rp2040"
        ;;
    "clean")
        echo "Cleaning build..."
        make clean
        rm -f .config .config.stm32 .config.rp2040
        ;;
    *)
        echo "Usage: $0 {stm32|rp2040|all|clean}"
        echo
        echo "Examples:"
        echo "  ./build.sh stm32     - Build STM32 firmware"
        echo "  ./build.sh rp2040    - Build RP2040 firmware"
        echo "  ./build.sh all       - Build both"
        echo "  ./build.sh clean     - Clean build files"
        echo
        echo "Current MCU: $MCU"
        echo
        if [ "$MCU" = "stm32" ]; then
            echo "STM32 Flashing Instructions:"
            echo "1. Connect CLEO board via USB"
            echo "2. Drag out/klipper.bin to the NOD_F401DE drive"
            echo "3. Board will auto-reboot with new firmware"
        elif [ "$MCU" = "rp2040" ]; then
            echo "RP2040 Flashing Instructions:"
            echo "1. Put Pico in bootloader mode (hold BOOTSEL while plugging in)"
            echo "2. Drag out/klipper.uf2 to the RPI-RP2 drive"
        fi
        exit 1
        ;;
esac
