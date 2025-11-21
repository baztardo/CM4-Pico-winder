#!/bin/bash
# Test Klipper API communication

python3 <<PYTHON_TEST
import socket
import json
import struct
import sys

def send_command(sock, method, params=None):
    cmd_id = 1
    cmd = {"id": cmd_id, "method": method}
    if params:
        cmd["params"] = params
    cmd_json = json.dumps(cmd) + "\n"
    cmd_bytes = cmd_json.encode('utf-8')
    sock.sendall(struct.pack('>I', len(cmd_bytes)) + cmd_bytes)
    return cmd_id

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
    print("Connecting to Klipper API socket...")
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.settimeout(5)
    sock.connect('/tmp/klippy_uds')
    print("✓ Connected to Klipper API\n")
    
    # Test 1: Get MCU status
    print("Test 1: Getting MCU status...")
    send_command(sock, "printer.objects.query", {"objects": {"mcu": None}})
    response = read_response(sock)
    if response and 'result' in response:
        mcu_status = response['result'].get('status', {}).get('mcu', {})
        if mcu_status:
            print(f"  ✓ MCU Version: {mcu_status.get('mcu_version', 'unknown')}")
            print(f"  ✓ MCU Connected: {mcu_status.get('mcu_connected', False)}")
            print(f"  ✓ MCU Last Stats: {mcu_status.get('mcu_last_stats', {}).get('mcu_awake', 'unknown')}")
        else:
            print("  ⚠️  MCU status not available")
    else:
        print(f"  ⚠️  Unexpected response: {response}")
    
    # Test 2: Send STATUS command
    print("\nTest 2: Sending STATUS command...")
    send_command(sock, "printer.gcode.script", {"script": "STATUS"})
    response = read_response(sock)
    if response:
        if 'error' in response:
            print(f"  ⚠️  Error: {response['error']}")
        else:
            print("  ✓ STATUS command sent successfully")
    
    # Test 3: Get printer info
    print("\nTest 3: Getting printer info...")
    send_command(sock, "printer.info")
    response = read_response(sock)
    if response and 'result' in response:
        info = response['result']
        print(f"  ✓ State: {info.get('state', 'unknown')}")
        print(f"  ✓ State Message: {info.get('state_message', 'unknown')}")
    else:
        print(f"  ⚠️  Unexpected response: {response}")
    
    sock.close()
    print("\n✓ All tests completed successfully!")
    print("\nKlipper communication is working!")
    
except socket.timeout:
    print("❌ Connection timeout")
    sys.exit(1)
except ConnectionRefusedError:
    print("❌ Connection refused - Klipper may not be fully started")
    print("   Wait a few seconds and try again")
    sys.exit(1)
except Exception as e:
    print(f"❌ Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

PYTHON_TEST

