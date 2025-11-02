#!/bin/bash
# Build script for CM4-Pico-winder RP2350 motor controller

# Set up PATH for ARM GCC toolchain and binutils
export PATH="/opt/homebrew/opt/binutils/bin:/Users/ssnow/Documents/GitHub/CM4-Pico-winder/tools/arm-gnu-toolchain-14.3.rel1-darwin-arm64-arm-none-eabi/bin:$PATH"

echo "Building CM4-Pico-winder for RP2350..."
echo "PATH includes: $(which arm-none-eabi-gcc)"
echo "Binutils: $(which readelf)"
echo ""

# Run make with parallel jobs
make -j4 "$@"

echo ""
if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo "Output files:"
    ls -la out/klipper.elf out/klipper.uf2 2>/dev/null || echo "No output files found"
else
    echo "❌ Build failed!"
fi
