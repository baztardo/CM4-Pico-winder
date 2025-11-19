#!/usr/bin/env python3
"""
Complete System Diagnostic - Check what's actually working
"""
import sys
import os
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from klipper_interface import KlipperInterface


def diagnose_everything(klipper):
    """Complete diagnostic of all systems"""
    print("\n" + "="*60)
    print("COMPLETE SYSTEM DIAGNOSTIC")
    print("="*60)
    
    results = {}
    
    # 1. Check MCU connection
    print("\n1. MCU Connection:")
    info = klipper.get_printer_info()
    if info:
        state = info.get("state", "unknown")
        print(f"   State: {state}")
        results['mcu'] = state == 'ready'
        if state != 'ready':
            print(f"   ✗ MCU not ready: {info.get('state_message', '')}")
        else:
            print("   ✓ MCU is ready")
    else:
        print("   ✗ Cannot get printer info")
        results['mcu'] = False
    
    # 2. Check stepper enable
    print("\n2. Stepper Enable:")
    status = klipper.query_objects({"stepper_enable": None})
    if status:
        steppers = status.get("stepper_enable", {}).get("steppers", {})
        y_enabled = steppers.get("stepper_y", False)
        print(f"   stepper_y enabled: {y_enabled}")
        results['stepper_enabled'] = y_enabled
        if not y_enabled:
            print("   → Try: SET_STEPPER_ENABLE STEPPER=stepper_y ENABLE=1")
    else:
        print("   ✗ Cannot query stepper_enable")
        results['stepper_enabled'] = False
    
    # 3. Check TMC2209
    print("\n3. TMC2209 Communication:")
    result = klipper.send_gcode("QUERY_TMC stepper_y", timeout=5.0)
    if result:
        print("   ✓ TMC2209 query successful")
        results['tmc2209'] = True
    else:
        print(f"   ✗ TMC2209 query failed: {klipper.last_error}")
        results['tmc2209'] = False
        print("   → TMC2209 UART (PF13) may not be connected")
    
    # 4. Check endstop
    print("\n4. Endstop Status:")
    result = klipper.send_gcode("QUERY_ENDSTOPS", timeout=5.0)
    if result:
        print("   ✓ Endstop query sent")
        results['endstop'] = True
    else:
        print(f"   ✗ Endstop query failed: {klipper.last_error}")
        results['endstop'] = False
    
    # 5. Check toolhead position
    print("\n5. Toolhead Status:")
    status = klipper.query_objects({"toolhead": ["position", "homed_axes", "status"]})
    if status:
        toolhead = status.get("toolhead", {})
        pos = toolhead.get("position", [0, 0, 0, 0])
        homed = toolhead.get("homed_axes", "")
        print(f"   Position: Y={pos[1]:.2f}mm")
        print(f"   Homed axes: {homed}")
        results['toolhead'] = True
    else:
        print("   ✗ Cannot query toolhead")
        results['toolhead'] = False
    
    # 6. Check winder module (if present)
    print("\n6. Winder Module:")
    status = klipper.query_objects({"winder": None})
    if status:
        winder = status.get("winder", {})
        print(f"   ✓ Winder module loaded")
        print(f"   Active: {winder.get('is_winding', False)}")
        results['winder'] = True
    else:
        print("   → Winder module not loaded (OK for basic test)")
        results['winder'] = False
    
    # 7. Check output pins
    print("\n7. Output Pins:")
    status = klipper.query_objects({"output_pin": None})
    if status:
        output_pins = status.get("output_pin", {})
        print(f"   ✓ Output pins available: {list(output_pins.keys())}")
        results['output_pins'] = True
    else:
        print("   → No output pins configured")
        results['output_pins'] = False
    
    # Summary
    print("\n" + "="*60)
    print("SUMMARY")
    print("="*60)
    print("\nWhat's Working:")
    for key, value in results.items():
        if value:
            print(f"  ✓ {key}")
    
    print("\nWhat's NOT Working:")
    for key, value in results.items():
        if not value:
            print(f"  ✗ {key}")
    
    print("\n" + "="*60)
    print("RECOMMENDATIONS")
    print("="*60)
    
    if not results.get('mcu'):
        print("\n1. MCU is not ready - fix this first!")
        print("   → Check serial connection")
        print("   → Run: FIRMWARE_RESTART")
    
    if not results.get('stepper_enabled'):
        print("\n2. Stepper is disabled - enable it:")
        print("   → SET_STEPPER_ENABLE STEPPER=stepper_y ENABLE=1")
    
    if not results.get('tmc2209'):
        print("\n3. TMC2209 not communicating:")
        print("   → Comment out [tmc2209 stepper_y] section")
        print("   → Test stepper without TMC2209 first")
    
    if not results.get('endstop'):
        print("\n4. Endstop issue:")
        print("   → Check wiring (PF3 pin)")
        print("   → Try: endstop_pin: PF3 (no ^)")
    
    print("\nNext Steps:")
    print("1. Fix MCU connection if not ready")
    print("2. Enable stepper manually")
    print("3. Test movement WITHOUT TMC2209")
    print("4. Once basic movement works, add TMC2209 back")


if __name__ == "__main__":
    klipper = KlipperInterface()
    if not klipper.connect():
        print("ERROR: Failed to connect to Klipper")
        print("Check: sudo systemctl status klipper")
        sys.exit(1)
    
    try:
        diagnose_everything(klipper)
    finally:
        klipper.disconnect()

