#!/usr/bin/env python3
# Get actual error message from movement command

import socket
import json
import struct
import sys

def send_command(sock, method, params=None):
    cmd = {"id": 1, "method": method}
    if params:
        cmd["params"] = params
    cmd_json = json.dumps(cmd) + "\n"
    cmd_bytes = cmd_json.encode('utf-8')
    sock.sendall(struct.pack('>I', len(cmd_bytes)) + cmd_bytes)

def read_response(sock):
    size_bytes = sock.recv(4)
    if len(size_bytes) < 4:
        return None
    size = struct.unpack('>I', size_bytes)[0]
    data = b''
    while len(data) < size:
        chunk = sock.recv(size - len(data))
        if not chunk:
            return None
        data += chunk
    return json.loads(data.decode('utf-8'))

try:
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.settimeout(10)
    sock.connect('/tmp/klippy_uds')
    
    print("Testing movement command...")
    send_command(sock, "printer.gcode.script", {"script": "G1 Y1 F100"})
    response = read_response(sock)
    
    print(f"\nFull API Response:")
    print(json.dumps(response, indent=2))
    
    if response:
        if 'error' in response:
            print(f"\n❌ ERROR: {response['error']}")
        elif 'result' in response:
            print(f"\n✓ Result: {response['result']}")
        else:
            print(f"\n⚠️  Unexpected response format")
    
    sock.close()
    
except Exception as e:
    print(f"❌ Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

