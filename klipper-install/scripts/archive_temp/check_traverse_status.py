#!/usr/bin/env python3
"""
Check Traverse Status - Comprehensive diagnostic
"""
import sys
import os
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from klipper_interface import KlipperInterface


def check_traverse_status(klipper):
    """Check traverse stepper status"""
    print("\n" + "="*60)
    print("TRAVERSE STEPPER STATUS CHECK")
    print("="*60)
    
    # 1. Check TMC2209
    print("\n1. TMC2209 Status:")
    print("   Querying TMC2209...")
    result = klipper.send_gcode("QUERY_TMC stepper_y", timeout=5.0)
    if result:
        print("✓ TMC2209 query sent successfully")
    else:
        print(f"✗ TMC2209 query failed: {klipper.last_error}")
        print("   → This indicates UART communication issue (PF13 pin)")
    
    time.sleep(1)
    
    # 2. Check stepper enable status
    print("\n2. Stepper Enable Status:")
    status = klipper.query_objects({"stepper_enable": None})
    if status:
        stepper_enable = status.get("stepper_enable", {})
        steppers = stepper_enable.get("steppers", {})
        y_enabled = steppers.get("stepper_y", False)
        print(f"   stepper_y enabled: {y_enabled}")
        if not y_enabled:
            print("   → Stepper is DISABLED - this is why it's not moving!")
            print("   → Enabling now...")
            klipper.send_gcode("SET_STEPPER_ENABLE STEPPER=stepper_y ENABLE=1", timeout=5.0)
            time.sleep(0.5)
            # Check again
            status2 = klipper.query_objects({"stepper_enable": None})
            if status2:
                stepper_enable2 = status2.get("stepper_enable", {})
                steppers2 = stepper_enable2.get("steppers", {})
                y_enabled2 = steppers2.get("stepper_y", False)
                print(f"   stepper_y enabled after command: {y_enabled2}")
    else:
        print("   ✗ Could not query stepper_enable")
    
    # 3. Check toolhead position
    print("\n3. Toolhead Position:")
    status = klipper.query_objects({"toolhead": ["position", "homed_axes"]})
    if status:
        toolhead = status.get("toolhead", {})
        pos = toolhead.get("position", [0, 0, 0, 0])
        homed = toolhead.get("homed_axes", "")
        print(f"   Position: Y={pos[1]:.2f}mm")
        print(f"   Homed axes: {homed}")
        if 'y' not in homed:
            print("   → Y-axis not homed - this might prevent movement")
    
    # 4. Test small movement
    print("\n4. Testing Movement:")
    print("   Sending G1 Y1 F100...")
    result = klipper.send_gcode("G1 Y1 F100", timeout=10.0)
    if result:
        print("✓ Movement command sent")
        time.sleep(2)
        # Check position again
        status = klipper.query_objects({"toolhead": ["position"]})
        if status:
            toolhead = status.get("toolhead", {})
            pos = toolhead.get("position", [0, 0, 0, 0])
            print(f"   Position after move: Y={pos[1]:.2f}mm")
            if pos[1] > 0.5:
                print("✓ Stepper moved!")
            else:
                print("✗ Stepper did NOT move")
    else:
        print(f"✗ Movement command failed: {klipper.last_error}")
    
    # 5. Summary
    print("\n" + "="*60)
    print("SUMMARY")
    print("="*60)
    print("\nIf stepper is not moving, check:")
    print("1. TMC2209 UART communication (PF13 pin)")
    print("2. Stepper enable pin (PB3)")
    print("3. Motor power (VBB/VM on stepper header)")
    print("4. Motor wiring (A+, A-, B+, B-)")
    print("5. Step/DIR pins (PF12, PF11)")


if __name__ == "__main__":
    klipper = KlipperInterface()
    if not klipper.connect():
        print("ERROR: Failed to connect to Klipper")
        sys.exit(1)
    
    try:
        check_traverse_status(klipper)
    finally:
        klipper.disconnect()

