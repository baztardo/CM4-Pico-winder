# Traverse Control Module
#
# Copyright (C) 2024
#
# This file may be distributed under the terms of the GNU GPLv3 license.
import logging

class Traverse:
    """Traverse stepper control and coordination"""
    
    def __init__(self, config):
        self.printer = config.get_printer()
        self.name = config.get_name()
        
        # Stepper configuration
        self.stepper_name = config.get('stepper', 'stepper_y')
        
        # Traverse parameters
        self.max_position = config.getfloat('max_position', 93.0, above=0.0)
        self.home_offset = config.getfloat('home_offset', 2.0, minval=0.0)
        
        # State
        self.stepper = None
        self.toolhead = None
        self.current_position = 0.0
        self.is_homed = False
        
        # Register event handlers
        self.printer.register_event_handler("klippy:connect", self.handle_connect)
        
        # Register G-code commands
        gcode = self.printer.lookup_object('gcode')
        gcode.register_command("TRAVERSE_MOVE", self.cmd_TRAVERSE_MOVE,
                               desc=self.cmd_TRAVERSE_MOVE_help)
        gcode.register_command("TRAVERSE_HOME", self.cmd_TRAVERSE_HOME,
                               desc=self.cmd_TRAVERSE_HOME_help)
        gcode.register_command("QUERY_TRAVERSE", self.cmd_QUERY_TRAVERSE,
                               desc=self.cmd_QUERY_TRAVERSE_help)
    
    def handle_connect(self):
        """Setup traverse stepper when MCU connects"""
        # Get toolhead
        self.toolhead = self.printer.lookup_object('toolhead')
        
        logging.info("Traverse '%s' initialized - stepper: %s, max: %.2fmm" %
                    (self.name, self.stepper_name, self.max_position))
    
    def check_homed(self):
        """Check if Y axis is homed using kinematics status"""
        if not self.toolhead:
            return False
        
        kin = self.toolhead.get_kinematics()
        try:
            status = kin.get_status(self.printer.get_reactor().monotonic())
            homed_axes = status.get('homed_axes', '')
            is_homed = 'y' in homed_axes
            if is_homed != self.is_homed:
                self.is_homed = is_homed
                if is_homed:
                    logging.info("Traverse '%s' detected homed" % self.name)
            return is_homed
        except Exception as e:
            logging.warning("Traverse: Error checking homed status: %s" % e)
            return False
    
    def home(self):
        """Home the traverse"""
        if not self.toolhead:
            logging.error("Traverse: Toolhead not available")
            return False
        
        gcode = self.printer.lookup_object('gcode')
        gcode.run_script_from_command("G28 Y")
        return True
    
    def move_to(self, position, speed=None):
        """Move traverse to absolute position"""
        if not self.toolhead:
            logging.error("Traverse: Toolhead not available")
            return False
        
        # Check if homed
        if not self.check_homed():
            logging.error("Traverse: Must home first (G28 Y)")
            return False
        
        # Clamp position
        position = max(0.0, min(position, self.max_position))
        
        # Use manual_move for better performance
        self.toolhead.manual_move([None, position, None, None], speed or self.toolhead.max_velocity)
        self.current_position = position
        return True
    
    def move_relative(self, distance, speed=None):
        """Move traverse relative distance"""
        if not self.toolhead:
            return False
        
        current_pos = self.toolhead.get_position()[1]
        target_pos = current_pos + distance
        return self.move_to(target_pos, speed)
    
    def get_position(self):
        """Get current position"""
        if self.toolhead:
            return self.toolhead.get_position()[1]
        return self.current_position
    
    def get_status(self, eventtime):
        """Get status for API"""
        return {
            'position': self.get_position(),
            'max_position': self.max_position,
            'homed': self.is_homed,
            'stepper': self.stepper_name,
        }
    
    # G-code commands
    cmd_TRAVERSE_MOVE_help = "Move traverse to position"
    def cmd_TRAVERSE_MOVE(self, gcmd):
        position = gcmd.get_float('POSITION', minval=0.0, maxval=self.max_position)
        speed = gcmd.get_float('SPEED', None, above=0.0)
        
        if self.move_to(position, speed):
            gcmd.respond_info("Traverse moved to %.2fmm" % position)
        else:
            gcmd.respond_info("ERROR: Failed to move traverse")
    
    cmd_TRAVERSE_HOME_help = "Home traverse"
    def cmd_TRAVERSE_HOME(self, gcmd):
        if self.home():
            gcmd.respond_info("Traverse homed")
        else:
            gcmd.respond_info("ERROR: Failed to home traverse")
    
    cmd_QUERY_TRAVERSE_help = "Query traverse status"
    def cmd_QUERY_TRAVERSE(self, gcmd):
        status = self.get_status(None)
        gcmd.respond_info("Traverse '%s':" % self.name)
        gcmd.respond_info("  Position: %.2f / %.2f mm" % (status['position'], status['max_position']))
        gcmd.respond_info("  Homed: %s" % status['homed'])
        gcmd.respond_info("  Stepper: %s" % status['stepper'])

def load_config(config):
    return Traverse(config)

def load_config_prefix(config):
    # For [traverse main] style sections
    return Traverse(config)

