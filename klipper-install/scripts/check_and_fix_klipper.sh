#!/bin/bash
# Check Klipper status and fix if needed

echo "=== Checking Klipper Status ==="
sudo systemctl status klipper --no-pager | head -15

echo ""
echo "=== Checking if API socket exists ==="
if [ -S /tmp/klippy_uds ]; then
    echo "✓ Socket exists"
    ls -la /tmp/klippy_uds
else
    echo "✗ Socket NOT found"
    echo "Klipper API server not running"
fi

echo ""
echo "=== Checking recent logs for errors ==="
tail -50 /tmp/klippy.log 2>/dev/null | grep -i "error\|failed\|config\|start" | tail -10

echo ""
echo "=== Checking if config loaded ==="
if tail -100 /tmp/klippy.log 2>/dev/null | grep -q "Config file"; then
    echo "✓ Config file loaded"
    tail -100 /tmp/klippy.log | grep "Config file" | tail -1
else
    echo "⚠️  Config file status unclear"
fi

echo ""
echo "=== Restarting Klipper ==="
sudo systemctl restart klipper
sleep 3

echo ""
echo "=== Checking status after restart ==="
sudo systemctl status klipper --no-pager | head -10

echo ""
echo "=== Waiting for socket... ==="
for i in {1..10}; do
    if [ -S /tmp/klippy_uds ]; then
        echo "✓ Socket appeared after $i seconds"
        break
    fi
    sleep 1
done

if [ ! -S /tmp/klippy_uds ]; then
    echo "✗ Socket still not found after 10 seconds"
    echo ""
    echo "Troubleshooting:"
    echo "1. Check config for errors:"
    echo "   tail -100 /tmp/klippy.log | grep -i error"
    echo ""
    echo "2. Check if klippy process is running:"
    echo "   ps aux | grep klippy"
    echo ""
    echo "3. Try starting manually:"
    echo "   sudo systemctl stop klipper"
    echo "   cd ~/klipper"
    echo "   ./klippy-env/bin/python3 klippy/klippy.py ~/printer.cfg -l /tmp/klippy.log --api-server /tmp/klippy_uds"
fi

