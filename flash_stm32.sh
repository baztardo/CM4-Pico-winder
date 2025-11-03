#!/bin/bash
# Flash STM32 CNC Winder Firmware to CLEO Board

echo "🔌 STM32 CNC Winder Firmware Flasher"
echo "===================================="

# Check if firmware exists
if [ ! -f "out/klipper.elf" ]; then
    echo "❌ Error: out/klipper.elf not found!"
    echo "   Run: ./build.sh stm32f401"
    exit 1
fi

echo "📁 Firmware found: out/klipper.elf ($(stat -f%z out/klipper.elf) bytes)"
echo ""

# Check for dfu-util
if ! command -v dfu-util &> /dev/null; then
    echo "⚠️  dfu-util not found. Installing..."
    if command -v brew &> /dev/null; then
        brew install dfu-util
    else
        echo "❌ Please install dfu-util manually:"
        echo "   brew install dfu-util"
        exit 1
    fi
fi

echo "🔍 Checking for STM32 DFU device..."
if lsusb 2>/dev/null | grep -i "stm32\|dfu" > /dev/null; then
    echo "✅ STM32 DFU device found!"
else
    echo "⚠️  STM32 DFU device not found."
    echo ""
    echo "📋 To enter DFU mode:"
    echo "   1. Connect STM32 board via USB"
    echo "   2. Press and hold BOOT0 button"
    echo "   3. Press and release RESET button (while holding BOOT0)"
    echo "   4. Release BOOT0 button"
    echo "   5. Run this script again"
    exit 1
fi

echo ""
echo "🚀 Flashing firmware to STM32F401RE..."
echo "   Command: dfu-util -a 0 -s 0x08000000:leave -D out/klipper.elf"
echo ""

if dfu-util -a 0 -s 0x08000000:leave -D out/klipper.elf; then
    echo ""
    echo "✅ FLASH SUCCESSFUL!"
    echo ""
    echo "🎯 Next steps:"
    echo "   1. Press RESET button on STM32 board"
    echo "   2. Connect STM32 to CM4/CB1:"
    echo "      • PA9 (TX) → CM4 RX"
    echo "      • PA10 (RX) → CM4 TX"
    echo "      • Ground → Ground"
    echo "   3. Run on CM4: ./setup_cnc_winder.sh"
    echo "   4. Open Mainsail web interface"
    echo ""
    echo "Your CNC winder is ready! 🎉"
else
    echo ""
    echo "❌ FLASH FAILED!"
    echo "   Check USB connection and DFU mode"
    exit 1
fi
