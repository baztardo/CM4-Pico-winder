#!/usr/bin/env python3
"""
Diagnose Endstop Issue
Tests endstop switch state and suggests fix
"""
import sys
import os
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from klipper_interface import KlipperInterface


def diagnose_endstop(klipper):
    """Diagnose endstop issue"""
    print("\n" + "="*60)
    print("ENDSTOP DIAGNOSTIC")
    print("="*60)
    
    # Query endstop status
    print("\n1. Checking endstop status...")
    result = klipper.send_gcode("QUERY_ENDSTOPS", timeout=5.0)
    
    if result:
        print("✓ QUERY_ENDSTOPS command sent")
        # The response should be in the status
        time.sleep(0.5)
    else:
        print(f"✗ Failed: {klipper.last_error}")
    
    # Try to query toolhead for endstop info
    print("\n2. Querying toolhead status...")
    status = klipper.query_objects({"toolhead": ["homed_axes", "status"]})
    if status:
        toolhead = status.get("toolhead", {})
        print(f"   Homed axes: {toolhead.get('homed_axes', 'N/A')}")
        print(f"   Status: {toolhead.get('status', {}).get('print_state', 'N/A')}")
    
    print("\n3. Testing endstop pin directly...")
    print("   Note: Endstop is on PF3")
    print("   Current config: endstop_pin: ^PF3 (inverted)")
    print("\n   If endstop shows TRIGGERED when switch is NOT pressed:")
    print("   → Try removing ^ (change to: endstop_pin: PF3)")
    print("\n   If endstop shows open when switch IS pressed:")
    print("   → Keep ^ (inverted is correct)")
    
    print("\n4. Manual test:")
    print("   - Press and hold the endstop switch")
    print("   - Run: python3 scripts/klipper_interface.py -g 'QUERY_ENDSTOPS'")
    print("   - Release the switch")
    print("   - Run again and compare results")
    
    print("\n5. Suggested fix:")
    print("   Edit config/generic-bigtreetech-manta-m8p-V1_1.cfg")
    print("   Change line 28 from:")
    print("     endstop_pin: ^PF3")
    print("   To:")
    print("     endstop_pin: PF3")
    print("   Then restart Klipper: sudo systemctl restart klipper")


if __name__ == "__main__":
    klipper = KlipperInterface()
    if not klipper.connect():
        print("ERROR: Failed to connect to Klipper")
        sys.exit(1)
    
    try:
        diagnose_endstop(klipper)
    finally:
        klipper.disconnect()

