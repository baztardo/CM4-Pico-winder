#!/bin/bash
# Analyze Klipper build dependencies to determine minimal file set
# Usage: ./scripts/analyze_klipper_dependencies.sh [klipper_dir]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

KLIPPER_DIR="${1:-$INSTALL_DIR/klipper-dev}"
if [ ! -d "$KLIPPER_DIR" ]; then
    echo "Error: Klipper directory not found: $KLIPPER_DIR"
    echo "Usage: $0 [klipper_dir]"
    echo "Or clone Klipper first: git clone https://github.com/Klipper3d/klipper.git $KLIPPER_DIR"
    exit 1
fi

echo "Analyzing Klipper build dependencies..."
echo "Klipper directory: $KLIPPER_DIR"
echo ""

cd "$KLIPPER_DIR"

# Check if .config exists (needed to determine what's actually compiled)
if [ ! -f ".config" ]; then
    echo "⚠ No .config found - analyzing all possible dependencies"
    echo "  Run 'make menuconfig' first for accurate analysis"
    echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. Checking Makefile structure..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Find all Makefiles
echo "Makefiles found:"
find . -name "Makefile" -o -name "*.mk" | grep -v ".git" | head -10
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. Analyzing src/ directory structure..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -d "src" ]; then
    echo "src/ subdirectories:"
    find src -type d -maxdepth 2 | sort
    echo ""
    
    echo "Sensor-related files:"
    find src -name "*sensor*" -o -name "*adxl*" -o -name "*mpu*" -o -name "*lis*" | head -20
    echo ""
    
    echo "Display-related files:"
    find src -name "*lcd*" -o -name "*display*" -o -name "*hd44780*" -o -name "*st7920*" | head -20
    echo ""
    
    echo "Neopixel/LED files:"
    find src -name "*neopixel*" -o -name "*led*" | head -20
    echo ""
    
    echo "MCU-specific directories:"
    find src -type d -name "stm32*" -o -name "rp2040*" -o -name "atmega*" -o -name "sam*" | head -20
    echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. Checking Makefile for conditional compilation..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f "Makefile" ]; then
    echo "Conditional compilation patterns in main Makefile:"
    grep -E "CONFIG_|ifeq|ifdef|ifneq" Makefile | head -20
    echo ""
fi

if [ -f "src/Makefile" ]; then
    echo "Conditional compilation in src/Makefile:"
    grep -E "CONFIG_|ifeq|ifdef|ifneq" src/Makefile | head -20
    echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. Checking what's actually compiled (if .config exists)..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f ".config" ]; then
    echo "Enabled features in .config:"
    grep -E "^CONFIG_" .config | grep "=y" | head -30
    echo ""
    
    echo "Disabled features:"
    grep -E "^# CONFIG_" .config | head -20
    echo ""
    
    # Try to see what would be compiled
    echo "Attempting dry-run build to see compiled files..."
    if command -v make >/dev/null 2>&1; then
        make -n 2>&1 | grep -E "Compiling|Building|src/" | head -30 || echo "  (Could not determine)"
    fi
else
    echo "⚠ No .config found - cannot determine what's actually compiled"
    echo "  Create one with: make menuconfig"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5. File size analysis..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -d "src" ]; then
    echo "Largest directories in src/:"
    du -sh src/* 2>/dev/null | sort -hr | head -10
    echo ""
    
    echo "Total src/ size:"
    du -sh src/
    echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6. Recommendations..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "To create a truly minimal install:"
echo "  1. Run 'make menuconfig' and disable unused features"
echo "  2. Run this script again to see what's actually needed"
echo "  3. Check if Makefile has hard dependencies on certain files"
echo "  4. Consider patching Makefile to skip unused MCU/sensor files"
echo ""

