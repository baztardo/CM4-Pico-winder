#!/bin/bash
# Check why console_sendf is missing

KLIPPER_DIR="${1:-$HOME/klipper}"

if [ ! -d "$KLIPPER_DIR" ]; then
    echo "Error: Klipper directory not found: $KLIPPER_DIR"
    exit 1
fi

cd "$KLIPPER_DIR"

echo "Checking USB serial configuration..."
echo ""

echo "1. Checking CONFIG_USBSERIAL:"
if grep -q "^CONFIG_USBSERIAL=y" .config; then
    echo "   ✅ CONFIG_USBSERIAL=y is set"
else
    echo "   ❌ CONFIG_USBSERIAL is NOT set"
    echo "   This is required for usb_cdc.c to compile"
fi

echo ""
echo "2. Checking CONFIG_STM32_USB_PA11_PA12:"
if grep -q "^CONFIG_STM32_USB_PA11_PA12=y" .config; then
    echo "   ✅ CONFIG_STM32_USB_PA11_PA12=y is set"
    echo "   This should auto-select CONFIG_USBSERIAL"
else
    echo "   ❌ CONFIG_STM32_USB_PA11_PA12 is NOT set"
fi

echo ""
echo "3. Checking if usb_cdc.c exists:"
if [ -f "src/generic/usb_cdc.c" ]; then
    echo "   ✅ src/generic/usb_cdc.c exists"
else
    echo "   ❌ src/generic/usb_cdc.c NOT FOUND!"
    echo "   This file was likely removed by cleanup script"
    if [ -f "$HOME/klipper-install/tmp-klipper/src/generic/usb_cdc.c" ]; then
        echo "   → Found in temp clone, can restore it"
    fi
fi

echo ""
echo "4. Checking if usb_cdc.o is being built:"
if [ -f "out/src/generic/usb_cdc.o" ]; then
    echo "   ✅ out/src/generic/usb_cdc.o exists (was compiled)"
else
    echo "   ❌ out/src/generic/usb_cdc.o NOT FOUND (not compiled)"
fi

echo ""
echo "5. Checking Makefile dependency:"
if grep -q "usb_cdc.c" src/stm32/Makefile 2>/dev/null; then
    echo "   ✅ src/stm32/Makefile references usb_cdc.c"
    echo "   Condition: src-\$(CONFIG_USBSERIAL) += ... generic/usb_cdc.c"
else
    echo "   ⚠️  Could not check Makefile"
fi

echo ""
echo "FIX:"
if ! grep -q "^CONFIG_USBSERIAL=y" .config; then
    echo "   Run: echo 'CONFIG_USBSERIAL=y' >> .config"
fi
if [ ! -f "src/generic/usb_cdc.c" ]; then
    echo "   Restore: cp ~/klipper-install/tmp-klipper/src/generic/usb_cdc.c src/generic/usb_cdc.c"
fi

