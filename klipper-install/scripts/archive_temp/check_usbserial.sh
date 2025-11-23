#!/bin/bash
# Check if CONFIG_USBSERIAL is enabled (needed for usb_cdc.c)

CONFIG_FILE="${1:-~/klipper/.config}"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file not found: $CONFIG_FILE"
    exit 1
fi

echo "Checking $CONFIG_FILE for USB serial config..."
echo ""

if grep -q "^CONFIG_USBSERIAL=y" "$CONFIG_FILE"; then
    echo "✅ CONFIG_USBSERIAL=y is set"
elif grep -q "^CONFIG_USB=y" "$CONFIG_FILE"; then
    echo "⚠️  CONFIG_USB=y is set, but CONFIG_USBSERIAL is not explicitly set"
    echo "   This might be auto-selected by STM32 Kconfig"
    echo "   Checking STM32 USB config..."
    if grep -q "CONFIG_STM32_USB" "$CONFIG_FILE"; then
        echo "   → STM32 USB config found"
    fi
else
    echo "❌ CONFIG_USBSERIAL is not set"
    echo "   This is required for USB serial communication"
fi

echo ""
echo "Checking if usb_cdc.c exists..."
if [ -f "~/klipper/src/generic/usb_cdc.c" ] || [ -f "src/generic/usb_cdc.c" ]; then
    echo "✅ usb_cdc.c exists"
else
    echo "❌ usb_cdc.c not found!"
fi

