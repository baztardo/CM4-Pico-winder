#!/bin/bash
# Force fix .config - disable unwanted features and ensure USBSERIAL is set

KLIPPER_DIR="${1:-$HOME/klipper}"

if [ ! -d "$KLIPPER_DIR" ]; then
    echo "Error: Klipper directory not found: $KLIPPER_DIR"
    exit 1
fi

cd "$KLIPPER_DIR"

echo "Force fixing .config..."

# Disable ALL unwanted features (that have been removed from src/)
# These files were removed by cleanup script, so they must be disabled
sed -i 's/^CONFIG_WANT_NEOPIXEL=y/# CONFIG_WANT_NEOPIXEL is not set/' .config
sed -i 's/^CONFIG_WANT_ST7920=y/# CONFIG_WANT_ST7920 is not set/' .config
sed -i 's/^CONFIG_WANT_HD44780=y/# CONFIG_WANT_HD44780 is not set/' .config
sed -i 's/^CONFIG_WANT_THERMOCOUPLE=y/# CONFIG_WANT_THERMOCOUPLE is not set/' .config
sed -i 's/^CONFIG_WANT_ADXL345=y/# CONFIG_WANT_ADXL345 is not set/' .config
sed -i 's/^CONFIG_WANT_LIS2DW=y/# CONFIG_WANT_LIS2DW is not set/' .config
sed -i 's/^CONFIG_WANT_MPU9250=y/# CONFIG_WANT_MPU9250 is not set/' .config
sed -i 's/^CONFIG_WANT_ICM20948=y/# CONFIG_WANT_ICM20948 is not set/' .config
sed -i 's/^CONFIG_WANT_HX71X=y/# CONFIG_WANT_HX71X is not set/' .config
sed -i 's/^CONFIG_WANT_ADS1220=y/# CONFIG_WANT_ADS1220 is not set/' .config
sed -i 's/^CONFIG_WANT_LDC1612=y/# CONFIG_WANT_LDC1612 is not set/' .config
sed -i 's/^CONFIG_WANT_LOAD_CELL_PROBE=y/# CONFIG_WANT_LOAD_CELL_PROBE is not set/' .config
sed -i 's/^CONFIG_NEED_SOS_FILTER=y/# CONFIG_NEED_SOS_FILTER is not set/' .config

# Ensure USBSERIAL is set if STM32 USB is configured
if grep -q "^CONFIG_STM32_USB_PA11_PA12=y" .config && ! grep -q "^CONFIG_USBSERIAL=y" .config; then
    echo "CONFIG_USBSERIAL=y" >> .config
    echo "✓ Added CONFIG_USBSERIAL=y"
fi

# Run olddefconfig to validate
echo ""
echo "Running make olddefconfig..."
make olddefconfig > /dev/null 2>&1

# Check if any removed features were re-enabled and disable them again
RE_ENABLED=()
for feature in NEOPIXEL ST7920 HD44780 THERMOCOUPLE ADXL345 LIS2DW MPU9250 ICM20948 HX71X ADS1220 LDC1612 LOAD_CELL_PROBE SOS_FILTER; do
    if grep -q "^CONFIG_WANT_${feature}=y" .config || grep -q "^CONFIG_NEED_${feature}=y" .config; then
        RE_ENABLED+=("$feature")
        if [[ "$feature" == "SOS_FILTER" ]]; then
            sed -i 's/^CONFIG_NEED_SOS_FILTER=y/# CONFIG_NEED_SOS_FILTER is not set/' .config
        else
            sed -i "s/^CONFIG_WANT_${feature}=y/# CONFIG_WANT_${feature} is not set/" .config
        fi
    fi
done

if [ ${#RE_ENABLED[@]} -gt 0 ]; then
    echo "⚠️  Re-disabled features that were re-enabled: ${RE_ENABLED[*]}"
fi

echo ""
echo "Final config check:"
echo "  CONFIG_WANT_NEOPIXEL: $(grep '^CONFIG_WANT_NEOPIXEL' .config || echo 'not set')"
echo "  CONFIG_WANT_ST7920: $(grep '^CONFIG_WANT_ST7920' .config || echo 'not set')"
echo "  CONFIG_USBSERIAL: $(grep '^CONFIG_USBSERIAL' .config || echo 'not set')"

echo ""
echo "✓ Config fixed. Now run: make clean && make"

