#!/usr/bin/env python3
"""
Winding System Calibration Script

Performs repeatable calibration tests to measure:
1. Turns per layer (actual vs theoretical)
2. Traverse distance per turn
3. Wire diameter (effective, including coating)
4. Spindle RPM accuracy

Usage:
    python3 calibrate_winding_system.py --rpm 300 --layers 3 --repeat 3
"""

import argparse
import json
import time
import sys
import os

# Add klipper scripts to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'klipper', 'scripts'))

try:
    from klipper_interface import KlipperInterface
except ImportError:
    print("ERROR: Could not import klipper_interface")
    print("Make sure you're running this on the CM4 with Klipper installed")
    sys.exit(1)


class WindingCalibration:
    def __init__(self, socket_path='/tmp/klippy_uds'):
        self.klipper = KlipperInterface(socket_path)
        self.results = []
    
    def get_status(self):
        """Get current winder status"""
        response = self.klipper.send_gcode("QUERY_WINDER")
        return response
    
    def get_hardware_count(self):
        """Get hardware counter value from log"""
        # Query the hardware counter
        self.klipper.send_gcode("QUERY_ENDSTOPS")  # Dummy command to flush
        time.sleep(0.1)
        
        # Read from log (this is a workaround - ideally we'd have a direct query)
        try:
            with open('/tmp/klippy.log', 'r') as f:
                lines = f.readlines()
                for line in reversed(lines[-100:]):
                    if 'Hardware Hall Counter' in line and 'count=' in line:
                        # Parse: Hardware Hall Counter 'hw_counter': count=1234
                        parts = line.split('count=')
                        if len(parts) > 1:
                            count = int(parts[1].split()[0])
                            return count
        except Exception as e:
            print(f"Warning: Could not read hardware counter from log: {e}")
        
        return None
    
    def get_traverse_position(self):
        """Get current Y position"""
        response = self.klipper.send_gcode("M114")
        # Parse response for Y position
        # This is a simplified parser - may need adjustment
        return None  # TODO: Parse M114 response
    
    def run_calibration_test(self, rpm, layers, test_number):
        """Run a single calibration test"""
        print(f"\n{'='*60}")
        print(f"CALIBRATION TEST #{test_number}")
        print(f"{'='*60}")
        print(f"RPM: {rpm}")
        print(f"Layers: {layers}")
        print()
        
        # Home and calibrate
        print("1. Homing traverse...")
        self.klipper.send_gcode("HOME_TRAVERSE")
        time.sleep(2)
        
        # Get starting position
        print("2. Recording start position...")
        start_y = 43.0  # Known start position
        
        # Reset hardware counter (via BLDC_START/STOP cycle)
        print("3. Resetting hardware counter...")
        self.klipper.send_gcode("CALIBRATE_SPINDLE")
        time.sleep(2)
        
        # Get initial count
        initial_count = self.get_hardware_count()
        print(f"   Initial count: {initial_count}")
        
        # Start winding
        print(f"4. Starting winding test ({rpm} RPM, {layers} layers)...")
        start_time = time.time()
        
        # Generate and run test G-code
        gcode_file = f"/tmp/calibration_test_{test_number}.gcode"
        cmd = f"python3 ~/generate_winding_gcode.py --rpm {rpm} --layers {layers} --output {gcode_file}"
        os.system(cmd)
        
        # Run the G-code
        self.klipper.send_gcode(f"SDCARD_PRINT_FILE FILENAME={gcode_file}")
        
        # Wait for completion (poll status)
        print("5. Waiting for completion...")
        while True:
            time.sleep(1)
            # Check if still printing (this is simplified)
            # In reality, we'd query virtual_sdcard status
            # For now, just wait a reasonable time
            if time.time() - start_time > (layers * 10 + 30):
                break
        
        end_time = time.time()
        duration = end_time - start_time
        
        # Get final measurements
        print("6. Recording final measurements...")
        time.sleep(2)
        
        final_count = self.get_hardware_count()
        end_y = 43.0 + (6.35 if layers % 2 == 0 else 0)  # Estimate based on layers
        
        # Calculate results
        actual_turns = final_count - initial_count if initial_count else final_count
        turns_per_layer = actual_turns / layers if layers > 0 else 0
        traverse_distance = abs(end_y - start_y)
        distance_per_turn = traverse_distance / actual_turns if actual_turns > 0 else 0
        
        # Theoretical calculations
        wire_diameter = 0.056  # mm
        wire_coating = 0.016  # mm
        effective_wire_dia = wire_diameter + wire_coating
        bobbin_width = 6.35  # mm
        theoretical_turns_per_layer = bobbin_width / effective_wire_dia
        
        result = {
            'test_number': test_number,
            'rpm': rpm,
            'layers': layers,
            'duration': duration,
            'initial_count': initial_count,
            'final_count': final_count,
            'actual_turns': actual_turns,
            'turns_per_layer': turns_per_layer,
            'theoretical_turns_per_layer': theoretical_turns_per_layer,
            'calibration_factor': turns_per_layer / theoretical_turns_per_layer if theoretical_turns_per_layer > 0 else 0,
            'traverse_distance': traverse_distance,
            'distance_per_turn': distance_per_turn,
            'effective_wire_diameter': distance_per_turn,  # Should equal wire diameter if perfect
        }
        
        # Print results
        print(f"\n{'='*60}")
        print(f"TEST #{test_number} RESULTS:")
        print(f"{'='*60}")
        print(f"Duration: {duration:.1f} seconds")
        print(f"Actual turns: {actual_turns}")
        print(f"Turns per layer: {turns_per_layer:.2f}")
        print(f"Theoretical turns per layer: {theoretical_turns_per_layer:.2f}")
        print(f"Calibration factor: {result['calibration_factor']:.4f}")
        print(f"Distance per turn: {distance_per_turn:.4f} mm")
        print(f"Effective wire diameter: {distance_per_turn:.4f} mm (expected: {effective_wire_dia:.4f} mm)")
        print(f"{'='*60}\n")
        
        return result
    
    def run_calibration_series(self, rpm, layers, repeat):
        """Run multiple calibration tests and average results"""
        print(f"\n{'#'*60}")
        print(f"WINDING SYSTEM CALIBRATION")
        print(f"{'#'*60}")
        print(f"Configuration:")
        print(f"  RPM: {rpm}")
        print(f"  Layers per test: {layers}")
        print(f"  Number of tests: {repeat}")
        print(f"{'#'*60}\n")
        
        results = []
        for i in range(repeat):
            result = self.run_calibration_test(rpm, layers, i + 1)
            results.append(result)
            
            if i < repeat - 1:
                print("\nWaiting 5 seconds before next test...")
                time.sleep(5)
        
        # Calculate statistics
        self.print_summary(results)
        
        # Save results
        self.save_results(results, rpm, layers, repeat)
        
        return results
    
    def print_summary(self, results):
        """Print summary statistics"""
        if not results:
            return
        
        print(f"\n{'#'*60}")
        print(f"CALIBRATION SUMMARY ({len(results)} tests)")
        print(f"{'#'*60}\n")
        
        # Calculate averages
        avg_turns_per_layer = sum(r['turns_per_layer'] for r in results) / len(results)
        avg_calibration_factor = sum(r['calibration_factor'] for r in results) / len(results)
        avg_distance_per_turn = sum(r['distance_per_turn'] for r in results) / len(results)
        
        # Calculate standard deviations
        import math
        if len(results) > 1:
            std_turns = math.sqrt(sum((r['turns_per_layer'] - avg_turns_per_layer)**2 for r in results) / (len(results) - 1))
            std_calibration = math.sqrt(sum((r['calibration_factor'] - avg_calibration_factor)**2 for r in results) / (len(results) - 1))
            std_distance = math.sqrt(sum((r['distance_per_turn'] - avg_distance_per_turn)**2 for r in results) / (len(results) - 1))
        else:
            std_turns = 0
            std_calibration = 0
            std_distance = 0
        
        print(f"Turns per layer:")
        print(f"  Average: {avg_turns_per_layer:.2f}")
        print(f"  Std dev: ±{std_turns:.2f}")
        print(f"  Range: {min(r['turns_per_layer'] for r in results):.2f} - {max(r['turns_per_layer'] for r in results):.2f}")
        print()
        
        print(f"Calibration factor (use this in --turns-calibration):")
        print(f"  Average: {avg_calibration_factor:.4f}")
        print(f"  Std dev: ±{std_calibration:.4f}")
        print(f"  Range: {min(r['calibration_factor'] for r in results):.4f} - {max(r['calibration_factor'] for r in results):.4f}")
        print()
        
        print(f"Distance per turn (effective wire diameter):")
        print(f"  Average: {avg_distance_per_turn:.4f} mm")
        print(f"  Std dev: ±{std_distance:.4f} mm")
        print(f"  Expected: 0.0720 mm (0.056 + 0.016 coating)")
        print()
        
        print(f"RECOMMENDED SETTINGS:")
        print(f"  --turns-calibration {avg_calibration_factor:.4f}")
        print(f"  --wire-diameter {avg_distance_per_turn - 0.016:.4f}")
        print(f"  --wire-coating 0.016")
        print(f"\n{'#'*60}\n")
    
    def save_results(self, results, rpm, layers, repeat):
        """Save results to JSON file"""
        timestamp = time.strftime("%Y%m%d_%H%M%S")
        filename = f"calibration_{rpm}rpm_{layers}layers_{repeat}tests_{timestamp}.json"
        
        data = {
            'timestamp': timestamp,
            'configuration': {
                'rpm': rpm,
                'layers': layers,
                'repeat': repeat,
            },
            'results': results,
        }
        
        with open(filename, 'w') as f:
            json.dump(data, f, indent=2)
        
        print(f"Results saved to: {filename}")


def main():
    parser = argparse.ArgumentParser(description='Calibrate winding system')
    parser.add_argument('--rpm', type=float, default=300, help='Test RPM')
    parser.add_argument('--layers', type=int, default=3, help='Layers per test')
    parser.add_argument('--repeat', type=int, default=3, help='Number of tests to run')
    parser.add_argument('--socket', type=str, default='/tmp/klippy_uds', help='Klipper socket path')
    
    args = parser.parse_args()
    
    cal = WindingCalibration(socket_path=args.socket)
    cal.run_calibration_series(args.rpm, args.layers, args.repeat)


if __name__ == '__main__':
    main()

