#!/usr/bin/env python3
"""
Generate G-code files for winding operations
"""
import argparse
import math

def generate_winding_gcode(rpm, layers, wire_diameter, wire_coating, bobbin_width, 
                           spindle_edge, output_file):
    """Generate complete G-code file for winding operation"""
    
    # Calculate parameters
    effective_wire_dia = wire_diameter + wire_coating
    traverse_speed_mm_s = rpm * effective_wire_dia / 60.0  # mm/s
    traverse_speed_mm_min = traverse_speed_mm_s * 60.0  # mm/min for F parameter
    
    start_y = spindle_edge
    end_y = spindle_edge + bobbin_width
    
    # Calculate time per pass (for progress estimation)
    time_per_pass = bobbin_width / traverse_speed_mm_s
    
    lines = []
    
    # Header
    lines.append("; Winding G-code")
    lines.append(f"; RPM: {rpm}")
    lines.append(f"; Layers: {layers}")
    lines.append(f"; Wire: {wire_diameter:.4f}mm + {wire_coating:.4f}mm coating = {effective_wire_dia:.4f}mm")
    lines.append(f"; Bobbin width: {bobbin_width:.3f}mm")
    lines.append(f"; Traverse speed: {traverse_speed_mm_s:.4f} mm/s ({traverse_speed_mm_min:.1f} mm/min)")
    lines.append(f"; Time per layer: ~{time_per_pass:.1f} seconds")
    lines.append(f"; Total time: ~{time_per_pass * layers:.1f} seconds")
    lines.append("")
    
    # Initial setup
    lines.append("; === SETUP ===")
    lines.append("G90  ; Absolute positioning")
    lines.append("M83  ; Relative extruder (not used, but standard)")
    lines.append("")
    
    # Home and calibrate
    lines.append("; === HOMING AND CALIBRATION ===")
    lines.append("M117 Calibrating spindle...")
    lines.append("CALIBRATE_SPINDLE")
    lines.append("M117 Homing traverse...")
    lines.append("HOME_TRAVERSE")
    lines.append("G4 P500  ; Wait 500ms for settling")
    lines.append("")
    
    # Start winding
    lines.append("; === START WINDING ===")
    lines.append(f"M117 Starting winding at {rpm} RPM...")
    lines.append(f"WINDER_START RPM={rpm} LAYERS=0  ; Start motor only, no traverse")
    lines.append("G4 P1000  ; Wait 1 second for motor to stabilize")
    lines.append("")
    
    # Generate traverse moves for each layer
    for layer in range(layers):
        direction = "FORWARD" if layer % 2 == 0 else "BACKWARD"
        target_y = end_y if layer % 2 == 0 else start_y
        
        lines.append(f"; === LAYER {layer + 1}/{layers} - {direction} ===")
        lines.append(f"M117 Layer {layer + 1}/{layers} - {direction}")
        
        # Set acceleration for this move
        lines.append(f"M204 S300  ; Set acceleration to 300 mm/s²")
        
        # Execute traverse move
        lines.append(f"G1 Y{target_y:.3f} F{traverse_speed_mm_min:.1f}  ; Traverse to Y{target_y:.3f}")
        
        # Optional: Add a small dwell between layers to ensure full stop
        if layer < layers - 1:  # Don't dwell after last layer
            lines.append("G4 P100  ; Dwell 100ms between layers")
        
        lines.append("")
    
    # Stop winding
    lines.append("; === STOP WINDING ===")
    lines.append("M117 Winding complete!")
    lines.append("WINDER_STOP")
    lines.append("M117 Done")
    lines.append("")
    
    # Write to file
    with open(output_file, 'w') as f:
        f.write('\n'.join(lines))
    
    print(f"Generated winding G-code: {output_file}")
    print(f"  RPM: {rpm}")
    print(f"  Layers: {layers}")
    print(f"  Traverse speed: {traverse_speed_mm_min:.1f} mm/min")
    print(f"  Estimated time: {time_per_pass * layers:.1f} seconds")

def main():
    parser = argparse.ArgumentParser(description='Generate winding G-code files')
    parser.add_argument('--rpm', type=float, required=True, help='Spindle RPM')
    parser.add_argument('--layers', type=int, required=True, help='Number of layers')
    parser.add_argument('--wire-diameter', type=float, default=0.056, help='Bare wire diameter (mm)')
    parser.add_argument('--wire-coating', type=float, default=0.016, help='Wire coating thickness (mm)')
    parser.add_argument('--bobbin-width', type=float, default=6.35, help='Bobbin width (mm)')
    parser.add_argument('--spindle-edge', type=float, default=43.0, help='Spindle edge offset (mm)')
    parser.add_argument('--output', type=str, required=True, help='Output G-code file')
    
    args = parser.parse_args()
    
    generate_winding_gcode(
        rpm=args.rpm,
        layers=args.layers,
        wire_diameter=args.wire_diameter,
        wire_coating=args.wire_coating,
        bobbin_width=args.bobbin_width,
        spindle_edge=args.spindle_edge,
        output_file=args.output
    )

if __name__ == '__main__':
    main()

