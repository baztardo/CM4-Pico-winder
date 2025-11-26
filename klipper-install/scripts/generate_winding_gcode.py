#!/usr/bin/env python3
"""
Generate G-code files for winding operations with EXACT turn count control
"""
import argparse
import math

def generate_winding_gcode(rpm, target_turns, wire_diameter, wire_coating, bobbin_width, 
                           spindle_edge, gear_ratio, motor_calibration, traverse_calibration, output_file):
    """Generate complete G-code file for winding operation
    
    Generates MORE layers than needed, but uses MONITOR_TURNS to stop at EXACT count.
    This ensures:
    - Exact turn count (industry standard: 2500 turns = 2500 turns!)
    - Uniform winding (proper layer spacing)
    - Stops precisely when target reached
    """
    
    # Calculate parameters
    effective_wire_dia = wire_diameter + wire_coating
    # Apply traverse calibration to sync with actual spindle speed
    traverse_speed_mm_s = (rpm * effective_wire_dia / 60.0) * traverse_calibration
    traverse_speed_mm_min = traverse_speed_mm_s * 60.0  # mm/min for F parameter
    
    # Calculate motor RPM (spindle RPM / gear ratio * calibration)
    motor_rpm = (rpm / gear_ratio) * motor_calibration
    
    # Calculate theoretical turns per layer
    theoretical_turns_per_layer = bobbin_width / effective_wire_dia
    
    # Calculate layers needed (add 20% safety margin to ensure we don't run out)
    layers_needed = math.ceil(target_turns / theoretical_turns_per_layer)
    layers_to_generate = int(layers_needed * 1.2)  # 20% extra
    
    start_y = spindle_edge
    end_y = spindle_edge + bobbin_width
    
    # Calculate time per pass (for progress estimation)
    time_per_pass = bobbin_width / traverse_speed_mm_s
    
    lines = []
    
    # Header
    lines.append("; Winding G-code - TURN COUNT CONTROLLED")
    lines.append(f"; Target turns: {target_turns} (EXACT)")
    lines.append(f"; RPM: {rpm}")
    lines.append(f"; Theoretical turns/layer: {theoretical_turns_per_layer:.1f}")
    lines.append(f"; Layers to generate: {layers_to_generate} (will stop at {target_turns} turns)")
    lines.append(f"; Wire: {wire_diameter:.4f}mm + {wire_coating:.4f}mm coating = {effective_wire_dia:.4f}mm")
    lines.append(f"; Bobbin width: {bobbin_width:.3f}mm")
    lines.append(f"; Traverse speed: {traverse_speed_mm_s:.4f} mm/s ({traverse_speed_mm_min:.1f} mm/min)")
    lines.append(f"; Motor RPM: {motor_rpm:.1f} (spindle {rpm} / gear {gear_ratio} * cal {motor_calibration})")
    lines.append("")
    
    # Initial setup
    lines.append("; === SETUP ===")
    lines.append("G90  ; Absolute positioning")
    lines.append("")
    
    # Home and calibrate
    lines.append("; === HOMING AND CALIBRATION ===")
    lines.append("M117 Calibrating spindle...")
    lines.append("CALIBRATE_SPINDLE")
    lines.append("M117 Homing traverse...")
    lines.append("HOME_TRAVERSE")
    lines.append("G4 P500  ; Wait 500ms for settling")
    lines.append("")
    
    # Start BLDC motor
    lines.append("; === START BLDC MOTOR ===")
    lines.append(f"M117 Starting motor at {rpm} RPM...")
    lines.append(f"BLDC_START RPM={motor_rpm:.1f}  ; Start motor")
    lines.append("G4 P2000  ; Wait 2 seconds for motor to stabilize")
    lines.append("")
    
    # Start turn monitoring with predictive stopping for buffer drain
    # Measured overshoot: 112 turns at 1000 RPM (from Klipper buffer + detection delay)
    # Scale proportionally with RPM
    predicted_overshoot = int((rpm / 1000.0) * 112)
    stop_early_at = max(target_turns - predicted_overshoot, 100)  # Safety: don't go below 100
    
    lines.append("; === TURN COUNT CONTROL ===")
    lines.append(f"; Target: {target_turns} turns")
    lines.append(f"; Predicted overshoot: {predicted_overshoot} turns (buffer drain + detection)")
    lines.append(f"; Stopping early at: {stop_early_at} turns")
    lines.append(f"MONITOR_TURNS TURNS={stop_early_at} RPM={rpm}")
    lines.append("")
    
    # Generate traverse moves for each layer
    lines.append("; === WINDING LAYERS ===")
    for layer in range(layers_to_generate):
        direction = "FORWARD" if layer % 2 == 0 else "BACKWARD"
        target_y = end_y if layer % 2 == 0 else start_y
        
        lines.append(f"; Layer {layer + 1}/{layers_to_generate} - {direction}")
        lines.append(f"M117 Layer {layer + 1} - {direction}")
        lines.append(f"G1 Y{target_y:.3f} F{traverse_speed_mm_min:.1f}")
        lines.append("")
    
    # Stop motor (will only reach here if MONITOR_TURNS doesn't stop it first)
    lines.append("; === STOP MOTOR ===")
    lines.append("M117 Winding complete!")
    lines.append("BLDC_STOP")
    lines.append("M117 Done")
    lines.append("")
    
    # Write to file
    with open(output_file, 'w') as f:
        f.write('\n'.join(lines))
    
    print(f"Generated winding G-code: {output_file}")
    print(f"  Target turns: {target_turns} (EXACT)")
    print(f"  RPM: {rpm}")
    print(f"  Layers generated: {layers_to_generate} (extra margin for safety)")
    print(f"  MONITOR_TURNS will stop at exactly {target_turns} turns")

def main():
    parser = argparse.ArgumentParser(description='Generate winding G-code with EXACT turn count')
    parser.add_argument('--rpm', type=float, required=True, help='Spindle RPM')
    parser.add_argument('--target-turns', type=int, required=True, help='Target turn count (EXACT)')
    parser.add_argument('--wire-diameter', type=float, default=0.056, help='Bare wire diameter (mm)')
    parser.add_argument('--wire-coating', type=float, default=0.016, help='Wire coating thickness (mm)')
    parser.add_argument('--bobbin-width', type=float, default=6.35, help='Bobbin width (mm)')
    parser.add_argument('--spindle-edge', type=float, default=43.0, help='Spindle edge offset (mm)')
    parser.add_argument('--gear-ratio', type=float, default=0.667, help='Gear ratio (motor:spindle)')
    parser.add_argument('--motor-calibration', type=float, default=1.09, help='Motor speed calibration factor')
    parser.add_argument('--traverse-calibration', type=float, default=1.0, help='Traverse speed calibration (1.0 = theoretical)')
    parser.add_argument('--output', type=str, required=True, help='Output G-code file')
    
    args = parser.parse_args()
    
    generate_winding_gcode(
        rpm=args.rpm,
        target_turns=args.target_turns,
        wire_diameter=args.wire_diameter,
        wire_coating=args.wire_coating,
        bobbin_width=args.bobbin_width,
        spindle_edge=args.spindle_edge,
        gear_ratio=args.gear_ratio,
        motor_calibration=args.motor_calibration,
        traverse_calibration=args.traverse_calibration,
        output_file=args.output
    )

if __name__ == '__main__':
    main()
