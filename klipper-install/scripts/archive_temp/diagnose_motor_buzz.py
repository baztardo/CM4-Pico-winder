#!/usr/bin/env python3
"""
Diagnose motor buzzing but not moving
"""
import sys
import os
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from klipper_interface import KlipperInterface

def diagnose_motor_buzz():
    """Diagnose why motor buzzes but doesn't move"""
    print("=" * 70)
    print("MOTOR BUZZ DIAGNOSTIC")
    print("=" * 70)
    print()
    print("Motor buzzing but not moving indicates:")
    print("  - Stepper is getting power ✓")
    print("  - TMC2209 is enabled ✓")
    print("  - But step pulses may not be reaching motor")
    print()
    
    klipper = KlipperInterface()
    if not klipper.connect():
        print("❌ Failed to connect to Klipper")
        return
    
    # 1. Check recent errors
    print("1. Checking recent errors...")
    print("   Run on CM4: tail -50 /tmp/klippy.log | grep -i 'error\|endstop\|homing'")
    
    # 2. Check TMC2209 configuration
    print()
    print("2. TMC2209 Configuration:")
    print("   - uart_pin: PF13")
    print("   - run_current: 0.400")
    print("   - Check: grep 'tmc2209 stepper_y' ~/printer.cfg")
    
    # 3. Check stepper pins
    print()
    print("3. Stepper Pin Configuration:")
    print("   - step_pin: PF12")
    print("   - dir_pin: PF11")
    print("   - enable_pin: !PB3")
    print("   - Check: grep -A 5 '\[stepper_y\]' ~/printer.cfg")
    
    # 4. Test step pulses manually
    print()
    print("4. Testing step pulses...")
    print("   Enabling stepper...")
    klipper.send_gcode("SET_STEPPER_ENABLE STEPPER=stepper_y ENABLE=1")
    time.sleep(0.5)
    
    print("   Sending manual step pulses (MOVE command)...")
    print("   👀 WATCH THE MOTOR - does it move even slightly?")
    
    # Try a very slow movement
    klipper.send_gcode("G91")  # Relative mode
    time.sleep(0.2)
    
    # Try very slow movement
    print("   Moving 0.1mm at 10mm/min (very slow)...")
    result = klipper.send_gcode("G1 Y0.1 F10", timeout=10.0)
    if result:
        print("   ✓ Movement command sent")
    else:
        print(f"   ✗ Movement failed: {klipper.last_error}")
    
    time.sleep(2)
    
    # Try faster movement
    print("   Moving 1mm at 100mm/min...")
    result = klipper.send_gcode("G1 Y1 F100", timeout=10.0)
    if result:
        print("   ✓ Movement command sent")
    else:
        print(f"   ✗ Movement failed: {klipper.last_error}")
    
    time.sleep(2)
    
    # Disable
    klipper.send_gcode("SET_STEPPER_ENABLE STEPPER=stepper_y ENABLE=0")
    
    print()
    print("=" * 70)
    print("TROUBLESHOOTING STEPS:")
    print("=" * 70)
    print()
    print("If motor buzzes but doesn't move:")
    print()
    print("1. Check motor wiring:")
    print("   - Swap motor coil pairs (A+/A- with B+/B-)")
    print("   - Try swapping just one coil (A+ with A-)")
    print("   - Verify motor has 4 wires: 2 coils")
    print()
    print("2. Check TMC2209 current:")
    print("   - Current may be too low (0.400)")
    print("   - Try increasing: run_current: 0.600")
    print("   - Edit: nano ~/printer.cfg")
    print("   - Find: [tmc2209 stepper_y]")
    print("   - Change: run_current: 0.400 → run_current: 0.600")
    print()
    print("3. Check motor power:")
    print("   - Verify motor power supply (12V/24V)")
    print("   - Check voltage at motor power connector")
    print("   - Ensure power supply can deliver enough current")
    print()
    print("4. Check TMC2209 UART:")
    print("   - PF13 → TMC2209 UART pin")
    print("   - Check logs: tail -100 /tmp/klippy.log | grep -i tmc")
    print()
    print("5. Check mechanical binding:")
    print("   - Try rotating motor shaft by hand")
    print("   - Should rotate smoothly")
    print("   - If stuck, check mechanical assembly")
    print()
    print("6. Test with direct step pulses:")
    print("   - Bypass TMC2209 and test motor directly")
    print("   - Use output_pin to send step pulses")
    print("   - This isolates TMC2209 vs motor issue")

if __name__ == "__main__":
    diagnose_motor_buzz()

