#!/bin/bash
# Check if Klipper is actually ready to accept commands

echo "=== Checking Klipper Status ==="
tail -30 /tmp/klippy.log | tail -10

echo ""
echo "=== Checking for 'Ready' message ==="
if tail -100 /tmp/klippy.log | grep -qi "ready\|started\|klippy.*start"; then
    echo "✓ Klipper appears to be ready"
else
    echo "⚠️  Klipper may not be fully started"
    echo "Recent log entries:"
    tail -20 /tmp/klippy.log
fi

echo ""
echo "=== Testing simple command ==="
python3 <<PYTHON
import socket
import json
import struct
import sys

try:
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.settimeout(3)
    sock.connect('/tmp/klippy_uds')
    
    # Try a simple command
    cmd = {"id": 1, "method": "printer.info"}
    cmd_json = json.dumps(cmd) + "\n"
    cmd_bytes = cmd_json.encode('utf-8')
    sock.sendall(struct.pack('>I', len(cmd_bytes)) + cmd_bytes)
    
    # Wait for response
    size_bytes = sock.recv(4)
    if len(size_bytes) >= 4:
        size = struct.unpack('>I', size_bytes)[0]
        data = sock.recv(size)
        response = json.loads(data.decode('utf-8'))
        if 'result' in response:
            print("✓ Klipper is responding to commands")
            print(f"  State: {response['result'].get('state', 'unknown')}")
        else:
            print(f"⚠️  Unexpected response: {response}")
    else:
        print("✗ No response from Klipper")
    
    sock.close()
except Exception as e:
    print(f"✗ Error: {e}")
    sys.exit(1)
PYTHON

