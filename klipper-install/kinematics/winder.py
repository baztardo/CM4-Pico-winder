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
        # Set initial position (limits are invalid until homed - this is expected)
        self.rail.set_position([0., 0., 0.])
        
    def get_steppers(self):
        return list(self.rail.get_steppers())
    
    def calc_position(self, stepper_positions):
        # Only Y-axis position matters
        y_pos = stepper_positions.get(self.rail.get_name(), 0.)
        return [0., y_pos, 0.]
    
    def set_position(self, newpos, homing_axes):
        self.rail.set_position(newpos)
        if 'y' in homing_axes:
            # Update limits when homing
            self.limits[1] = self.rail.get_range()
        # After any move, limits remain valid if we were previously homed
        # (limits are only invalid before first homing)
    
    def clear_homing_state(self, clear_axes):
        if 'y' in clear_axes:
            self.limits[1] = (1.0, -1.0)
    
    def _home_traverse(self, homing_state):
        """Home the traverse (Y-axis)"""
        position_min, position_max = self.rail.get_range()
        hi = self.rail.get_homing_info()
        
        # Calculate force position (start from beyond max)
        homepos = [None, hi.position_endstop, None, None]
        forcepos = list(homepos)
        
        # Move to position beyond max to ensure we hit endstop
        # Use large safety margin to ensure we can reach endstop from anywhere
        # This accounts for incorrect rotation_distance calibration
        safety_margin = 150.0  # Large margin to ensure we can reach switch
        if hi.positive_dir:
            forcepos[1] = position_min - safety_margin
        else:
            forcepos[1] = position_max + safety_margin
        
        # Perform homing
        homing_state.home_rails([self.rail], forcepos, homepos)
    
    def home(self, homing_state):
        """Home the Y-axis (traverse)"""
        axes = homing_state.get_axes()
        # Check if Y-axis (index 1) needs homing
        if 'y' in axes or 1 in axes:
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
