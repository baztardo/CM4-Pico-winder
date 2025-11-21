#!/bin/bash
# Quick script to check .config for unwanted features

CONFIG_FILE="${1:-~/klipper/.config}"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file not found: $CONFIG_FILE"
    exit 1
fi

echo "Checking $CONFIG_FILE for unwanted features..."
echo ""

# Check for features that should be disabled
UNWANTED=(
    "CONFIG_WANT_NEOPIXEL"
    "CONFIG_WANT_ST7920"
    "CONFIG_WANT_HD44780"
    "CONFIG_WANT_THERMOCOUPLE"
    "CONFIG_WANT_ADXL345"
    "CONFIG_WANT_LIS2DW"
    "CONFIG_WANT_MPU9250"
    "CONFIG_WANT_ICM20948"
    "CONFIG_WANT_HX71X"
    "CONFIG_WANT_ADS1220"
    "CONFIG_WANT_LDC1612"
)

FOUND=0
for feature in "${UNWANTED[@]}"; do
    if grep -q "^${feature}=y" "$CONFIG_FILE"; then
        echo "❌ $feature is ENABLED (should be disabled)"
        FOUND=1
    fi
done

if [ $FOUND -eq 0 ]; then
    echo "✅ All unwanted features are disabled"
else
    echo ""
    echo "⚠️  Some unwanted features are enabled!"
    echo "   Run: cp ~/klipper-install/.config.winder-minimal ~/klipper/.config"
fi

