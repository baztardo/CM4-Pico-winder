#!/bin/bash
# Test MCU Detection Script
# Run this on CM4 to see what USB devices/serial ports are detected

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}MCU Detection Test${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${GREEN}1. Checking USB devices (lsusb)...${NC}"
echo "---"
lsusb 2>/dev/null | head -20
echo ""

echo -e "${GREEN}2. Checking for STM32 (Klipper USB ID: 1d50:614e)...${NC}"
if lsusb 2>/dev/null | grep -q "1d50:614e"; then
    echo -e "  ${GREEN}✓ Found STM32 device${NC}"
    lsusb 2>/dev/null | grep "1d50:614e"
else
    echo -e "  ${YELLOW}✗ No STM32 device found${NC}"
fi
echo ""

echo -e "${GREEN}3. Checking for RP2040 (Raspberry Pi USB ID: 2e8a)...${NC}"
if lsusb 2>/dev/null | grep -q "2e8a"; then
    echo -e "  ${GREEN}✓ Found RP2040 device${NC}"
    lsusb 2>/dev/null | grep "2e8a"
else
    echo -e "  ${YELLOW}✗ No RP2040 device found${NC}"
fi
echo ""

echo -e "${GREEN}4. Checking serial ports (/dev/serial/by-id/)...${NC}"
if [ -d "/dev/serial/by-id" ]; then
    echo "---"
    ls -la /dev/serial/by-id/ 2>/dev/null | grep -v "^total" | grep -v "^d"
    echo ""
    
    echo -e "${GREEN}5. Checking for STM32 in serial port names...${NC}"
    if ls -la /dev/serial/by-id/ 2>/dev/null | grep -qi "stm32"; then
        echo -e "  ${GREEN}✓ Found STM32 in serial port${NC}"
        ls -la /dev/serial/by-id/ 2>/dev/null | grep -i "stm32"
    else
        echo -e "  ${YELLOW}✗ No STM32 in serial port names${NC}"
    fi
    echo ""
    
    echo -e "${GREEN}6. Checking for RP2040/Pico in serial port names...${NC}"
    if ls -la /dev/serial/by-id/ 2>/dev/null | grep -qi "rp2040\|pico"; then
        echo -e "  ${GREEN}✓ Found RP2040/Pico in serial port${NC}"
        ls -la /dev/serial/by-id/ 2>/dev/null | grep -iE "rp2040|pico"
    else
        echo -e "  ${YELLOW}✗ No RP2040/Pico in serial port names${NC}"
    fi
    echo ""
    
    echo -e "${GREEN}7. Checking for 'Klipper' in serial port names...${NC}"
    if ls -la /dev/serial/by-id/ 2>/dev/null | grep -qi "Klipper"; then
        echo -e "  ${GREEN}✓ Found 'Klipper' in serial port${NC}"
        ls -la /dev/serial/by-id/ 2>/dev/null | grep -i "Klipper"
    else
        echo -e "  ${YELLOW}✗ No 'Klipper' in serial port names${NC}"
    fi
else
    echo -e "  ${YELLOW}✗ /dev/serial/by-id/ directory not found${NC}"
fi
echo ""

echo -e "${GREEN}8. Detection Result:${NC}"
echo "---"
# Simulate the detection function
DETECTED_MCU=""
if lsusb 2>/dev/null | grep -q "1d50:614e"; then
    if ls -la /dev/serial/by-id/ 2>/dev/null | grep -qi "stm32g0"; then
        DETECTED_MCU="STM32G0B1 (from USB ID + serial port)"
    else
        DETECTED_MCU="STM32G0B1 (from USB ID, generic STM32)"
    fi
elif lsusb 2>/dev/null | grep -q "2e8a"; then
    DETECTED_MCU="RP2040 (from USB ID)"
elif ls -la /dev/serial/by-id/ 2>/dev/null | grep -qi "rp2040\|pico"; then
    DETECTED_MCU="RP2040 (from serial port name)"
elif ls -la /dev/serial/by-id/ 2>/dev/null | grep -qi "Klipper"; then
    DETECTED_MCU="STM32G0B1 (from Klipper serial port, default)"
else
    DETECTED_MCU="STM32G0B1 (default fallback - no detection)"
fi

echo "Detected MCU: $DETECTED_MCU"
echo ""

echo -e "${BLUE}========================================${NC}"
echo "Test complete!"
echo ""
echo "To use this detection in setup:"
echo "  ./SETUP_CM4_COMPLETE.sh --mcu=AUTO"
echo ""

