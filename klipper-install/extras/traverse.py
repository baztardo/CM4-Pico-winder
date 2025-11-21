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
        self.printer.register_event_handler("homing:home_rails_end", self.handle_home_end)
        
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
        # Lookup stepper
        try:
            self.stepper = self.printer.lookup_object(self.stepper_name)
        except Exception:
            logging.error("Traverse: Could not find stepper '%s'" % self.stepper_name)
            return
        
        # Get toolhead
        self.toolhead = self.printer.lookup_object('toolhead')
        
        logging.info("Traverse '%s' initialized - stepper: %s, max: %.2fmm" %
                    (self.name, self.stepper_name, self.max_position))
    
    def handle_home_end(self, homing_state, rails):
        """Called when homing completes"""
        # Check if our stepper was homed
        for rail in rails:
            for stepper in rail.get_steppers():
                if stepper.get_name() == self.stepper_name:
                    self.is_homed = True
                    self.current_position = self.toolhead.get_position()[1]  # Y position
                    logging.info("Traverse '%s' homed at position %.2fmm" %
                               (self.name, self.current_position))
                    return
    
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
        
        if not self.is_homed:
            logging.error("Traverse: Must home first (G28 Y)")
            return False
        
        # Clamp position
        position = max(0.0, min(position, self.max_position))
        
        # Get current position
        current_pos = self.toolhead.get_position()
        
        # Move Y axis
        gcode = self.printer.lookup_object('gcode')
        if speed:
            gcode.run_script_from_command("G1 Y%.3f F%.1f" % (position, speed))
        else:
            gcode.run_script_from_command("G1 Y%.3f" % position)
        
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

