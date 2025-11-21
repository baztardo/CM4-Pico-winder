#!/bin/bash
# Comprehensive traverse (stepper_y) diagnostic

python3 <<PYTHON_DIAG
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
    sock.settimeout(5)
    sock.connect('/tmp/klippy_uds')
    
    print("=== Traverse (stepper_y) Diagnostic ===\n")
    
    # 1. Check stepper enable status
    print("1. Checking stepper_y enable status...")
    send_command(sock, "printer.objects.query", {"objects": {"steppers": None}})
    response = read_response(sock)
    if response and 'result' in response:
        steppers = response['result'].get('status', {}).get('steppers', {})
        y_enabled = steppers.get("stepper_y", False)
        print(f"   stepper_y enabled: {y_enabled}")
        if not y_enabled:
            print("   ⚠️  Stepper is DISABLED - enabling now...")
            send_command(sock, "printer.gcode.script", {"script": "SET_STEPPER_ENABLE STEPPER=stepper_y ENABLE=1"})
            response = read_response(sock)
            if response and 'error' not in response:
                print("   ✓ Enabled stepper_y")
            else:
                print(f"   ❌ Failed to enable: {response}")
    else:
        print("   ⚠️  Could not query stepper status")
    
    # 2. Check endstop status
    print("\n2. Checking endstop status...")
    send_command(sock, "printer.gcode.script", {"script": "QUERY_ENDSTOPS"})
    response = read_response(sock)
    if response:
        if 'error' in response:
            print(f"   ⚠️  Error: {response['error']}")
        else:
            print("   ✓ QUERY_ENDSTOPS command sent")
    
    # 3. Check TMC2209 status
    print("\n3. Checking TMC2209 (stepper_y) status...")
    send_command(sock, "printer.gcode.script", {"script": "QUERY_TMC stepper_y"})
    response = read_response(sock)
    if response:
        if 'error' in response:
            print(f"   ⚠️  TMC2209 query error: {response['error']}")
            print("   → This might mean TMC2209 is not configured or not communicating")
        else:
            print("   ✓ TMC2209 query sent")
    
    # 4. Try to read endstop pin directly
    print("\n4. Checking endstop pin state...")
    send_command(sock, "printer.gcode.script", {"script": "SET_PIN PIN=endstop_y VALUE=0"})
    response = read_response(sock)
    if response:
        print(f"   Response: {response}")
    
    # 5. Check current position
    print("\n5. Checking current position...")
    send_command(sock, "printer.objects.query", {"objects": {"toolhead": None}})
    response = read_response(sock)
    if response and 'result' in response:
        toolhead = response['result'].get('status', {}).get('toolhead', {})
        position = toolhead.get('position', [])
        if position:
            print(f"   Current position: X={position[0]:.2f}, Y={position[1]:.2f}, Z={position[2]:.2f}")
    
    # 6. Try a small movement (if stepper is enabled)
    print("\n6. Testing small movement...")
    send_command(sock, "printer.gcode.script", {"script": "G91\nG1 Y1 F100\nG90"})
    response = read_response(sock)
    if response:
        if 'error' in response:
            print(f"   ❌ Movement error: {response['error']}")
        else:
            print("   ✓ Movement command sent")
    
    sock.close()
    
    print("\n=== Diagnostic Complete ===")
    print("\nTroubleshooting steps:")
    print("1. Check endstop wiring - LED should turn ON when pressed")
    print("2. Try inverting endstop: endstop_pin: ^PF3")
    print("3. Check TMC2209 UART wiring (PF13 pin)")
    print("4. Verify stepper enable pin (PB3)")
    print("5. Check stepper power supply")
    
except Exception as e:
    print(f"❌ Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

PYTHON_DIAG

