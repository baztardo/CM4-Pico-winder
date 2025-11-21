#!/usr/bin/env python3
"""
Direct Hardware Test - Bypass Klipper entirely
Test stepper and BLDC motor directly via MCU serial port
"""

import serial
import time
import sys

# MCU serial port
SERIAL_PORT = "/dev/serial/by-id/usb-Klipper_stm32g0b1xx_2000080012504B4633373520-if00"

# Pin definitions (STM32G0B1)
STEP_PIN = "PF12"  # Motor 2 STEP
DIR_PIN = "PF11"   # Motor 2 DIR
EN_PIN = "PB3"     # Motor 2 EN

BLDC_PWM_PIN = "PC9"  # Motor 5 STEP (PWM capable)
BLDC_DIR_PIN = "PC8"  # Motor 5 DIR
BLDC_BRAKE_PIN = "PD1" # Motor 5 EN

def send_command(ser, cmd):
    """Send command to MCU and wait for response"""
    ser.write(cmd.encode() + b'\n')
    time.sleep(0.1)
    response = ser.read(ser.in_waiting).decode('utf-8', errors='ignore')
    return response

def test_serial_connection():
    """Test 1: Can we talk to the MCU?"""
    print("=" * 60)
    print("TEST 1: Serial Connection")
    print("=" * 60)
    
    try:
        ser = serial.Serial(SERIAL_PORT, 250000, timeout=1)
        time.sleep(2)  # Wait for MCU to initialize
        
        # Send status query
        response = send_command(ser, "status")
        print(f"MCU Response: {response[:200]}")
        
        if "Klipper" in response or "start" in response.lower():
            print("✓ MCU is responding")
            ser.close()
            return True
        else:
            print("⚠️  MCU responded but format unexpected")
            ser.close()
            return True
            
    except Exception as e:
        print(f"✗ FAILED: {e}")
        print("\nTroubleshooting:")
        print("  1. Stop Klipper: sudo systemctl stop klipper")
        print("  2. Check port: ls -la /dev/serial/by-id/")
        print("  3. Check permissions: ls -la /dev/ttyACM0")
        return False

def test_pin_control_direct():
    """Test 2: Direct pin control via GPIO commands"""
    print("\n" + "=" * 60)
    print("TEST 2: Direct Pin Control (requires Klipper running)")
    print("=" * 60)
    print("\nNOTE: This test requires Klipper to be running")
    print("      We'll use Klipper's SET_PIN command")
    print()
    
    import socket
    import json
    import struct
    
    try:
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.settimeout(2)
        sock.connect('/tmp/klippy_uds')
        
        def send_klipper_cmd(method, params=None):
            cmd = {"id": 1, "method": method}
            if params:
                cmd["params"] = params
            cmd_json = json.dumps(cmd) + "\n"
            cmd_bytes = cmd_json.encode('utf-8')
            sock.sendall(struct.pack('>I', len(cmd_bytes)) + cmd_bytes)
            size_bytes = sock.recv(4)
            if len(size_bytes) >= 4:
                size = struct.unpack('>I', size_bytes)[0]
                data = sock.recv(size)
                return json.loads(data.decode('utf-8'))
            return None
        
        # Test enable pin
        print(f"Testing {EN_PIN} (ENABLE pin)...")
        result = send_klipper_cmd("printer.gcode.script", {"script": f"SET_PIN PIN=stepper_y_enable VALUE=0"})
        if result and 'error' not in result:
            print("  ✓ Enable pin controllable")
        else:
            print(f"  ✗ Failed: {result}")
        
        # Test step pin
        print(f"\nTesting {STEP_PIN} (STEP pin)...")
        print("  Pulsing step pin 10 times...")
        for i in range(10):
            send_klipper_cmd("printer.gcode.script", {"script": f"SET_PIN PIN=stepper_y_step VALUE=1"})
            time.sleep(0.001)
            send_klipper_cmd("printer.gcode.script", {"script": f"SET_PIN PIN=stepper_y_step VALUE=0"})
            time.sleep(0.01)
            print(f"    Pulse {i+1}/10", end='\r')
        print("\n  ✓ Step pulses sent")
        print("\n  → Did the motor move? If yes, wiring is correct!")
        
        sock.close()
        return True
        
    except Exception as e:
        print(f"✗ FAILED: {e}")
        return False

def create_minimal_klipper_config():
    """Create absolute minimal config for pin testing"""
    print("\n" + "=" * 60)
    print("Creating Minimal Test Config")
    print("=" * 60)
    
    config = f"""[mcu]
serial: {SERIAL_PORT}

[printer]
kinematics: winder
max_velocity: 200
max_accel: 300

# Minimal stepper_y section (required by winder kinematics)
[stepper_y]
step_pin: {STEP_PIN}
dir_pin: {DIR_PIN}
enable_pin: !{EN_PIN}
endstop_pin: tmc2209_stepper_y:virtual_endstop
position_endstop: 0
position_min: -10
position_max: 93
homing_speed: 10
homing_retract_dist: 0
homing_retract_speed: 0

# BLDC motor pins
[output_pin bldc_pwm]
pin: {BLDC_PWM_PIN}

[output_pin bldc_dir]
pin: {BLDC_DIR_PIN}

[output_pin bldc_brake]
pin: !{BLDC_BRAKE_PIN}
"""
    
    config_path = "/tmp/minimal_hardware_test.cfg"
    with open(config_path, 'w') as f:
        f.write(config)
    
    print(f"✓ Config created: {config_path}")
    print("\nTo use:")
    print(f"  cp {config_path} ~/printer.cfg")
    print("  sudo systemctl restart klipper")
    print("  sleep 5")
    print("  python3 ~/klipper-install/scripts/direct_hardware_test.py --test-pins")
    
    return config_path

def manual_step_test():
    """Manual step test using output_pin"""
    print("\n" + "=" * 60)
    print("MANUAL STEP TEST")
    print("=" * 60)
    print("\nThis will pulse the step pin manually")
    print("Watch the motor - it should move slightly with each pulse")
    print()
    
    import socket
    import json
    import struct
    
    try:
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.settimeout(2)
        sock.connect('/tmp/klippy_uds')
        
        def send_cmd(script):
            cmd = {"id": 1, "method": "printer.gcode.script", "params": {"script": script}}
            cmd_json = json.dumps(cmd) + "\n"
            cmd_bytes = cmd_json.encode('utf-8')
            sock.sendall(struct.pack('>I', len(cmd_bytes)) + cmd_bytes)
            size_bytes = sock.recv(4)
            if len(size_bytes) >= 4:
                size = struct.unpack('>I', size_bytes)[0]
                data = sock.recv(size)
                return json.loads(data.decode('utf-8'))
            return None
        
        # Enable stepper (LOW = enabled)
        print("1. Enabling stepper (EN pin LOW)...")
        result = send_cmd("SET_PIN PIN=stepper_y_enable VALUE=0")
        print(f"   Result: {result}")
        time.sleep(0.5)
        
        # Set direction
        print("2. Setting direction...")
        send_cmd("SET_PIN PIN=stepper_y_dir VALUE=0")
        time.sleep(0.1)
        
        # Pulse step pin
        print("3. Pulsing step pin 20 times...")
        print("   Watch the motor!")
        for i in range(20):
            send_cmd("SET_PIN PIN=stepper_y_step VALUE=1")
            time.sleep(0.001)  # 1ms pulse
            send_cmd("SET_PIN PIN=stepper_y_step VALUE=0")
            time.sleep(0.01)   # 10ms between pulses
            if (i + 1) % 5 == 0:
                print(f"   Pulses: {i+1}/20")
        
        print("\n✓ Test complete")
        print("\nDid the motor move?")
        print("  YES → Hardware wiring is correct, issue is in Klipper config")
        print("  NO  → Check hardware: power, wiring, motor connections")
        
        sock.close()
        
    except Exception as e:
        print(f"✗ FAILED: {e}")
        print("\nMake sure:")
        print("  1. Klipper is running: sudo systemctl status klipper")
        print("  2. Minimal config is loaded")
        print("  3. API socket exists: ls -la /tmp/klippy_uds")

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--test-pins":
        manual_step_test()
    elif len(sys.argv) > 1 and sys.argv[1] == "--create-config":
        create_minimal_klipper_config()
    else:
        print("Direct Hardware Test - Proof of Concept")
        print("=" * 60)
        print()
        print("This script tests hardware directly, bypassing Klipper complexity")
        print()
        
        # Test 1: Serial connection
        if test_serial_connection():
            # Test 2: Pin control
            test_pin_control_direct()
        
        # Create minimal config
        create_minimal_klipper_config()
        
        print("\n" + "=" * 60)
        print("NEXT STEPS")
        print("=" * 60)
        print("1. Copy minimal config: cp /tmp/minimal_hardware_test.cfg ~/printer.cfg")
        print("2. Restart Klipper: sudo systemctl restart klipper")
        print("3. Run pin test: python3 ~/klipper-install/scripts/direct_hardware_test.py --test-pins")
        print()
        print("This will prove if hardware works, then we fix Klipper config")

