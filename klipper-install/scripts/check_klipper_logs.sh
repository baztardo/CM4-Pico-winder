#!/bin/bash
# Check Klipper logs for errors or initialization status

echo "=== Checking Klipper Log File ==="
if [ -f /tmp/klippy.log ]; then
    echo "✓ Log file exists: /tmp/klippy.log"
    echo ""
    echo "Last 50 lines:"
    tail -50 /tmp/klippy.log
else
    echo "❌ Log file not found: /tmp/klippy.log"
    echo "Checking if Klipper is writing to a different location..."
fi

echo ""
echo "=== Checking systemd logs ==="
sudo journalctl -u klipper -n 30 --no-pager

echo ""
echo "=== Checking if MCU is connected ==="
if grep -q "mcu 'mcu': Connected" /tmp/klippy.log 2>/dev/null; then
    echo "✓ MCU connection found in logs"
elif grep -q "mcu 'mcu': Shutdown" /tmp/klippy.log 2>/dev/null; then
    echo "❌ MCU shutdown detected!"
    echo "Recent shutdown messages:"
    grep -i "shutdown" /tmp/klippy.log | tail -5
elif grep -q "Unable to open serial port" /tmp/klippy.log 2>/dev/null; then
    echo "❌ Serial port error!"
    grep -i "serial port" /tmp/klippy.log | tail -5
else
    echo "⚠️  MCU connection status unclear from logs"
fi

echo ""
echo "=== Checking for config errors ==="
if grep -qi "error\|failed\|exception" /tmp/klippy.log 2>/dev/null | tail -10; then
    echo "Recent errors:"
    grep -i "error\|failed\|exception" /tmp/klippy.log | tail -10
else
    echo "✓ No obvious errors in recent logs"
fi

