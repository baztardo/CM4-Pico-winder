#!/bin/bash
# Test Klipper communication with MCU
# Checks serial port, Klipper service, and basic commands

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Klipper Communication Test ===${NC}"
echo ""

# Step 1: Check if MCU serial port exists
echo -e "${BLUE}Step 1: Checking MCU serial port...${NC}"
SERIAL_PORT=$(ls /dev/serial/by-id/usb-Klipper_* 2>/dev/null | head -1)
if [ -n "$SERIAL_PORT" ]; then
    echo -e "${GREEN}✓ MCU found: $SERIAL_PORT${NC}"
    ls -la "$SERIAL_PORT"
else
    echo -e "${RED}❌ MCU serial port not found${NC}"
    echo "   Check USB connection and power"
    echo "   Try: ls -la /dev/serial/by-id/"
    exit 1
fi

echo ""

# Step 2: Check Klipper service status
echo -e "${BLUE}Step 2: Checking Klipper service...${NC}"
if systemctl is-active --quiet klipper; then
    echo -e "${GREEN}✓ Klipper service is running${NC}"
    systemctl status klipper --no-pager -l | head -10
else
    echo -e "${YELLOW}⚠️  Klipper service is not running${NC}"
    echo "   Starting Klipper service..."
    sudo systemctl start klipper
    sleep 2
    if systemctl is-active --quiet klipper; then
        echo -e "${GREEN}✓ Klipper service started${NC}"
    else
        echo -e "${RED}❌ Failed to start Klipper service${NC}"
        echo "   Check logs: sudo journalctl -u klipper -n 50"
        exit 1
    fi
fi

echo ""

# Step 3: Check API server socket
echo -e "${BLUE}Step 3: Checking API server socket...${NC}"
if [ -S /tmp/klippy_uds ]; then
    echo -e "${GREEN}✓ API server socket exists: /tmp/klippy_uds${NC}"
else
    echo -e "${YELLOW}⚠️  API server socket not found${NC}"
    echo "   API server may not be enabled"
    echo "   Check: grep --api-server /etc/default/klipper"
fi

echo ""

# Step 4: Test basic Klipper commands via API socket
if [ -S /tmp/klippy_uds ]; then
    echo -e "${BLUE}Step 4: Testing Klipper commands via API socket...${NC}"
    
    # Test STATUS command
    echo "  Testing STATUS command..."
    python3 <<PYTHON_TEST
import socket
import json
import struct

def send_command(sock, cmd):
    cmd_bytes = cmd.encode('utf-8') + b'\n'
    sock.sendall(struct.pack('>I', len(cmd_bytes)) + cmd_bytes)

def read_response(sock):
    size_bytes = sock.recv(4)
    if len(size_bytes) < 4:
        return None
    size = struct.unpack('>I', size_bytes)[0]
    data = sock.recv(size)
    return json.loads(data.decode('utf-8'))

try:
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect('/tmp/klippy_uds')
    
    # Test STATUS
    send_command(sock, '{"id": 1, "method": "printer.gcode.script", "params": {"script": "STATUS"}}')
    response = read_response(sock)
    if response:
        print("  ✓ STATUS command sent")
        if 'result' in response:
            print("  ✓ Received response")
        else:
            print("  ⚠️  Response:", response)
    
    # Test GET_STATUS
    send_command(sock, '{"id": 2, "method": "printer.objects.query", "params": {"objects": {"mcu": null}}}')
    response = read_response(sock)
    if response and 'result' in response:
        mcu_status = response['result'].get('status', {}).get('mcu', {})
        if mcu_status:
            print("  ✓ MCU status retrieved")
            print(f"    MCU version: {mcu_status.get('mcu_version', 'unknown')}")
            print(f"    MCU connected: {mcu_status.get('mcu_connected', False)}")
        else:
            print("  ⚠️  MCU status not available")
    
    sock.close()
    print("  ✓ API socket communication successful")
except Exception as e:
    print(f"  ❌ API socket test failed: {e}")
PYTHON_TEST
else
    echo -e "${YELLOW}Step 4: Skipping API socket test (socket not available)${NC}"
fi

echo ""

# Step 5: Check Klipper logs for errors
echo -e "${BLUE}Step 5: Checking recent Klipper logs...${NC}"
RECENT_LOGS=$(sudo journalctl -u klipper -n 20 --no-pager 2>/dev/null)
if echo "$RECENT_LOGS" | grep -qi "mcu 'mcu' shutdown\|error\|failed"; then
    echo -e "${RED}⚠️  Errors found in logs:${NC}"
    echo "$RECENT_LOGS" | grep -i "error\|failed\|shutdown" | tail -5
else
    echo -e "${GREEN}✓ No recent errors in logs${NC}"
fi

echo ""

# Step 6: Test direct serial communication (if API not available)
if [ ! -S /tmp/klippy_uds ]; then
    echo -e "${BLUE}Step 6: Testing direct serial communication...${NC}"
    echo "  (This requires stopping Klipper service temporarily)"
    read -p "  Stop Klipper service to test serial? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo systemctl stop klipper
        sleep 1
        echo "  Testing serial port..."
        timeout 2 cat "$SERIAL_PORT" > /dev/null 2>&1 && echo -e "${GREEN}✓ Serial port is readable${NC}" || echo -e "${YELLOW}⚠️  Serial port test inconclusive${NC}"
        sudo systemctl start klipper
    fi
fi

echo ""
echo -e "${GREEN}=== Test Complete ===${NC}"
echo ""
echo "Next steps:"
echo "  1. Check printer.cfg: ~/printer.cfg"
echo "  2. Test G-code commands: echo 'STATUS' | nc -U /tmp/klippy_uds"
echo "  3. View logs: sudo journalctl -u klipper -f"

