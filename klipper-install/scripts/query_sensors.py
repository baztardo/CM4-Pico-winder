#!/usr/bin/env python3
"""
Query Winder Sensors - Shows real-time sensor data
"""
import socket
import json
import sys
import time

SOCKET_PATH = "/tmp/klippy_uds"

def send_gcode(sock, command):
    """Send a G-code command and return response"""
    data = json.dumps({"id": int(time.time() * 1000), 
                      "method": "gcode/script",
                      "params": {"script": command}})
    sock.sendall((data + "\x03").encode())
    
    # Read response
    response = b""
    while True:
        chunk = sock.recv(4096)
        if not chunk:
            break
        response += chunk
        if b"\x03" in response:
            break
    
    return response.decode().strip("\x03")

def query_sensor(command, sensor_name):
    """Query a sensor and return parsed data"""
    try:
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.connect(SOCKET_PATH)
        sock.settimeout(2.0)
        
        # Send query command
        send_gcode(sock, command)
        
        # Small delay for response
        time.sleep(0.1)
        
        sock.close()
        return True
    except Exception as e:
        print(f"Error querying {sensor_name}: {e}")
        return False

def main():
    print("=" * 60)
    print("WINDER SENSOR STATUS")
    print("=" * 60)
    
    # Query all sensors
    sensors = [
        ("QUERY_ANGLE_SENSOR", "Angle Sensor"),
        ("QUERY_SPINDLE_HALL", "Spindle Hall"),
        ("QUERY_WINDER", "Winder Control"),
    ]
    
    for cmd, name in sensors:
        print(f"\n{name}:")
        print("-" * 40)
        if query_sensor(cmd, name):
            print(f"✓ Query sent - check Klipper console for response")
        else:
            print(f"✗ Query failed")
    
    print("\n" + "=" * 60)
    print("Note: Responses appear in Klipper console/Mainsail")
    print("To see in terminal, use: tail -f /tmp/klippy.log | grep -E 'Angle|Hall|Winder'")
    print("=" * 60)

if __name__ == "__main__":
    main()


