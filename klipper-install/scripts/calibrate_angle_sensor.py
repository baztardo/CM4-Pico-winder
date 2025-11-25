#!/usr/bin/env python3
"""
Angle Sensor Calibration Script

This script:
1. Spins the spindle at low RPM
2. Records angle sensor value every time hall sensor fires
3. Analyzes ADC range, gaps, and repeatability
4. Generates calibration data for angle-to-hall alignment

Usage:
    ./calibrate_angle_sensor.py --rpm 300 --revolutions 50
"""

import sys
import time
import socket
import json
import argparse
from collections import defaultdict

class KlipperAPI:
    """Simple Klipper API client"""
    
    def __init__(self, host='localhost', port=7125):
        self.host = host
        self.port = port
    
    def send_gcode(self, command):
        """Send G-code command via Moonraker API"""
        url = f"http://{self.host}:{self.port}/printer/gcode/script?script={command}"
        import urllib.request
        try:
            with urllib.request.urlopen(url, timeout=5) as response:
                return response.read().decode()
        except Exception as e:
            print(f"Error sending command: {e}")
            return None
    
    def get_status(self, objects):
        """Get printer status"""
        url = f"http://{self.host}:{self.port}/printer/objects/query?{objects}"
        import urllib.request
        try:
            with urllib.request.urlopen(url, timeout=5) as response:
                data = json.loads(response.read().decode())
                return data.get('result', {}).get('status', {})
        except Exception as e:
            print(f"Error getting status: {e}")
            return {}

def calibrate_angle_sensor(api, rpm=300, revolutions=50):
    """
    Calibrate angle sensor by recording angle at every hall pulse
    
    Args:
        api: KlipperAPI instance
        rpm: Spindle RPM for calibration (low speed for accuracy)
        revolutions: Number of revolutions to record
    """
    print("=" * 70)
    print("ANGLE SENSOR CALIBRATION")
    print("=" * 70)
    print(f"Target RPM: {rpm}")
    print(f"Revolutions to record: {revolutions}")
    print()
    
    # Start motor
    print("Starting motor...")
    api.send_gcode(f"BLDC_START RPM={rpm}")
    time.sleep(2)  # Let motor stabilize
    
    # Data collection
    hall_angles = []  # Angle at each hall pulse
    adc_samples = []  # All ADC samples
    last_hall_count = None
    
    print("Recording data...")
    print("Hall Count | Angle (deg) | ADC Value | Delta from last")
    print("-" * 70)
    
    start_time = time.time()
    timeout = (revolutions / (rpm / 60.0)) * 1.5  # 1.5x expected time
    
    while len(hall_angles) < revolutions:
        # Check timeout
        if time.time() - start_time > timeout:
            print(f"\nTimeout after {timeout:.1f}s")
            break
        
        # Get current status
        status = api.get_status("hw_counter,angle_sensor")
        
        if not status:
            time.sleep(0.05)
            continue
        
        # Get hall counter
        hw_counter = status.get('hw_counter', {})
        hall_count = hw_counter.get('count', 0)
        
        # Get angle sensor
        angle_sensor = status.get('angle_sensor', {})
        angle_deg = angle_sensor.get('angle', 0.0)
        adc_value = angle_sensor.get('adc_value', 0.0)
        
        # Record ADC sample
        adc_samples.append(adc_value)
        
        # Check if hall count changed
        if last_hall_count is not None and hall_count > last_hall_count:
            # Hall pulse fired - record angle
            delta = ""
            if len(hall_angles) > 0:
                last_angle = hall_angles[-1][1]
                delta = f"{angle_deg - last_angle:+.1f}°"
            
            hall_angles.append((hall_count, angle_deg, adc_value))
            print(f"{hall_count:10d} | {angle_deg:11.2f} | {adc_value:9.4f} | {delta}")
        
        last_hall_count = hall_count
        time.sleep(0.01)  # 100 Hz sampling
    
    # Stop motor
    print("\nStopping motor...")
    api.send_gcode("BLDC_STOP")
    time.sleep(1)
    
    # Analyze data
    print("\n" + "=" * 70)
    print("CALIBRATION RESULTS")
    print("=" * 70)
    
    if len(hall_angles) < 2:
        print("ERROR: Not enough data collected!")
        return
    
    # ADC range analysis
    adc_min = min(adc_samples)
    adc_max = max(adc_samples)
    adc_range = adc_max - adc_min
    
    print(f"\nADC RANGE:")
    print(f"  Min: {adc_min:.4f}")
    print(f"  Max: {adc_max:.4f}")
    print(f"  Range: {adc_range:.4f}")
    print(f"  Samples: {len(adc_samples)}")
    
    # Unique ADC values (resolution)
    unique_adc = len(set([round(v, 4) for v in adc_samples]))
    print(f"  Unique values: {unique_adc}")
    print(f"  Theoretical resolution: {360.0 / unique_adc:.2f}° per step")
    
    # Hall angle analysis
    angles = [a[1] for a in hall_angles]
    angle_mean = sum(angles) / len(angles)
    angle_std = (sum((a - angle_mean)**2 for a in angles) / len(angles)) ** 0.5
    angle_min = min(angles)
    angle_max = max(angles)
    
    print(f"\nHALL PULSE ANGLE:")
    print(f"  Mean: {angle_mean:.2f}°")
    print(f"  Std Dev: {angle_std:.2f}°")
    print(f"  Min: {angle_min:.2f}°")
    print(f"  Max: {angle_max:.2f}°")
    print(f"  Range: {angle_max - angle_min:.2f}°")
    
    # Repeatability check
    if angle_std < 5.0:
        print(f"  ✓ GOOD: Angle is repeatable (±{angle_std:.1f}°)")
    else:
        print(f"  ✗ BAD: Angle varies too much (±{angle_std:.1f}°)")
    
    # Check for saturation
    if adc_max >= 0.95:
        print(f"\n  ⚠ WARNING: ADC saturating at high end ({adc_max:.4f})")
    if adc_min <= 0.05:
        print(f"  ⚠ WARNING: ADC saturating at low end ({adc_min:.4f})")
    
    # Angle distribution
    print(f"\nANGLE DISTRIBUTION AT HALL PULSES:")
    angle_bins = defaultdict(int)
    for angle in angles:
        bin_angle = int(angle / 10) * 10
        angle_bins[bin_angle] += 1
    
    for bin_start in sorted(angle_bins.keys()):
        count = angle_bins[bin_start]
        bar = "█" * count
        print(f"  {bin_start:3d}-{bin_start+10:3d}°: {bar} ({count})")
    
    # Save calibration data
    print(f"\nRECOMMENDED CONFIG:")
    print(f"  angle_adc_min: {adc_min:.4f}")
    print(f"  angle_adc_max: {adc_max:.4f}")
    print(f"  hall_trigger_angle: {angle_mean:.1f}  # Angle when hall fires")
    
    print("\n" + "=" * 70)

def main():
    parser = argparse.ArgumentParser(description='Calibrate angle sensor')
    parser.add_argument('--rpm', type=int, default=300, help='Calibration RPM (default: 300)')
    parser.add_argument('--revolutions', type=int, default=50, help='Revolutions to record (default: 50)')
    parser.add_argument('--host', default='localhost', help='Moonraker host (default: localhost)')
    parser.add_argument('--port', type=int, default=7125, help='Moonraker port (default: 7125)')
    
    args = parser.parse_args()
    
    api = KlipperAPI(args.host, args.port)
    
    try:
        calibrate_angle_sensor(api, args.rpm, args.revolutions)
    except KeyboardInterrupt:
        print("\n\nCalibration interrupted!")
        api.send_gcode("BLDC_STOP")
    except Exception as e:
        print(f"\nError: {e}")
        import traceback
        traceback.print_exc()
        api.send_gcode("BLDC_STOP")

if __name__ == '__main__':
    main()

