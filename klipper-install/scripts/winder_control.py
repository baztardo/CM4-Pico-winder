#!/usr/bin/env python3
"""
Winder Control Script - Example usage of klipper_interface for winder operations
"""
import sys
import os
import time

# Add scripts directory to path so we can import klipper_interface
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from klipper_interface import KlipperInterface


def wind_coil(klipper, layers=10, start_y=38.0, end_y=50.0, e_per_layer=12.0, feedrate=336.0):
    """
    Wind a coil with alternating traverse direction
    
    Args:
        klipper: KlipperInterface instance
        layers: Number of layers to wind
        start_y: Starting Y position (mm)
        end_y: Ending Y position (mm)
        e_per_layer: Extruder movement per layer (mm)
        feedrate: Feedrate for winding moves (mm/min)
    """
    print(f"Winding {layers} layers...")
    
    # Home and reset
    print("Homing Y axis...")
    if not klipper.send_gcode("G28 Y"):
        print("ERROR: Homing failed!")
        return False
    
    print("Resetting extruder position...")
    klipper.send_gcode("G92 E0")
    
    # Move to start position
    print(f"Moving to start position Y{start_y}...")
    klipper.send_gcode(f"G1 Y{start_y} F1000")
    time.sleep(0.5)  # Wait for move to complete
    
    # Wind layers
    for layer in range(layers):
        e_pos = e_per_layer * (layer + 1)
        if layer % 2 == 0:
            # Forward direction
            print(f"Layer {layer + 1}/{layers}: Y{end_y} E{e_pos:.1f}")
            klipper.send_gcode(f"G1 Y{end_y} E{e_pos} F{feedrate}")
        else:
            # Reverse direction
            print(f"Layer {layer + 1}/{layers}: Y{start_y} E{e_pos:.1f}")
            klipper.send_gcode(f"G1 Y{start_y} E{e_pos} F{feedrate}")
        
        # Wait for move to complete (rough estimate)
        time.sleep(0.5)
    
    # Return to start
    print(f"Returning to start position Y{start_y}...")
    klipper.send_gcode(f"G1 Y{start_y} F1000")
    
    print("Winding complete!")
    return True


def get_status(klipper):
    """Get current winder status"""
    status = klipper.query_objects({
        "toolhead": ["position", "homed_axes", "status"],
        "winder": None  # Get all winder status fields
    })
    
    if status:
        pos = status.get("toolhead", {}).get("position", [0, 0, 0, 0])
        print(f"Position: Y={pos[1]:.2f}mm, E={pos[3]:.2f}mm")
        
        winder_status = status.get("winder", {})
        if winder_status:
            print(f"Winder Status: {winder_status}")
    
    return status


def main():
    import argparse
    
    parser = argparse.ArgumentParser(
        description="Winder Control Script",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Get current status
  python3 winder_control.py --status
  
  # Home Y axis
  python3 winder_control.py --home
  
  # Wind 10 layers
  python3 winder_control.py --wind --layers 10
  
  # Move to specific position
  python3 winder_control.py --move 45
  
  # Custom socket path
  python3 winder_control.py -s /tmp/printer --status
        """
    )
    
    parser.add_argument('-s', '--socket', default='/tmp/klippy_uds',
                       help='Unix socket path (default: /tmp/klippy_uds)')
    parser.add_argument('--home', action='store_true',
                       help='Home Y axis')
    parser.add_argument('--status', action='store_true',
                       help='Get current status')
    parser.add_argument('--wind', action='store_true',
                       help='Wind a coil')
    parser.add_argument('--layers', type=int, default=10,
                       help='Number of layers to wind (default: 10)')
    parser.add_argument('--start-y', type=float, default=38.0,
                       help='Start Y position (default: 38.0)')
    parser.add_argument('--end-y', type=float, default=50.0,
                       help='End Y position (default: 50.0)')
    parser.add_argument('--e-per-layer', type=float, default=12.0,
                       help='Extruder movement per layer (default: 12.0)')
    parser.add_argument('--feedrate', type=float, default=336.0,
                       help='Winding feedrate (default: 336.0)')
    parser.add_argument('--move', type=float, metavar='Y',
                       help='Move to Y position (mm)')
    parser.add_argument('--gcode', metavar='CMD',
                       help='Send custom G-code command')
    
    args = parser.parse_args()
    
    # Connect to Klipper
    klipper = KlipperInterface(args.socket)
    print(f"Connecting to {args.socket}...")
    if not klipper.connect():
        print("ERROR: Failed to connect to Klipper")
        print(f"Make sure Klipper is running and socket exists: {args.socket}")
        return 1
    
    try:
        # Execute commands
        if args.status:
            get_status(klipper)
        
        if args.home:
            print("Homing Y axis...")
            klipper.send_gcode("G28 Y")
            time.sleep(1)
            get_status(klipper)
        
        if args.move is not None:
            print(f"Moving to Y{args.move}...")
            klipper.send_gcode(f"G1 Y{args.move} F1000")
            time.sleep(0.5)
            get_status(klipper)
        
        if args.gcode:
            print(f"Sending: {args.gcode}")
            result = klipper.send_gcode(args.gcode)
            print(f"Result: {result}")
        
        if args.wind:
            wind_coil(klipper, args.layers, args.start_y, args.end_y,
                     args.e_per_layer, args.feedrate)
            get_status(klipper)
        
        # If no commands specified, show help
        if not (args.status or args.home or args.wind or args.move or args.gcode):
            parser.print_help()
    
    except KeyboardInterrupt:
        print("\nInterrupted by user")
        return 1
    except Exception as e:
        print(f"ERROR: {e}")
        import traceback
        traceback.print_exc()
        return 1
    finally:
        klipper.disconnect()
    
    return 0


if __name__ == "__main__":
    sys.exit(main())

