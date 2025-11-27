#!/usr/bin/env python3
"""
Query hardware counters and display their status
"""
import socket
import json
import time
import sys

def send_and_receive(sock, method, params=None):
    """Send a request and get the response"""
    request = {
        "id": int(time.time() * 1000),
        "method": method,
        "params": params or {}
    }
    
    # Send request
    sock.sendall((json.dumps(request) + "\x03").encode())
    
    # Read response
    response = b""
    while True:
        chunk = sock.recv(4096)
        if not chunk:
            break
        response += chunk
        if b"\x03" in response:
            break
    
    # Parse response
    try:
        data = json.loads(response.decode().strip("\x03"))
        return data
    except:
        return None

def main():
    # Connect to Klipper Unix socket
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        sock.connect("/tmp/klippy_uds")
    except Exception as e:
        print(f"Error connecting to Klipper: {e}")
        return 1
    
    # Subscribe to G-code responses
    response = send_and_receive(sock, "gcode/subscribe_output", {"response_template": {}})
    
    # Query spindle hall
    print("=== Querying Spindle Hall ===")
    send_and_receive(sock, "gcode/script", {"script": "QUERY_HW_COUNTER COUNTER=spindle_hall"})
    time.sleep(0.5)
    
    # Query BLDC hall
    print("\n=== Querying BLDC Hall ===")
    send_and_receive(sock, "gcode/script", {"script": "QUERY_HW_COUNTER COUNTER=bldc_hall"})
    time.sleep(0.5)
    
    # Read any pending messages
    sock.setblocking(False)
    try:
        while True:
            chunk = sock.recv(4096)
            if not chunk:
                break
            # Try to parse messages
            for msg in chunk.decode().split("\x03"):
                if msg.strip():
                    try:
                        data = json.loads(msg)
                        if "params" in data:
                            # This is a notification
                            if isinstance(data["params"], list):
                                for item in data["params"]:
                                    print(item)
                            else:
                                print(data["params"])
                    except:
                        pass
    except BlockingIOError:
        pass
    
    sock.close()
    return 0

if __name__ == "__main__":
    sys.exit(main())

