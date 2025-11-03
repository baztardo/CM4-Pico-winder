#!/bin/bash
# Build script for CM4-Pico-winder multi-platform CNC winder

# Set up PATH for ARM GCC toolchain and binutils
export PATH="/opt/homebrew/opt/binutils/bin:/Users/ssnow/Documents/GitHub/CM4-Pico-winder/tools/arm-gnu-toolchain-14.3.rel1-darwin-arm64-arm-none-eabi/bin:$PATH"

# MCU switching support
if [ "$1" = "simulator" ]; then
    echo "🔄 Switching to Simulator (software testing)..."
    cp .config.simulator .config 2>/dev/null || echo "❌ .config.simulator not found"
    shift
elif [ "$1" = "rp2350" ]; then
    echo "🔄 Switching to RP2350 (Raspberry Pi Pico)..."
    cp .config.rp2350 .config 2>/dev/null || echo "❌ .config.rp2350 not found"
    shift
elif [ "$1" = "stm32f401" ]; then
    echo "🔄 Switching to STM32F401RE (CLEO)..."
    cp .config.stm32f401 .config 2>/dev/null || echo "❌ .config.stm32f401 not found"
    shift
elif [ "$1" = "stm32g0" ]; then
    echo "🔄 Switching to STM32G0B0 (BTT Manta MP4)..."
    cp .config.stm32g0 .config 2>/dev/null || echo "❌ .config.stm32g0 not found"
    shift
fi

MCU_TYPE=$(grep 'CONFIG_MCU=' .config | cut -d'"' -f2)
echo "Building CM4-Pico-winder for $MCU_TYPE..."
echo "PATH includes: $(which arm-none-eabi-gcc)"
echo "Binutils: $(which readelf)"
echo ""

# Run make with parallel jobs (quiet mode)
if [ "$1" = "verbose" ]; then
    make -j4 "$@"
else
    make -j4 "$@" 2>&1 | grep -E "(error|Error|ERROR|warning|Warning|WARNING|✅|❌|Compiling|Linking|Building)" || echo "Build completed with no significant output"
fi

echo ""
if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo "Output files:"
    ls -la out/klipper.elf out/klipper.uf2 2>/dev/null || echo "No output files found"
    echo ""
    echo "🎯 Flash commands:"
    if [[ "$MCU_TYPE" == "rp2350" ]]; then
        echo "   Put Pico in BOOTSEL mode, then:"
        echo "   cp out/klipper.uf2 /Volumes/RPI-RP2/"
    else
        echo "   STM32 boards: Use dfu-util or your board's flash tool"
        echo "   Check docs for your specific board flashing instructions"
    fi
else
    echo "❌ Build failed!"
fi
