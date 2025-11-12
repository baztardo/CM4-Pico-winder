#!/usr/bin/env python3
"""
Klipper Interface - Direct webhooks communication
Based on Klipper's whconsole.py and webhooks.py architecture
"""
import socket
import json
import time
import sys
import os
import errno
import fcntl
import select
from typing import Dict, Any, Optional, Callable


class KlipperInterface:
    """
    Direct interface to Klipper via Unix domain socket.
    Implements webhooks protocol from klippy/webhooks.py
    """
    
    def __init__(self, uds_path: str = "/tmp/klippy_uds"):
        """
        Args:
            uds_path: Path to Klipper's Unix domain socket
                     Default from klippy/klippy.py --api-server arg
        """
        self.uds_path = uds_path
        self.sock: Optional[socket.socket] = None
        self.socket_data = b""
        self.request_id = 0
        self.pending_responses: Dict[int, Any] = {}
        self.last_error: Optional[str] = None
        
    def _set_nonblock(self, fd: int):
        """Set file descriptor non-blocking (from klippy/util.py)"""
        fcntl.fcntl(fd, fcntl.F_SETFL,
                   fcntl.fcntl(fd, fcntl.F_GETFL) | os.O_NONBLOCK)
    
    def connect(self, timeout: float = 10.0) -> bool:
        """
        Connect to Klipper's Unix socket.
        Pattern from scripts/whconsole.py::webhook_socket_create()
        
        Returns:
            True if connected successfully
        """
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.setblocking(0)
        
        start_time = time.time()
        while time.time() - start_time < timeout:
            try:
                self.sock.connect(self.uds_path)
                print(f"Connected to {self.uds_path}")
                return True
            except socket.error as e:
                if e.errno == errno.ECONNREFUSED:
                    time.sleep(0.1)
                    continue
                elif e.errno == errno.EISCONN:
                    # Already connected
                    return True
                else:
                    print(f"Connection error: {e}")
                    return False
        
        print(f"Connection timeout after {timeout}s")
        return False
    
    def _read_response(self, timeout: Optional[float] = None) -> Optional[Dict]:
        """
        Read response from socket.
        Protocol: JSON messages separated by \x03 (from klippy/webhooks.py)
        """
        if not self.sock:
            return None
        
        # Use instance timeout if set, otherwise use parameter
        if timeout is None:
            timeout = getattr(self, '_read_timeout', 5.0)
        
        poll = select.poll()
        poll.register(self.sock, select.POLLIN)
        
        end_time = time.time() + timeout
        while time.time() < end_time:
            ready = poll.poll(100)  # 100ms poll interval
            if not ready:
                continue
                
            try:
                data = self.sock.recv(4096)
            except socket.error:
                return None
                
            if not data:
                print("Socket closed by server")
                return None
            
            # Process received data (pattern from whconsole.py)
            parts = data.split(b'\x03')
            parts[0] = self.socket_data + parts[0]
            self.socket_data = parts.pop()
            
            for msg in parts:
                if msg:
                    try:
                        response = json.loads(msg)
                        # Check if this response matches our request ID
                        # (for now, just return the first valid JSON response)
                        return response
                    except json.JSONDecodeError as e:
                        print(f"JSON decode error: {e}")
                        continue
        
        return None
    
    def send_webhook(self, method: str, params: Optional[Dict] = None) -> Optional[Dict]:
        """
        Send webhook request and wait for response.
        Protocol from klippy/webhooks.py::WebRequest
        
        Args:
            method: Webhook endpoint (e.g., "gcode/script", "objects/query")
            params: Optional parameters dict
            
        Returns:
            Response dict or None on error
        """
        if not self.sock:
            print("Not connected")
            return None
        
        self.request_id += 1
        request = {
            "id": self.request_id,
            "method": method,
            "params": params or {}
        }
        
        # Send request (pattern from whconsole.py)
        msg = json.dumps(request, separators=(',', ':')).encode() + b'\x03'
        try:
            self.sock.send(msg)
        except socket.error as e:
            print(f"Send error: {e}")
            return None
        
        # Wait for response (use instance timeout if set)
        timeout = getattr(self, '_read_timeout', None)
        return self._read_response(timeout)
    
    def send_gcode(self, gcode: str, timeout: float = 30.0) -> bool:
        """
        Send G-code command(s) to Klipper.
        Uses gcode/script endpoint (klippy/webhooks.py::GCodeHelper)
        
        Args:
            gcode: G-code string (can be multiple lines)
            timeout: Timeout in seconds (default 30, longer for homing)
            
        Returns:
            True if sent successfully, False on error
        """
        # Use longer timeout for homing commands
        if "G28" in gcode.upper():
            timeout = 60.0
        
        # Temporarily override timeout for this call
        old_timeout = getattr(self, '_read_timeout', 5.0)
        self._read_timeout = timeout
        try:
            response = self.send_webhook("gcode/script", {"script": gcode})
        finally:
            self._read_timeout = old_timeout
        
        # Response format: {"id": 1, "result": {}} on success (empty dict is OK)
        # or {"id": 1, "error": {...}} on error
        if response:
            if "error" in response:
                # Error occurred - store error message for retrieval
                error_info = response["error"]
                error_msg = error_info.get("message", str(error_info))
                self.last_error = error_msg
                return False
            # Success if we have "result" key (even if empty)
            if "result" in response:
                self.last_error = None
                return True
        self.last_error = "No response from Klipper"
        return False
    
    def get_printer_info(self) -> Optional[Dict]:
        """Get printer info (klippy/webhooks.py::info endpoint)"""
        response = self.send_webhook("info")
        if response and "result" in response:
            return response["result"]
        return None
    
    def get_objects_list(self) -> Optional[list]:
        """Get list of available printer objects"""
        response = self.send_webhook("objects/list")
        if response and "result" in response:
            result = response["result"]
            # Result is a dict with "objects" key
            if isinstance(result, dict):
                return result.get("objects", [])
            elif isinstance(result, list):
                return result
        return None
    
    def query_objects(self, objects: Dict[str, Optional[list]], timeout: float = 5.0) -> Optional[Dict]:
        """
        Query printer object status.
        From klippy/webhooks.py::QueryStatusHelper
        
        Args:
            objects: Dict of {object_name: [field_list]} or {object_name: None} for all fields
            Example: {"toolhead": ["position", "status"], "heater_bed": None}
            timeout: Timeout in seconds
            
        Returns:
            Status dict
        """
        # Temporarily override timeout for this call
        old_timeout = getattr(self, '_read_timeout', 5.0)
        self._read_timeout = timeout
        try:
            response = self.send_webhook("objects/query", {"objects": objects})
        finally:
            self._read_timeout = old_timeout
        
        if response and "result" in response:
            result = response["result"]
            # Result is a dict with "status" key containing the object statuses
            if isinstance(result, dict):
                return result.get("status", result)
            return result
        return None
    
    def emergency_stop(self) -> bool:
        """Trigger emergency stop"""
        response = self.send_webhook("emergency_stop")
        return response is not None
    
    def restart(self) -> bool:
        """Restart Klipper host software"""
        return self.send_gcode("RESTART")
    
    def firmware_restart(self) -> bool:
        """Restart MCU firmware"""
        return self.send_gcode("FIRMWARE_RESTART")
    
    def get_gcode_help(self) -> Optional[Dict]:
        """Get available G-code commands and help"""
        response = self.send_webhook("gcode/help")
        if response and "result" in response:
            return response["result"]
        return None
    
    def disconnect(self):
        """Close connection"""
        if self.sock:
            try:
                self.sock.close()
            except:
                pass
            self.sock = None


# Command-line interface
def interactive_mode(klipper: KlipperInterface):
    """Interactive command shell"""
    print("\nKlipper Interface - Interactive Mode")
    print("Commands:")
    print("  gcode <command>  - Send G-code")
    print("  info            - Get printer info")
    print("  objects         - List available objects")
    print("  query <obj>     - Query object status")
    print("  estop           - Emergency stop")
    print("  quit            - Exit")
    print()
    
    while True:
        try:
            line = input(">>> ").strip()
            if not line:
                continue
            
            parts = line.split(maxsplit=1)
            cmd = parts[0].lower()
            args = parts[1] if len(parts) > 1 else ""
            
            if cmd == "quit" or cmd == "exit":
                break
            elif cmd == "gcode":
                if args:
                    result = klipper.send_gcode(args)
                    if result:
                        print(f"Result: True (command sent successfully)")
                    else:
                        print(f"Result: False")
                        if klipper.last_error:
                            print(f"Error: {klipper.last_error}")
                        else:
                            # Show raw response for debugging
                            response = klipper.send_webhook("gcode/script", {"script": args})
                            if response:
                                print(f"Response: {json.dumps(response, indent=2)}")
                else:
                    print("Usage: gcode <command>")
            elif cmd == "info":
                info = klipper.get_printer_info()
                if info:
                    print(json.dumps(info, indent=2))
                else:
                    print("No info returned")
                    # Debug: show raw response
                    response = klipper.send_webhook("info")
                    print(f"Raw response: {json.dumps(response, indent=2)}")
            elif cmd == "objects":
                objects = klipper.get_objects_list()
                if objects is not None:
                    print(json.dumps(objects, indent=2))
                else:
                    print("No objects returned")
                    # Debug: show raw response
                    response = klipper.send_webhook("objects/list")
                    print(f"Raw response: {json.dumps(response, indent=2)}")
            elif cmd == "query":
                if args:
                    # Query single object with all fields
                    status = klipper.query_objects({args: None}, timeout=10.0)
                    if status:
                        # Status is a dict with object names as keys
                        if args in status:
                            print(json.dumps(status[args], indent=2))
                        else:
                            # Show all returned status
                            print(json.dumps(status, indent=2))
                    else:
                        print("No status returned")
                        # Debug: show raw response
                        response = klipper.send_webhook("objects/query", {"objects": {args: None}})
                        print(f"Raw response: {json.dumps(response, indent=2)}")
                else:
                    print("Usage: query <object_name>")
            elif cmd == "estop":
                result = klipper.emergency_stop()
                print(f"Emergency stop: {result}")
            else:
                print(f"Unknown command: {cmd}")
                
        except KeyboardInterrupt:
            print("\nInterrupted")
            break
        except EOFError:
            break
        except Exception as e:
            print(f"Error: {e}")


def main():
    import argparse
    parser = argparse.ArgumentParser(
        description="Klipper Interface - Send G-code and commands",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Interactive mode
  python3 klipper_interface.py -i
  
  # Send single G-code command
  python3 klipper_interface.py -g "G28 Y"
  
  # Send multiple G-code commands
  python3 klipper_interface.py -g "G28 Y" -g "G1 Y50 F1000"
  
  # Get printer info
  python3 klipper_interface.py --info
  
  # Query toolhead position
  python3 klipper_interface.py --query toolhead
  
  # Custom socket path
  python3 klipper_interface.py -s /tmp/klippy_uds -i
        """
    )
    parser.add_argument('-s', '--socket', default='/tmp/klippy_uds',
                       help='Unix socket path (default: /tmp/klippy_uds)')
    parser.add_argument('-i', '--interactive', action='store_true',
                       help='Interactive mode')
    parser.add_argument('-g', '--gcode', action='append',
                       help='Send G-code command (can be used multiple times)')
    parser.add_argument('--info', action='store_true',
                       help='Get printer info')
    parser.add_argument('--objects', action='store_true',
                       help='List available objects')
    parser.add_argument('--query', metavar='OBJECT',
                       help='Query object status')
    parser.add_argument('--estop', action='store_true',
                       help='Emergency stop')
    
    args = parser.parse_args()
    
    # Connect to Klipper
    klipper = KlipperInterface(args.socket)
    if not klipper.connect():
        print("Failed to connect to Klipper")
        return 1
    
    try:
        # Execute commands
        if args.info:
            info = klipper.get_printer_info()
            print(json.dumps(info, indent=2))
        
        if args.objects:
            objects = klipper.get_objects_list()
            print(json.dumps(objects, indent=2))
        
        if args.query:
            status = klipper.query_objects({args.query: None})
            print(json.dumps(status, indent=2))
        
        if args.gcode:
            for cmd in args.gcode:
                print(f"Sending: {cmd}")
                result = klipper.send_gcode(cmd)
                print(f"Result: {result}")
        
        if args.estop:
            print("Emergency stop...")
            klipper.emergency_stop()
        
        # Interactive mode
        if args.interactive:
            interactive_mode(klipper)
        
        # If no commands specified, show help
        if not (args.interactive or args.info or args.objects or 
                args.query or args.gcode or args.estop):
            parser.print_help()
    
    finally:
        klipper.disconnect()
    
    return 0


if __name__ == "__main__":
    sys.exit(main())
