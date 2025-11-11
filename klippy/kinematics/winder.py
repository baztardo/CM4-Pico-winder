# Code for handling the kinematics of CNC Winder
# Only Y-axis (traverse) is used
#
# Copyright (C) 2024
#
# This file may be distributed under the terms of the GNU GPLv3 license.
import logging
import stepper

class WinderKinematics:
    def __init__(self, toolhead, config):
        self.printer = config.get_printer()
        # Only Y-axis (traverse) stepper
        self.rail = stepper.LookupMultiRail(config.getsection('stepper_y'))
        self.rail.setup_itersolve('cartesian_stepper_alloc', b'y')
        self.rail.set_trapq(toolhead.get_trapq())
        
        # Get position range
        position_min, position_max = self.rail.get_range()
        self.axes_min = toolhead.Coord((0., position_min, 0., 0.))
        self.axes_max = toolhead.Coord((0., position_max, 0., 0.))
        
        # Setup limits (Y-axis only)
        self.limits = [(1.0, -1.0), (1.0, -1.0), (1.0, -1.0)]  # X, Y, Z
        self.set_position([0., 0., 0.], "")
    
    def get_steppers(self):
        return list(self.rail.get_steppers())
    
    def calc_position(self, stepper_positions):
        # Only Y-axis position matters
        y_pos = stepper_positions.get(self.rail.get_name(), 0.)
        return [0., y_pos, 0.]
    
    def set_position(self, newpos, homing_axes):
        self.rail.set_position(newpos)
        if 'y' in homing_axes:
            self.limits[1] = self.rail.get_range()
    
    def clear_homing_state(self, clear_axes):
        if 'y' in clear_axes:
            self.limits[1] = (1.0, -1.0)
    
    def _home_traverse(self, homing_state):
        """Home the traverse (Y-axis)"""
        import logging
        logging.info("DEBUG WINDER: _home_traverse called")
        
        position_min, position_max = self.rail.get_range()
        hi = self.rail.get_homing_info()
        
        # Get current stepper position (may be wrong if not homed, but better than assuming)
        try:
            current_pos = self.rail.get_commanded_position()
        except:
            current_pos = None
        
        logging.info("DEBUG WINDER: position_min=%.2f position_max=%.2f position_endstop=%.2f positive_dir=%s current_pos=%s" 
                    % (position_min, position_max, hi.position_endstop, hi.positive_dir, current_pos))
        
        # Determine homing move
        homepos = [None, hi.position_endstop, None, None]
        forcepos = [None, None, None, None]
        
        if hi.positive_dir:
            # Home towards positive direction (endstop at max)
            # Start from before endstop, move toward endstop
            if current_pos is not None and current_pos < hi.position_endstop:
                # Use current position + safety margin
                forcepos[1] = max(current_pos - 20.0, position_min - 10.0)
            else:
                # Default: start from before endstop
                forcepos[1] = hi.position_endstop - 1.5 * (hi.position_endstop - position_min)
        else:
            # Home towards negative direction (endstop at min, typical for traverse)
            # Calculate based on current position, but ensure we ALWAYS move far enough
            # The forcepos is where we START the homing move from
            safety_margin = 50.0  # Increased from 20mm to 50mm for timing bug
            min_forcepos = position_max + safety_margin  # Always ensure we can reach endstop
            
            if current_pos is not None:
                # Use current position if it's reasonable, but never less than min_forcepos
                if current_pos <= position_max:
                    # Stepper thinks it's at a valid position, but we need to ensure
                    # we move far enough to hit endstop from ANY actual position
                    # So use max(min_forcepos, current_pos + small_margin)
                    forcepos[1] = max(min_forcepos, current_pos + 10.0)
                else:
                    # Current position is invalid (e.g., 139.5mm), clamp aggressively
                    # Use a reasonable maximum that's not too long but still safe
                    max_reasonable = position_max + 50.0  # Increased from 30mm to 50mm
                    forcepos[1] = max(min_forcepos, min(current_pos, max_reasonable))
            else:
                # Can't get current position, use min_forcepos
                forcepos[1] = min_forcepos
            
            # Final clamp: never exceed 1.5x max (absolute safety limit)
            forcepos[1] = min(forcepos[1], position_max * 1.5)
        
        logging.info("DEBUG WINDER: forcepos=%s homepos=%s" % (forcepos, homepos))
        logging.info("DEBUG WINDER: Calling homing_state.home_rails()")
        
        # Perform homing
        homing_state.home_rails([self.rail], forcepos, homepos)
        
        logging.info("DEBUG WINDER: homing_state.home_rails() completed")
    
    def home(self, homing_state):
        """Home the Y-axis (traverse)"""
        import logging
        logging.info("DEBUG WINDER: home() called, axes=%s (type=%s)" % (homing_state.get_axes(), type(homing_state.get_axes())))
        
        axes = homing_state.get_axes()
        # Check if Y-axis (index 1) needs homing
        if 'y' in axes or 1 in axes:
            logging.info("DEBUG WINDER: Y axis found in axes, calling _home_traverse()")
            self._home_traverse(homing_state)
        else:
            # No Y-axis in homing - just set as homed if already homed
            if self.limits[1][0] <= self.limits[1][1]:
                homing_state.set_homed_position([0., self.rail.get_commanded_position(), 0.])
    
    def check_move(self, move):
        """Check if move is valid - requires Y-axis to be homed"""
        end_pos = move.end_pos
        
        # Check Y-axis limits
        if move.axes_d[1]:
            if end_pos[1] < self.limits[1][0] or end_pos[1] > self.limits[1][1]:
                if self.limits[1][0] > self.limits[1][1]:
                    raise move.move_error("Must home Y axis first")
                raise move.move_error("Move out of range: Y=%.3f" % end_pos[1])
        
        # X and Z should not move
        if move.axes_d[0] or move.axes_d[2]:
            raise move.move_error("X and Z axes not supported in winder kinematics")
    
    def get_status(self, eventtime):
        axes = []
        if self.limits[1][0] <= self.limits[1][1]:
            axes.append('y')
        return {
            'homed_axes': "".join(axes),
            'axis_minimum': self.axes_min,
            'axis_maximum': self.axes_max,
        }

def load_kinematics(toolhead, config):
    return WinderKinematics(toolhead, config)

