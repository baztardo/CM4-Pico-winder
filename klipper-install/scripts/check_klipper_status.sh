#!/bin/bash
# Quick check of Klipper status and logs

echo "=== Klipper Process Check ==="
ps aux | grep -E "klippy|python.*klippy" | grep -v grep

echo ""
echo "=== Recent Klipper Logs (last 30 lines) ==="
sudo journalctl -u klipper -n 30 --no-pager

echo ""
echo "=== Checking printer.cfg ==="
if [ -f ~/printer.cfg ]; then
    echo "✓ printer.cfg exists"
    echo "  MCU serial: $(grep 'serial:' ~/printer.cfg | head -1)"
else
    echo "❌ printer.cfg not found at ~/printer.cfg"
fi

echo ""
echo "=== Checking API Socket ==="
if [ -S /tmp/klippy_uds ]; then
    echo "✓ Socket exists"
    ls -la /tmp/klippy_uds
    echo ""
    echo "Testing socket connection..."
    timeout 2 python3 <<PYTHON
import socket
import sys
try:
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.settimeout(1)
    sock.connect('/tmp/klippy_uds')
    print("✓ Socket connection successful")
    sock.close()
except Exception as e:
    print(f"❌ Socket connection failed: {e}")
    sys.exit(1)
PYTHON
else
    echo "❌ Socket not found"
fi

