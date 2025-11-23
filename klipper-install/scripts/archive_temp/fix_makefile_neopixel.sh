#!/bin/bash
# Fix Makefile issue where neopixel.o is being built even when disabled
# This happens if .config has CONFIG_WANT_NEOPIXEL=y OR if dependency files are stale

KLIPPER_DIR="${1:-$HOME/klipper}"

if [ ! -d "$KLIPPER_DIR" ]; then
    echo "Error: Klipper directory not found: $KLIPPER_DIR"
    exit 1
fi

cd "$KLIPPER_DIR"

echo "Step 1: Fixing .config..."
if [ -f "$HOME/klipper-install/.config.winder-minimal" ]; then
    cp "$HOME/klipper-install/.config.winder-minimal" .config
    echo "   ✓ Copied .config.winder-minimal to .config"
else
    echo "   ⚠️  .config.winder-minimal not found, disabling features manually..."
    sed -i 's/^CONFIG_WANT_NEOPIXEL=y/# CONFIG_WANT_NEOPIXEL is not set/' .config
    sed -i 's/^CONFIG_WANT_ST7920=y/# CONFIG_WANT_ST7920 is not set/' .config
    sed -i 's/^CONFIG_WANT_HD44780=y/# CONFIG_WANT_HD44780 is not set/' .config
    sed -i 's/^CONFIG_WANT_THERMOCOUPLE=y/# CONFIG_WANT_THERMOCOUPLE is not set/' .config
    sed -i 's/^CONFIG_WANT_ADXL345=y/# CONFIG_WANT_ADXL345 is not set/' .config
fi

echo ""
echo "Step 2: Verifying .config..."
if grep -q "^CONFIG_WANT_NEOPIXEL=y" .config; then
    echo "❌ CONFIG_WANT_NEOPIXEL is still enabled!"
    exit 1
else
    echo "✅ CONFIG_WANT_NEOPIXEL is disabled"
fi

echo ""
echo "Step 3: Running make clean..."
make clean
echo "✓ Cleaned build directory"

echo ""
echo "Step 4: Checking if source files exist (they shouldn't)..."
if [ -f "src/neopixel.c" ]; then
    echo "⚠️  WARNING: src/neopixel.c still exists!"
    echo "   This means the cleanup script didn't run or the file was restored"
    echo "   Run: ~/klipper-install/scripts/cleanup_unused_src_files.sh ~/klipper"
else
    echo "✅ src/neopixel.c doesn't exist (as expected)"
fi

echo ""
echo "Step 5: Running make olddefconfig to ensure config is valid..."
# olddefconfig sets defaults for new options but doesn't change existing ones
make olddefconfig
echo "✓ Config validated"

echo ""
echo "Step 6: Verifying CONFIG_USBSERIAL is set (needed for console_sendf)..."
if grep -q "^CONFIG_USBSERIAL=y" .config; then
    echo "✅ CONFIG_USBSERIAL=y is set"
elif grep -q "^CONFIG_STM32_USB_PA11_PA12=y" .config; then
    echo "⚠️  CONFIG_STM32_USB_PA11_PA12=y is set, but CONFIG_USBSERIAL is not explicitly set"
    echo "   This should be auto-selected. Adding it explicitly..."
    echo "CONFIG_USBSERIAL=y" >> .config
    echo "   ✓ Added CONFIG_USBSERIAL=y"
else
    echo "❌ CONFIG_USBSERIAL is not set and STM32 USB config not found!"
fi

echo ""
echo "Step 7: Checking if usb_cdc.c exists..."
if [ -f "src/generic/usb_cdc.c" ]; then
    echo "✅ src/generic/usb_cdc.c exists"
else
    echo "❌ src/generic/usb_cdc.c NOT FOUND!"
    echo "   This file was likely removed by cleanup script"
    echo "   Restore it from: ~/klipper-install/tmp-klipper/src/generic/usb_cdc.c"
fi

echo ""
echo "Step 8: Final verification..."
if grep -q "^CONFIG_WANT_NEOPIXEL=y" .config; then
    echo "❌ CONFIG_WANT_NEOPIXEL was re-enabled by olddefconfig!"
    echo "   Manually disabling..."
    sed -i 's/^CONFIG_WANT_NEOPIXEL=y/# CONFIG_WANT_NEOPIXEL is not set/' .config
else
    echo "✅ CONFIG_WANT_NEOPIXEL is still disabled"
fi

echo ""
echo "Now try: make"
echo "  (Skip 'make menuconfig' - it may auto-enable features)"
