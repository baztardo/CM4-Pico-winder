#!/bin/bash
# Check why movement is failing

echo "=== Checking Klipper logs for movement errors ==="
tail -50 /tmp/klippy.log | grep -i "error\|failed\|stepper\|endstop\|y" | tail -20

echo ""
echo "=== Checking endstop status ==="
python3 <<PYTHON
import socket
import json
import struct

sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
sock.settimeout(5)
sock.connect('/tmp/klippy_uds')

# Query endstops
cmd = json.dumps({"id": 1, "method": "printer.gcode.script", "params": {"script": "QUERY_ENDSTOPS"}}) + "\n"
cmd_bytes = cmd.encode('utf-8')
sock.sendall(struct.pack('>I', len(cmd_bytes)) + cmd_bytes)

# Read response
size_bytes = sock.recv(4)
if len(size_bytes) >= 4:
    size = struct.unpack('>I', size_bytes)[0]
    data = sock.recv(size)
    response = json.loads(data.decode('utf-8'))
    print(f"QUERY_ENDSTOPS response: {response}")

sock.close()
PYTHON

echo ""
echo "=== Trying movement with error capture ==="
python3 ~/klipper/scripts/klipper_interface.py -g "G1 Y1 F100" 2>&1

