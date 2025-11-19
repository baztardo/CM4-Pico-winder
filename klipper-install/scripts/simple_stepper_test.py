#!/usr/bin/env python3
"""
Simple Stepper Test - Just get basic movement working
No winder, no TMC2209, just basic stepper movement
"""
import sys
import os
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from klipper_interface import KlipperInterface


def simple_test(klipper):
    """Simple stepper movement test"""
    print("\n" + "="*60)
    print("SIMPLE STEPPER TEST")
    print("="*60)
    print("\nGoal: Just get the stepper to move 1mm")
    print("No winder, no TMC2209, just basic movement\n")
    
    # Step 1: Enable stepper
    print("Step 1: Enabling stepper_y...")
    result = klipper.send_gcode("SET_STEPPER_ENABLE STEPPER=stepper_y ENABLE=1", timeout=5.0)
    if result:
        print("✓ Stepper enabled")
    else:
        print(f"✗ Failed: {klipper.last_error}")
        return False
    
    time.sleep(0.5)
    
    # Step 2: Check enable status
    print("\nStep 2: Verifying enable status...")
    status = klipper.query_objects({"stepper_enable": None})
    if status:
        steppers = status.get("stepper_enable", {}).get("steppers", {})
        if steppers.get("stepper_y", False):
            print("✓ Stepper is enabled")
        else:
            print("✗ Stepper is NOT enabled")
            return False
    
    # Step 3: Get current position
    print("\nStep 3: Getting current position...")
    status = klipper.query_objects({"toolhead": ["position"]})
    if status:
        pos = status.get("toolhead", {}).get("position", [0, 0, 0, 0])
        start_y = pos[1]
        print(f"   Start position: Y={start_y:.2f}mm")
    
    # Step 4: Try movement
    print("\nStep 4: Moving 1mm...")
    print("   Command: G1 Y1 F100")
    result = klipper.send_gcode("G1 Y1 F100", timeout=10.0)
    if result:
        print("✓ Movement command sent")
    else:
        print(f"✗ Movement failed: {klipper.last_error}")
        return False
    
    time.sleep(2)
    
    # Step 5: Check position
    print("\nStep 5: Checking final position...")
    status = klipper.query_objects({"toolhead": ["position"]})
    if status:
        pos = status.get("toolhead", {}).get("position", [0, 0, 0, 0])
        end_y = pos[1]
        print(f"   End position: Y={end_y:.2f}mm")
        moved = end_y - start_y
        print(f"   Moved: {moved:.2f}mm")
        
        if abs(moved) > 0.1:
            print("\n✓✓✓ SUCCESS! Stepper moved!")
            return True
        else:
            print("\n✗ Stepper did NOT move")
            print("\nTroubleshooting:")
            print("1. Check motor power (VBB/VM on stepper header)")
            print("2. Check motor wiring (A+, A-, B+, B-)")
            print("3. Check step pin (PF12) - should pulse when moving")
            print("4. Check enable pin (PB3) - should be LOW when enabled")
            return False
    
    return False


if __name__ == "__main__":
    klipper = KlipperInterface()
    if not klipper.connect():
        print("ERROR: Failed to connect to Klipper")
        sys.exit(1)
    
    try:
        success = simple_test(klipper)
        sys.exit(0 if success else 1)
    finally:
        klipper.disconnect()

