#!/usr/bin/env python3
"""
TMC2209 Diagnostic - Check UART communication and driver status
"""
import sys
import os
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from klipper_interface import KlipperInterface

def diagnose_tmc2209():
    """Comprehensive TMC2209 diagnostic"""
    print("=" * 70)
    print("TMC2209 DIAGNOSTIC - Traverse Stepper (Motor 2)")
    print("=" * 70)
    print()
    
    klipper = KlipperInterface()
    if not klipper.connect():
        print("❌ Failed to connect to Klipper")
        return
    
    # 1. Check printer state
    print("1. Checking Klipper state...")
    info = klipper.get_printer_info()
    if info:
        state = info.get("state", "unknown")
        print(f"   State: {state}")
        if state != 'ready':
            print(f"   ❌ Klipper not ready: {info.get('state_message', '')}")
            return
        print("   ✓ Klipper is ready")
    else:
        print("   ❌ Cannot get printer info")
        return
    
    print()
    
    # 2. Check TMC2209 configuration
    print("2. Checking TMC2209 configuration...")
    print("   Expected: uart_pin: PF13")
    print("   Config file: ~/printer.cfg")
    print("   → Check: grep 'tmc2209 stepper_y' ~/printer.cfg")
    
    print()
    
    # 3. Test TMC2209 UART communication
    print("3. Testing TMC2209 UART communication...")
    print("   Querying TMC2209 object...")
    
    # Query TMC2209 object directly
    tmc_status = klipper.query_objects({"tmc2209 stepper_y": None})
    if tmc_status:
        tmc = tmc_status.get("tmc2209 stepper_y", {})
        if tmc:
            print("   ✓ TMC2209 object found")
            # Check for common TMC fields
            if "mcu_uart" in str(tmc):
                print("   ✓ TMC2209 UART configured")
            # Try to get status register
            try:
                # TMC status is usually in logs, not directly queryable
                print("   → TMC2209 is configured and should be communicating")
                print("   → Check logs for TMC errors: tail -100 /tmp/klippy.log | grep -i tmc")
            except:
                pass
        else:
            print("   ⚠️  TMC2209 object not found in query response")
    else:
        print("   ❌ Cannot query TMC2209 object")
        print()
        print("   TROUBLESHOOTING:")
        print("   → TMC2209 may not be initialized")
        print("   → Check config: grep 'tmc2209 stepper_y' ~/printer.cfg")
        print("   → Check logs for TMC errors: tail -100 /tmp/klippy.log | grep -i 'tmc\|uart\|error'")
    
    # Check logs for TMC errors
    print()
    print("   Checking logs for TMC2209 errors...")
    import subprocess
    try:
        log_check = subprocess.run(
            ["tail", "-100", "/tmp/klippy.log"],
            capture_output=True, text=True, timeout=2
        )
        if log_check.returncode == 0:
            tmc_errors = [line for line in log_check.stdout.split('\n') 
                         if 'tmc' in line.lower() or 'uart' in line.lower() or 'error' in line.lower()]
            if tmc_errors:
                print("   Recent TMC/UART messages:")
                for line in tmc_errors[-5:]:
                    print(f"     {line[:80]}")
            else:
                print("   → No TMC/UART messages in recent logs")
        else:
            print("   ⚠️  Could not read logs")
    except:
        print("   ⚠️  Could not check logs (run manually: tail -100 /tmp/klippy.log | grep -i tmc)")
    
    time.sleep(1)
    
    print()
    
    # 4. Check stepper enable status
    print("4. Checking stepper enable status...")
    status = klipper.query_objects({"stepper_enable": None})
    if status:
        stepper_enable = status.get("stepper_enable", {})
        steppers = stepper_enable.get("steppers", {})
        y_enabled = steppers.get("stepper_y", False)
        print(f"   stepper_y enabled: {y_enabled}")
        
        if not y_enabled:
            print("   → Stepper is DISABLED")
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
                if y_enabled2:
                    print("   ✓ Stepper enabled successfully")
                else:
                    print("   ❌ Stepper still disabled - check enable pin (PB3)")
        else:
            print("   ✓ Stepper is enabled")
    else:
        print("   ❌ Could not query stepper_enable")
    
    print()
    
    # 5. Check endstop status
    print("5. Checking endstop status...")
    result = klipper.send_gcode("QUERY_ENDSTOPS", timeout=5.0)
    if result:
        print("   ✓ QUERY_ENDSTOPS sent")
        print("   → Check response in logs or via: python3 ~/klipper/scripts/klipper_interface.py -g 'QUERY_ENDSTOPS'")
    else:
        print(f"   ⚠️  QUERY_ENDSTOPS failed: {klipper.last_error}")
    
    print()
    
    # 6. Check toolhead position
    print("6. Checking toolhead position...")
    status = klipper.query_objects({"toolhead": ["position", "homed_axes"]})
    if status:
        toolhead = status.get("toolhead", {})
        position = toolhead.get("position", [0, 0, 0, 0])
        homed_axes = toolhead.get("homed_axes", "")
        print(f"   Position: X={position[0]:.3f} Y={position[1]:.3f} Z={position[2]:.3f}")
        print(f"   Homed axes: {homed_axes}")
        if 'y' not in homed_axes.lower():
            print("   ⚠️  Y axis not homed - movement commands will fail")
            print("   → Run: G28 Y to home")
    else:
        print("   ❌ Could not query toolhead")
    
    print()
    print("=" * 70)
    print("NEXT STEPS:")
    print("=" * 70)
    print()
    print("If TMC2209 communication failed:")
    print("  1. Check physical connections:")
    print("     - PF13 → TMC2209 UART pin")
    print("     - PF12 → TMC2209 STEP pin")
    print("     - PF11 → TMC2209 DIR pin")
    print("     - PB3 → TMC2209 EN pin")
    print("  2. Check TMC2209 power:")
    print("     - 5V logic power")
    print("     - Motor power (12V/24V)")
    print("  3. Check TMC2209 is seated correctly on driver header")
    print("  4. Try removing and reseating TMC2209")
    print()
    print("If TMC2209 communication works but motor doesn't move:")
    print("  1. Check motor wiring (coil connections)")
    print("  2. Check motor power")
    print("  3. Try swapping motor coil wires")
    print("  4. Check TMC2209 current settings (run_current: 0.400)")
    print()
    print("To test movement:")
    print("  python3 ~/klipper/scripts/klipper_interface.py -g 'G28 Y'")
    print("  python3 ~/klipper/scripts/klipper_interface.py -g 'G91'")
    print("  python3 ~/klipper/scripts/klipper_interface.py -g 'G1 Y1 F100'")

if __name__ == "__main__":
    diagnose_tmc2209()

