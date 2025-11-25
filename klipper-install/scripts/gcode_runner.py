#!/usr/bin/env python3
"""
G-code File Runner for Klipper Winder
Parses and executes G-code files line-by-line with progress tracking
"""
import os
import time
import re
from typing import Optional, Callable, Dict, Any
from klipper_interface import KlipperInterface


class GCodeRunner:
    """Parse and execute G-code files with the winder system"""
    
    def __init__(self, klipper: KlipperInterface):
        """
        Args:
            klipper: Connected KlipperInterface instance
        """
        self.klipper = klipper
        self.current_file: Optional[str] = None
        self.current_line: int = 0
        self.total_lines: int = 0
        self.paused: bool = False
        self.aborted: bool = False
        
        # Callbacks for progress/status
        self.on_line_execute: Optional[Callable[[int, str], None]] = None
        self.on_progress: Optional[Callable[[int, int, float], None]] = None
        self.on_error: Optional[Callable[[str, str], None]] = None
        self.on_complete: Optional[Callable[[Dict[str, Any]], None]] = None
        
    def parse_file(self, filepath: str) -> list:
        """
        Parse G-code file and return list of executable lines.
        
        Handles:
        - Comment removal (lines starting with ;)
        - Inline comments (text after ;)
        - Empty lines
        - Line numbers (N prefix)
        - Checksums (* suffix)
        
        Args:
            filepath: Path to G-code file
            
        Returns:
            List of (line_num, command) tuples
        """
        if not os.path.exists(filepath):
            raise FileNotFoundError(f"G-code file not found: {filepath}")
        
        commands = []
        with open(filepath, 'r') as f:
            for line_num, line in enumerate(f, 1):
                # Strip whitespace
                line = line.strip()
                
                # Skip empty lines
                if not line:
                    continue
                
                # Skip full-line comments
                if line.startswith(';'):
                    continue
                
                # Remove inline comments
                if ';' in line:
                    line = line.split(';')[0].strip()
                
                # Remove line numbers (N prefix)
                if line.startswith('N'):
                    match = re.match(r'N\d+\s+(.*)', line)
                    if match:
                        line = match.group(1)
                
                # Remove checksums (* suffix)
                if '*' in line:
                    line = line.split('*')[0].strip()
                
                # Skip if nothing left after processing
                if not line:
                    continue
                
                commands.append((line_num, line))
        
        return commands
    
    def execute_file(self, filepath: str, 
                    dry_run: bool = False,
                    pause_on_error: bool = True) -> Dict[str, Any]:
        """
        Execute G-code file line-by-line.
        
        Args:
            filepath: Path to G-code file
            dry_run: If True, parse but don't execute
            pause_on_error: If True, pause on command errors
            
        Returns:
            Execution statistics dict
        """
        self.current_file = filepath
        self.current_line = 0
        self.paused = False
        self.aborted = False
        
        # Parse file
        try:
            commands = self.parse_file(filepath)
        except Exception as e:
            if self.on_error:
                self.on_error("parse", str(e))
            return {"success": False, "error": f"Parse error: {e}"}
        
        self.total_lines = len(commands)
        
        if dry_run:
            print(f"DRY RUN: Would execute {self.total_lines} commands from {filepath}")
            for line_num, cmd in commands:
                print(f"  Line {line_num}: {cmd}")
            return {"success": True, "dry_run": True, "commands": self.total_lines}
        
        # Execution statistics
        stats = {
            "file": filepath,
            "total_commands": self.total_lines,
            "executed": 0,
            "errors": 0,
            "skipped": 0,
            "start_time": time.time(),
            "end_time": None,
            "duration": None,
        }
        
        # Execute commands
        for line_num, cmd in commands:
            if self.aborted:
                stats["aborted"] = True
                break
            
            # Handle pause
            while self.paused and not self.aborted:
                time.sleep(0.1)
            
            self.current_line = line_num
            
            # Callback before execution
            if self.on_line_execute:
                self.on_line_execute(line_num, cmd)
            
            # Execute command
            try:
                success = self.klipper.send_gcode(cmd)
                if success:
                    stats["executed"] += 1
                else:
                    stats["errors"] += 1
                    error_msg = self.klipper.last_error or "Unknown error"
                    
                    if self.on_error:
                        self.on_error(cmd, error_msg)
                    
                    if pause_on_error:
                        print(f"\nError on line {line_num}: {cmd}")
                        print(f"Error: {error_msg}")
                        print("Paused. Type 'resume' to continue, 'abort' to stop.")
                        self.paused = True
            
            except Exception as e:
                stats["errors"] += 1
                if self.on_error:
                    self.on_error(cmd, str(e))
                
                if pause_on_error:
                    self.paused = True
            
            # Progress callback
            if self.on_progress:
                progress_pct = (stats["executed"] + stats["errors"]) / self.total_lines * 100
                self.on_progress(stats["executed"], self.total_lines, progress_pct)
        
        # Finalize stats
        stats["end_time"] = time.time()
        stats["duration"] = stats["end_time"] - stats["start_time"]
        stats["success"] = stats["errors"] == 0 and not stats.get("aborted", False)
        
        # Completion callback
        if self.on_complete:
            self.on_complete(stats)
        
        return stats
    
    def pause(self):
        """Pause execution"""
        self.paused = True
    
    def resume(self):
        """Resume execution"""
        self.paused = False
    
    def abort(self):
        """Abort execution"""
        self.aborted = True
        self.paused = False


class WindingSequence:
    """High-level winding sequence manager"""
    
    def __init__(self, klipper: KlipperInterface):
        self.klipper = klipper
        self.runner = GCodeRunner(klipper)
    
    def create_winding_gcode(self, 
                            rpm: float,
                            layers: int,
                            output_file: str,
                            home_first: bool = True,
                            calibrate: bool = True) -> str:
        """
        Generate a complete winding G-code file.
        
        Args:
            rpm: Spindle RPM
            layers: Number of layers to wind
            output_file: Path to save G-code file
            home_first: Home traverse before winding
            calibrate: Run spindle calibration
            
        Returns:
            Path to generated file
        """
        gcode_lines = [
            "; Winding Sequence",
            f"; RPM: {rpm}",
            f"; Layers: {layers}",
            f"; Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}",
            "",
        ]
        
        if home_first:
            gcode_lines.append("; Home traverse")
            if calibrate:
                gcode_lines.append("HOME_TRAVERSE  ; Includes automatic spindle calibration")
            else:
                gcode_lines.append("G28 Y")
                gcode_lines.append("G1 Y50 F50")
        
        gcode_lines.extend([
            "",
            "; Start winding",
            f"WINDER_START RPM={rpm} LAYERS={layers}",
            "",
            "; Winding complete",
            "M117 Winding complete",
        ])
        
        with open(output_file, 'w') as f:
            f.write('\n'.join(gcode_lines))
        
        return output_file
    
    def run_winding_sequence(self, rpm: float, layers: int, **kwargs) -> Dict[str, Any]:
        """
        Execute a complete winding sequence.
        
        Args:
            rpm: Spindle RPM
            layers: Number of layers
            **kwargs: Additional arguments for create_winding_gcode
            
        Returns:
            Execution statistics
        """
        # Generate G-code file
        temp_file = f"/tmp/winding_{int(time.time())}.gcode"
        gcode_file = self.create_winding_gcode(rpm, layers, temp_file, **kwargs)
        
        print(f"Generated winding sequence: {gcode_file}")
        print(f"RPM: {rpm}, Layers: {layers}")
        print()
        
        # Execute
        stats = self.runner.execute_file(gcode_file)
        
        # Cleanup temp file
        try:
            os.remove(gcode_file)
        except:
            pass
        
        return stats


# Command-line interface
def main():
    import argparse
    
    parser = argparse.ArgumentParser(description="G-code file runner for Klipper winder")
    parser.add_argument("file", nargs='?', help="G-code file to execute")
    parser.add_argument("--dry-run", action="store_true", help="Parse but don't execute")
    parser.add_argument("--uds", default="/tmp/klippy_uds", help="Klipper UDS path")
    parser.add_argument("--no-pause-on-error", action="store_true", help="Don't pause on errors")
    
    # Winding sequence options
    parser.add_argument("--winding", action="store_true", help="Generate and run winding sequence")
    parser.add_argument("--rpm", type=float, help="Spindle RPM for winding")
    parser.add_argument("--layers", type=int, help="Number of layers for winding")
    parser.add_argument("--no-home", action="store_true", help="Skip homing")
    parser.add_argument("--no-calibrate", action="store_true", help="Skip calibration")
    
    args = parser.parse_args()
    
    # Connect to Klipper
    klipper = KlipperInterface(args.uds)
    if not klipper.connect():
        print("ERROR: Could not connect to Klipper")
        return 1
    
    # Setup progress callbacks
    def on_line(line_num, cmd):
        print(f"[{line_num}] {cmd}")
    
    def on_progress(executed, total, pct):
        if executed % 10 == 0:  # Update every 10 commands
            print(f"Progress: {executed}/{total} ({pct:.1f}%)")
    
    def on_error(cmd, error):
        print(f"ERROR: {cmd}")
        print(f"  {error}")
    
    def on_complete(stats):
        print("\n" + "="*60)
        print("EXECUTION COMPLETE")
        print("="*60)
        print(f"File: {stats['file']}")
        print(f"Commands executed: {stats['executed']}/{stats['total_commands']}")
        print(f"Errors: {stats['errors']}")
        print(f"Duration: {stats['duration']:.1f}s")
        if stats.get('aborted'):
            print("Status: ABORTED")
        elif stats['success']:
            print("Status: SUCCESS")
        else:
            print("Status: FAILED")
        print("="*60)
    
    try:
        if args.winding:
            # Winding sequence mode
            if not args.rpm or not args.layers:
                print("ERROR: --rpm and --layers required for winding mode")
                return 1
            
            sequence = WindingSequence(klipper)
            sequence.runner.on_line_execute = on_line
            sequence.runner.on_progress = on_progress
            sequence.runner.on_error = on_error
            sequence.runner.on_complete = on_complete
            
            stats = sequence.run_winding_sequence(
                args.rpm, 
                args.layers,
                home_first=not args.no_home,
                calibrate=not args.no_calibrate
            )
            
            return 0 if stats['success'] else 1
        
        elif args.file:
            # File execution mode
            runner = GCodeRunner(klipper)
            runner.on_line_execute = on_line
            runner.on_progress = on_progress
            runner.on_error = on_error
            runner.on_complete = on_complete
            
            stats = runner.execute_file(
                args.file,
                dry_run=args.dry_run,
                pause_on_error=not args.no_pause_on_error
            )
            
            return 0 if stats['success'] else 1
        
        else:
            parser.print_help()
            return 1
    
    finally:
        klipper.disconnect()


if __name__ == "__main__":
    exit(main())

