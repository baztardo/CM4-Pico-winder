#!/usr/bin/env python3
"""
Calibration script to move stepper exactly 10mm
Measure the actual movement and we'll calculate the correct rotation_distance
"""
import socket
import json
import sys
import time

def send_command(sock, command):
    """Send G-code command and wait for response"""
    cmd = {
        'id': 1,
        'method': 'gcode/script',
        'params': {'script': command}
    }
    sock.send(json.dumps(cmd).encode() + b'\x03')
    
    sock.settimeout(30.0)
    try:
        # Read response in chunks until we get complete JSON
        response_data = b''
        while True:
            chunk = sock.recv(4096)
            if not chunk:
                break
            response_data += chunk
            # Check if we have a complete JSON response (ends with } or has \x03)
            if b'\x03' in response_data or (response_data.count(b'{') > 0 and response_data.count(b'{') == response_data.count(b'}')):
                break
        
        response_str = response_data.decode('utf-8', errors='ignore').strip()
        # Remove any trailing \x03 or other control chars
        response_str = response_str.rstrip('\x03').strip()
        
        if not response_str:
            return {'error': 'Empty response'}
        
        return json.loads(response_str)
    except socket.timeout:
        return {'error': {'message': 'Timeout waiting for response'}}
    except json.JSONDecodeError as e:
        return {'error': {'message': f'Invalid JSON: {str(e)[:50]}'}}
    except Exception as e:
        return {'error': {'message': f'Error: {str(e)[:50]}'}}

def main():
    socket_path = '/tmp/klippy_uds'
    if len(sys.argv) > 1:
        socket_path = sys.argv[1]
    
    print("=== Rotation Distance Calibration ===")
    print("This will move the traverse 10mm")
    print("Measure the ACTUAL movement with your caliper")
    print("")
    
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        sock.connect(socket_path)
        print("✅ Connected to Klipper")
        
        # Try to home first
        print("\n1. Homing Y-axis...")
        resp = send_command(sock, "G28 Y")
        
        # Check if response is a dict and has error
        if isinstance(resp, dict) and 'error' in resp:
            error_msg = resp.get('error', {})
            if isinstance(error_msg, dict):
                error_msg = error_msg.get('message', 'Unknown error')
            print(f"⚠️  Homing failed: {str(error_msg)[:60]}")
            print("   Will try FORCE_MOVE instead...")
            time.sleep(1)
            # Use FORCE_MOVE to bypass homing requirement
            resp2 = send_command(sock, "FORCE_MOVE STEPPER=stepper_y DISTANCE=10 VELOCITY=5")
            if isinstance(resp2, dict) and 'error' in resp2:
                error_msg = resp2.get('error', {})
                if isinstance(error_msg, dict):
                    error_msg = error_msg.get('message', 'Unknown error')
                print(f"❌ FORCE_MOVE failed: {str(error_msg)}")
                return
            print("✅ FORCE_MOVE command sent (10mm)")
        else:
            print("✅ Homed successfully")
            print("\n" + "="*50)
            print("STOPPED AT HOME POSITION")
            print("="*50)
            print("Set up your caliper to measure the movement.")
            print("Position the caliper so you can measure from the current position.")
            print("\nPress ENTER when ready to move 10mm...")
            input()
            
            # Move exactly 10mm from home position
            print("\n2. Moving 10mm from home...")
            resp2 = send_command(sock, "G1 Y10 F300")
            if isinstance(resp2, dict) and 'error' in resp2:
                error_msg = resp2.get('error', {})
                if isinstance(error_msg, dict):
                    error_msg = error_msg.get('message', 'Unknown error')
                print(f"❌ Move failed: {str(error_msg)}")
                return
            print("✅ Move command sent (10mm)")
            print("Waiting for move to complete...")
            time.sleep(5)  # Wait for move to complete
        
        print("\n" + "="*50)
        print("NOW MEASURE THE ACTUAL MOVEMENT WITH YOUR CALIPER")
        print("="*50)
        print("\nEnter the ACTUAL measured distance (in mm):")
        actual_mm = float(input("> "))
        
        # Calculate correct rotation_distance
        # Formula: New rotation_distance = Current rotation_distance × (Actual / Commanded)
        # If we commanded 10mm but it moved actual_mm, then:
        # correct_rotation_distance = current_rotation_distance × (actual_mm / 10.0)
        current_rd = 1.0  # Current setting (update this if you change it)
        correct_rd = current_rd * (actual_mm / 10.0)
        
        print("\n" + "="*50)
        print("CALIBRATION RESULT:")
        print("="*50)
        print(f"Commanded: 10.00mm")
        print(f"Actual:    {actual_mm:.3f}mm")
        print("")
        print("Formula: New rotation_distance = Current × (Actual / Commanded)")
        print(f"Calculation: {current_rd} × ({actual_mm:.3f} / 10.0) = {correct_rd:.6f}mm")
        print("")
        print(f"Current rotation_distance: {current_rd}mm")
        print(f"Correct rotation_distance: {correct_rd:.6f}mm")
        print("")
        print("Update printer.cfg with:")
        print(f"rotation_distance: {correct_rd:.6f}")
        
    except FileNotFoundError:
        print(f"❌ Error: Cannot connect to {socket_path}")
        print("   Make sure Klipper is running")
    except KeyboardInterrupt:
        print("\n\nCancelled")
    except Exception as e:
        print(f"❌ Error: {e}")
    finally:
        sock.close()

if __name__ == '__main__':
    main()
