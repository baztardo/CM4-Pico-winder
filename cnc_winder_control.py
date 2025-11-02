# Simple CNC Winder Controller
# No GUI, just motor control

import serial
import time
import sys

class CNCWinder:
    def __init__(self, port='/dev/ttyACM0'):
        self.port = port
        self.serial = None
        
    def connect(self):
        try:
            self.serial = serial.Serial(self.port, 115200, timeout=1)
            print(f"Connected to Pico on {self.port}")
            return True
        except:
            print(f"Failed to connect to {self.port}")
            return False
    
    def send_cmd(self, cmd):
        if self.serial:
            self.serial.write(f"{cmd}
".encode())
            time.sleep(0.01)  # Small delay
            if self.serial.in_waiting:
                return self.serial.readline().decode().strip()
        return None
    
    def wind_pickup(self, turns=10, speed=500):
        """Wind pickup coil"""
        print(f"Winding {turns} turns at speed {speed}")
        
        for turn in range(turns):
            # Move stepper motor
            self.send_cmd(f"stepper_move D360 F{speed}")
            
            # Read encoder feedback
            encoder_pos = self.send_cmd("encoder_read")
            print(f"Turn {turn+1}/{turns}, Encoder: {encoder_pos}")
            
            time.sleep(0.1)  # Delay between turns
        
        print("Winding complete!")
    
    def calibrate(self):
        """Calibrate pickup position"""
        print("Calibrating...")
        self.send_cmd("home_pickup")
        pos = self.send_cmd("get_position")
        print(f"Homed position: {pos}")
    
    def emergency_stop(self):
        """Stop everything"""
        self.send_cmd("emergency_stop")
        print("EMERGENCY STOP")

# Simple command line interface
if __name__ == "__main__":
    winder = CNCWinder()
    
    if not winder.connect():
        sys.exit(1)
    
    print("CNC Pickup Winder Controller")
    print("Commands: wind, calibrate, stop, quit")
    
    while True:
        cmd = input("> ").strip().lower()
        
        if cmd == "wind":
            turns = int(input("Turns: ") or "10")
            speed = int(input("Speed: ") or "500")
            winder.wind_pickup(turns, speed)
            
        elif cmd == "calibrate":
            winder.calibrate()
            
        elif cmd == "stop":
            winder.emergency_stop()
            
        elif cmd == "quit":
            break
            
        else:
            print("Unknown command")
    
    print("Goodbye!")
