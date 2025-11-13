#!/usr/bin/env python3
"""
Winding Sequence Controller - High-level winding operations using Klipper interface
"""
import sys
import os
import time
import json

# Add scripts directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from klipper_interface import KlipperInterface


class WindingSequence:
    """High-level winding sequence controller"""
    
    def __init__(self, socket_path="/tmp/klippy_uds"):
        self.klipper = KlipperInterface(socket_path)
        self.connected = False
        
    def connect(self):
        """Connect to Klipper"""
        if self.klipper.connect():
            self.connected = True
            return True
        return False
    
    def disconnect(self):
        """Disconnect from Klipper"""
        if self.connected:
            self.klipper.disconnect()
            self.connected = False
    
    def get_status(self):
        """Get winder status"""
        if not self.connected:
            return None
        return self.klipper.query_objects({"winder": None})
    
    def home_traverse(self):
        """Home the traverse (Y-axis)"""
        if not self.connected:
            return False
        return self.klipper.send_gcode("G28 Y")
    
    def move_to(self, y_position, feedrate=1000):
        """Move traverse to position"""
        if not self.connected:
            return False
        return self.klipper.send_gcode(f"G1 Y{y_position} F{feedrate}")
    
    def set_spindle_speed(self, rpm):
        """Set spindle speed"""
        if not self.connected:
            return False
        return self.klipper.send_gcode(f"SET_SPINDLE_SPEED RPM={rpm}")
    
    def start_winding(self, rpm=100, layers=1):
        """Start winding operation"""
        if not self.connected:
            return False
        return self.klipper.send_gcode(f"WINDER_START RPM={rpm} LAYERS={layers}")
    
    def stop_winding(self):
        """Stop winding"""
        if not self.connected:
            return False
        return self.klipper.send_gcode("WINDER_STOP")
    
    def set_wire_diameter(self, diameter):
        """Set wire diameter (mm)"""
        if not self.connected:
            return False
        return self.klipper.send_gcode(f"SET_WIRE_DIAMETER DIAMETER={diameter}")
    
    def wind_layer(self, start_y, end_y, rpm, wire_diameter=0.056, feedrate=None):
        """
        Wind a single layer (forward and back)
        
        Args:
            start_y: Starting Y position (mm)
            end_y: Ending Y position (mm)
            rpm: Spindle RPM
            wire_diameter: Wire diameter (mm)
            feedrate: Traverse feedrate (mm/min). If None, calculated automatically
        """
        if not self.connected:
            return False
        
        # Calculate feedrate if not provided
        if feedrate is None:
            # Feedrate = (RPM / 60) * wire_diameter * 60 (convert to mm/min)
            feedrate = (rpm / 60.0) * wire_diameter * 60.0
        
        # Start spindle
        if not self.set_spindle_speed(rpm):
            print("ERROR: Failed to set spindle speed")
            return False
        
        time.sleep(0.5)  # Wait for spindle to start
        
        # Move forward
        if not self.move_to(end_y, feedrate):
            print("ERROR: Failed to move forward")
            return False
        
        # Wait for move to complete (rough estimate)
        move_time = abs(end_y - start_y) / (feedrate / 60.0)
        time.sleep(move_time + 0.5)
        
        # Move back
        if not self.move_to(start_y, feedrate):
            print("ERROR: Failed to move back")
            return False
        
        time.sleep(move_time + 0.5)
        
        return True
    
    def wind_coil(self, layers=10, start_y=38.0, end_y=50.0, rpm=100, 
                  wire_diameter=0.056, pause_between_layers=0.5):
        """
        Wind a complete coil with multiple layers
        
        Args:
            layers: Number of layers to wind
            start_y: Starting Y position (mm)
            end_y: Ending Y position (mm)
            rpm: Spindle RPM
            wire_diameter: Wire diameter (mm)
            pause_between_layers: Pause time between layers (seconds)
        """
        if not self.connected:
            print("ERROR: Not connected to Klipper")
            return False
        
        print(f"Winding coil: {layers} layers, {start_y}mm to {end_y}mm, {rpm} RPM")
        
        # Home traverse
        print("Homing traverse...")
        if not self.home_traverse():
            print("ERROR: Homing failed")
            return False
        time.sleep(2)
        
        # Move to start position
        print(f"Moving to start position Y{start_y}...")
        if not self.move_to(start_y):
            print("ERROR: Failed to move to start position")
            return False
        time.sleep(1)
        
        # Set wire diameter
        print(f"Setting wire diameter: {wire_diameter}mm")
        self.set_wire_diameter(wire_diameter)
        
        # Wind layers
        for layer in range(layers):
            print(f"Layer {layer + 1}/{layers}...")
            if not self.wind_layer(start_y, end_y, rpm, wire_diameter):
                print(f"ERROR: Layer {layer + 1} failed")
                return False
            
            if layer < layers - 1:  # Don't pause after last layer
                time.sleep(pause_between_layers)
        
        print("Winding complete!")
        return True
    
    def get_motor_status(self):
        """Get motor/spindle status"""
        status = self.get_status()
        if status and "winder" in status:
            winder = status["winder"]
            return {
                "motor_rpm": winder.get("motor_measured_rpm", 0),
                "spindle_rpm": winder.get("spindle_measured_rpm", 0),
                "motor_target_rpm": winder.get("motor_rpm_target", 0),
                "spindle_target_rpm": winder.get("spindle_rpm_target", 0),
                "is_winding": winder.get("is_winding", False),
                "wire_diameter": winder.get("wire_diameter", 0),
            }
        return None


def main():
    import argparse
    
    parser = argparse.ArgumentParser(
        description="Winding Sequence Controller",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Wind 10 layers
  python3 winding_sequence.py --wind --layers 10
  
  # Test motor at 500 RPM
  python3 winding_sequence.py --test-motor --rpm 500
  
  # Get status
  python3 winding_sequence.py --status
        """
    )
    
    parser.add_argument('-s', '--socket', default='/tmp/klippy_uds',
                       help='Unix socket path')
    parser.add_argument('--status', action='store_true',
                       help='Get winder status')
    parser.add_argument('--wind', action='store_true',
                       help='Wind a coil')
    parser.add_argument('--layers', type=int, default=10,
                       help='Number of layers')
    parser.add_argument('--start-y', type=float, default=38.0,
                       help='Start Y position (mm)')
    parser.add_argument('--end-y', type=float, default=50.0,
                       help='End Y position (mm)')
    parser.add_argument('--rpm', type=float, default=100.0,
                       help='Spindle RPM')
    parser.add_argument('--wire-diameter', type=float, default=0.056,
                       help='Wire diameter (mm)')
    parser.add_argument('--test-motor', action='store_true',
                       help='Test motor at specified RPM')
    parser.add_argument('--stop', action='store_true',
                       help='Stop winding/motor')
    
    args = parser.parse_args()
    
    # Create sequence controller
    seq = WindingSequence(args.socket)
    
    if not seq.connect():
        print("ERROR: Failed to connect to Klipper")
        return 1
    
    try:
        if args.status:
            status = seq.get_motor_status()
            if status:
                print("Winder Status:")
                print(json.dumps(status, indent=2))
            else:
                print("No status available")
        
        if args.test_motor:
            print(f"Testing motor at {args.rpm} RPM...")
            if seq.set_spindle_speed(args.rpm):
                print("Motor started. Press Ctrl+C to stop.")
                try:
                    while True:
                        status = seq.get_motor_status()
                        if status:
                            print(f"Motor: {status['motor_measured_rpm']:.1f} RPM, "
                                  f"Spindle: {status['spindle_measured_rpm']:.1f} RPM")
                        time.sleep(1)
                except KeyboardInterrupt:
                    print("\nStopping motor...")
                    seq.stop_winding()
            else:
                print("ERROR: Failed to start motor")
        
        if args.stop:
            print("Stopping...")
            seq.stop_winding()
        
        if args.wind:
            seq.wind_coil(args.layers, args.start_y, args.end_y, 
                         args.rpm, args.wire_diameter)
        
        # If no commands, show help
        if not (args.status or args.wind or args.test_motor or args.stop):
            parser.print_help()
    
    except KeyboardInterrupt:
        print("\nInterrupted")
        seq.stop_winding()
        return 1
    except Exception as e:
        print(f"ERROR: {e}")
        import traceback
        traceback.print_exc()
        return 1
    finally:
        seq.disconnect()
    
    return 0


if __name__ == "__main__":
    sys.exit(main())


