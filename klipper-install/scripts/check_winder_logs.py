#!/usr/bin/env python3
"""
Check Winder Logs - Show recent winder-related log entries
"""
import subprocess
import sys

def check_logs(lines=50):
    """Check recent winder logs"""
    print("\n" + "="*60)
    print(f"RECENT WINDER LOGS (last {lines} lines)")
    print("="*60)
    
    try:
        # Get recent winder logs
        result = subprocess.run(
            ['tail', '-n', str(lines), '/tmp/klippy.log'],
            capture_output=True,
            text=True
        )
        
        if result.returncode == 0:
            lines_output = result.stdout
            # Filter for winder-related lines
            winder_lines = [line for line in lines_output.split('\n') if 'winder' in line.lower() or 'motor' in line.lower() or 'pwm' in line.lower()]
            
            if winder_lines:
                for line in winder_lines[-30:]:  # Show last 30 winder lines
                    print(line)
            else:
                print("No winder-related log entries found")
                print("\nFull recent logs:")
                print(lines_output[-500:])  # Show last 500 chars
        else:
            print(f"Error reading logs: {result.stderr}")
            
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    lines = int(sys.argv[1]) if len(sys.argv) > 1 else 50
    check_logs(lines)

