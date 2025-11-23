#!/usr/bin/env python3
"""
Fix MCU Shutdown - Restart MCU and clear errors
"""
import sys
import os
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from klipper_interface import KlipperInterface


def fix_mcu_shutdown(klipper):
    """Fix MCU shutdown state"""
    print("\n" + "="*60)
    print("FIXING MCU SHUTDOWN")
    print("="*60)
    
    # Check current state
    print("\n1. Checking printer state...")
    info = klipper.get_printer_info()
    if info:
        state = info.get("state", "unknown")
        state_message = info.get("state_message", "")
        print(f"   State: {state}")
        print(f"   Message: {state_message}")
    
    # Try firmware restart
    print("\n2. Restarting MCU firmware...")
    result = klipper.firmware_restart()
    if result:
        print("✓ FIRMWARE_RESTART command sent")
        print("   Waiting 5 seconds for MCU to restart...")
        time.sleep(5)
    else:
        print(f"✗ Failed: {klipper.last_error}")
        return False
    
    # Check state again
    print("\n3. Checking printer state after restart...")
    time.sleep(2)
    info = klipper.get_printer_info()
    if info:
        state = info.get("state", "unknown")
        state_message = info.get("state_message", "")
        print(f"   State: {state}")
        print(f"   Message: {state_message}")
        
        if state == "ready":
            print("✓ MCU is ready!")
            return True
        else:
            print("✗ MCU still not ready")
            print("   Try: sudo systemctl restart klipper")
            return False
    else:
        print("✗ Could not get printer info")
        return False


if __name__ == "__main__":
    klipper = KlipperInterface()
    if not klipper.connect():
        print("ERROR: Failed to connect to Klipper")
        sys.exit(1)
    
    try:
        success = fix_mcu_shutdown(klipper)
        sys.exit(0 if success else 1)
    finally:
        klipper.disconnect()

