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
        position_min, position_max = self.rail.get_range()
        hi = self.rail.get_homing_info()
        
        # Calculate force position (start from beyond max)
        homepos = [None, hi.position_endstop, None, None]
        forcepos = list(homepos)
        
        # Move to position beyond max to ensure we hit endstop
        if hi.positive_dir:
            forcepos[1] = position_min - 10.0
        else:
            forcepos[1] = position_max + 10.0
        
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

# CNC Puck Winder Control Module
import logging
from . import pulse_counter

class WinderController:
    def __init__(self, config):
        self.printer = config.get_printer()
        self.name = config.get_name()
        
        # Load config parameters
        self.motor_pwm_pin = config.get('motor_pwm_pin')
        self.motor_dir_pin = config.get('motor_dir_pin')
        self.motor_brake_pin = config.get('motor_brake_pin', None)
        self.motor_hall_pin = config.get('motor_hall_pin', None)
        self.spindle_hall_pin = config.get('spindle_hall_pin')
        
        # Physical parameters
        self.spindle_gear_ratio = config.getfloat('gear_ratio', 0.667, above=0.0, below=1.0)
        self.motor_poles = config.getint('motor_poles', 8, minval=2)
        self.spindle_hall_ppr = config.getint('spindle_hall_ppr', 1, minval=1)
        
        # Winding parameters
        self.wire_diameter = config.getfloat('wire_diameter', 0.056, above=0.001)
        self.bobbin_width = config.getfloat('bobbin_width', 12.0, above=0.0)
        self.spindle_edge_offset = config.getfloat('spindle_edge', 38.0, minval=0.0)
        self.traverse_max = config.getfloat('traverse_max', 93.0, above=0.0)
        self.home_offset = config.getfloat('home_offset', 2.0, minval=0.0)
        
        # Hall sensor timing
        self.hall_sample_time = config.getfloat('hall_sample_time', 0.01, above=0.001)
        self.hall_poll_time = config.getfloat('hall_poll_time', 0.1, above=0.01)
        self.hall_update_rate = config.getfloat('hall_update_rate', 10.0, above=1.0)
        
        # Speed limits
        self.max_motor_rpm = config.getfloat('max_motor_rpm', 3000.0, above=0.0)
        self.max_spindle_rpm = config.getfloat('max_spindle_rpm', 2000.0, above=0.0)
        self.min_spindle_rpm = config.getfloat('min_spindle_rpm', 10.0, above=0.0)
        
        # Sync parameters
        self.sync_tolerance = config.getfloat('sync_tolerance', 0.01, above=0.0, below=0.1)
        self.sync_update_rate = config.getfloat('sync_update_rate', 50.0, above=1.0)
        
        # Initialize state
        self.motor_pwm = None
        self.motor_dir = None
        self.motor_brake = None
        self.spindle_freq_counter = None
        self.motor_freq_counter = None
        self.spindle_measured_rpm = 0.0
        self.motor_measured_rpm = 0.0
        self.rpm_timer = None
        self.sync_timer = None
        self.current_layer = 0
        self.winding_direction = 1
        self.motor_rpm_target = 0.0
        self.spindle_rpm_target = 0.0
        self.is_winding = False
        self.start_position = self.spindle_edge_offset
        self.current_y_position = 0.0
        
        # Register commands
        gcode = self.printer.lookup_object('gcode')
        gcode.register_command('WINDER_START', self.cmd_WINDER_START,
                              desc=self.cmd_WINDER_START_help)
        gcode.register_command('WINDER_STOP', self.cmd_WINDER_STOP,
                              desc=self.cmd_WINDER_STOP_help)
        gcode.register_command('WINDER_STATUS', self.cmd_WINDER_STATUS,
                              desc=self.cmd_WINDER_STATUS_help)
        gcode.register_command('SET_SPINDLE_SPEED', self.cmd_SET_SPINDLE_SPEED,
                              desc=self.cmd_SET_SPINDLE_SPEED_help)
        gcode.register_command('SET_WIRE_DIAMETER', self.cmd_SET_WIRE_DIAMETER,
                              desc=self.cmd_SET_WIRE_DIAMETER_help)
        
        # Register event handlers
        self.printer.register_event_handler("klippy:connect", self._handle_connect)
        self.printer.register_event_handler("klippy:ready", self._handle_ready)
        self.printer.register_event_handler("klippy:shutdown", self._handle_shutdown)
        
        logging.info("Winder: Traverse range: %.2f-%.2fmm, Winding range: %.2f-%.2fmm"
                    % (0.0, self.traverse_max, self.start_position,
                       self.start_position + self.bobbin_width))
    
    def _handle_connect(self):
        """Setup hardware after MCU connects"""
        logging.info("Winder: Setting up hardware...")
        
        ppins = self.printer.lookup_object('pins')
        self.motor_pwm = ppins.setup_pin('pwm', self.motor_pwm_pin)
        self.motor_pwm.setup_max_duration(0)
        self.motor_pwm.setup_cycle_time(0.001)
        
        self.motor_dir = ppins.setup_pin('digital_out', self.motor_dir_pin)
        self.motor_dir.setup_max_duration(0)
        
        if self.motor_brake_pin:
            self.motor_brake = ppins.setup_pin('digital_out', self.motor_brake_pin)
            self.motor_brake.setup_max_duration(0)
        
        logging.info("Winder: Pins configured, Start position = %.2fmm from home" 
                    % self.start_position)
        
        # Setup Hall sensors
        if self.spindle_hall_pin:
            self.spindle_freq_counter = pulse_counter.FrequencyCounter(
                self.printer, 
                self.spindle_hall_pin,
                self.hall_sample_time,
                self.hall_poll_time
            )
            logging.info("Winder: Spindle Hall sensor initialized on %s" % self.spindle_hall_pin)
        
        if self.motor_hall_pin:
            self.motor_freq_counter = pulse_counter.FrequencyCounter(
                self.printer,
                self.motor_hall_pin,
                self.hall_sample_time,
                self.hall_poll_time
            )
            logging.info("Winder: Motor Hall sensor initialized on %s" % self.motor_hall_pin)
        
        # Register timers
        reactor = self.printer.get_reactor()
        self.rpm_timer = reactor.register_timer(
            self._update_rpm_safe,
            reactor.monotonic() + 1.0
        )
        logging.info("Winder: Hall sensor timer registered (poll=%.3fs)" % self.hall_poll_time)
        
        self.sync_timer = reactor.register_timer(
            self._sync_traverse_to_spindle,
            reactor.monotonic() + 1.0 + self.hall_poll_time
        )
        logging.info("Winder: Sync timer registered (rate=%.1f Hz)" % self.sync_update_rate)
    
    def _handle_ready(self):
        """Initialize pin states once printer is ready"""
        logging.info("Winder: Printer ready - pins will be initialized on first use")
    
    def _update_rpm_safe(self, eventtime):
        """Periodic callback to update RPM from Hall sensors"""
        try:
            state_msg, state = self.printer.get_state_message()
            if state != 'ready':
                return eventtime + 0.5
            
            if self.spindle_freq_counter:
                freq = self.spindle_freq_counter.get_frequency()
                self.spindle_measured_rpm = freq * 60.0
            
            if self.motor_freq_counter:
                freq = self.motor_freq_counter.get_frequency()
                self.motor_measured_rpm = (freq * 60.0) / 6.0
            
            return eventtime + self.hall_poll_time
            
        except Exception as e:
            logging.warning("Winder: RPM update error: %s" % e)
            return eventtime + 1.0
    
    def _sync_traverse_to_spindle(self, eventtime):
        """Real-time sync adjustment based on Hall feedback"""
        if not self.is_winding:
            return self.printer.get_reactor().NEVER
        
        try:
            measured_rpm = self.spindle_measured_rpm if self.spindle_freq_counter else self.spindle_rpm_target
            required_speed = self.calculate_traverse_speed(measured_rpm, self.wire_diameter)
            
            toolhead = self.printer.lookup_object('toolhead')
            current_speed = toolhead.get_status(eventtime)['max_velocity']
            
            if required_speed > 0:
                speed_error = abs(required_speed - current_speed) / required_speed
                
                if speed_error > self.sync_tolerance:
                    toolhead.set_max_velocities(required_speed * 1.1, None, None, None)
                    logging.debug("Winder: Adjusted traverse speed to %.3f mm/s (RPM: %.1f)"
                                % (required_speed, measured_rpm))
            
            return eventtime + (1.0 / self.sync_update_rate)
            
        except Exception as e:
            logging.warning("Winder: Sync error: %s" % e)
            return eventtime + 0.1
    
    def _handle_shutdown(self):
        """Emergency shutdown handler"""
        logging.info("Winder: Shutdown - stopping motor")
        self.stop_motor()
        
        reactor = self.printer.get_reactor()
        if self.rpm_timer:
            reactor.unregister_timer(self.rpm_timer)
        if self.sync_timer:
            reactor.unregister_timer(self.sync_timer)
    
    def stop_motor(self):
        """Emergency stop motor"""
        self.is_winding = False
        
        toolhead = self.printer.lookup_object('toolhead')
        eventtime = toolhead.get_reactor().monotonic()
        print_time = toolhead.mcu.estimated_print_time(eventtime)
        
        try:
            if self.motor_pwm:
                self.motor_pwm.set_pwm(print_time, 0.0)
        except AttributeError:
            logging.warning("Winder: Motor PWM pin not ready")
        
        try:
            if self.motor_brake:
                self.motor_brake.set_digital(print_time, 1)
        except AttributeError:
            logging.warning("Winder: Motor brake pin not ready")
        
        logging.info("Winder: Motor stopped")
    
    def set_motor_speed(self, motor_rpm):
        """Set motor speed via PWM"""
        if motor_rpm < 0:
            motor_rpm = 0
        if motor_rpm > self.max_motor_rpm:
            motor_rpm = self.max_motor_rpm
        
        self.motor_rpm_target = motor_rpm
        self.spindle_rpm_target = motor_rpm * self.spindle_gear_ratio
        
        pwm_duty = min(motor_rpm / self.max_motor_rpm, 1.0)
        
        toolhead = self.printer.lookup_object('toolhead')
        eventtime = toolhead.get_reactor().monotonic()
        print_time = toolhead.mcu.estimated_print_time(eventtime)
        
        try:
            if self.motor_brake:
                self.motor_brake.set_digital(print_time, 0)
        except AttributeError:
            logging.warning("Winder: Motor brake pin not ready")
        
        try:
            if self.motor_pwm:
                self.motor_pwm.set_pwm(print_time, pwm_duty)
        except AttributeError:
            logging.warning("Winder: Motor PWM pin not ready")
        
        logging.info("Winder: Motor speed set - Motor=%.1f RPM (%.1f%%), Spindle=%.1f RPM" 
                    % (motor_rpm, pwm_duty * 100, self.spindle_rpm_target))
    
    def set_motor_direction(self, forward=True):
        """Set motor direction"""
        if self.motor_dir is None:
            return
        
        toolhead = self.printer.lookup_object('toolhead')
        eventtime = toolhead.get_reactor().monotonic()
        print_time = toolhead.mcu.estimated_print_time(eventtime)
        
        try:
            self.motor_dir.set_digital(print_time, 0 if forward else 1)
        except AttributeError:
            logging.warning("Winder: Motor direction pin not ready")
    
    def calculate_traverse_speed(self, spindle_rpm, wire_diameter):
        """Calculate traverse speed to match spindle RPM"""
        if spindle_rpm <= 0:
            return 0.0
        revs_per_second = spindle_rpm / 60.0
        traverse_speed = revs_per_second * wire_diameter
        return traverse_speed
    
    def start_winding(self, spindle_rpm, layers=1):
        """Start winding operation"""
        if spindle_rpm < self.min_spindle_rpm:
            raise ValueError("RPM too low (min: %.1f)" % self.min_spindle_rpm)
        if spindle_rpm > self.max_spindle_rpm:
            raise ValueError("RPM too high (max: %.1f)" % self.max_spindle_rpm)
        
        self.is_winding = True
        self.current_layer = 0
        
        required_motor_rpm = spindle_rpm / self.spindle_gear_ratio
        self.set_motor_direction(forward=True)
        self.set_motor_speed(required_motor_rpm)
        
        traverse_speed = self.calculate_traverse_speed(self.spindle_rpm_target, self.wire_diameter)
        
        toolhead = self.printer.lookup_object('toolhead')
        start_y = self.start_position
        end_y = self.start_position + self.bobbin_width
        
        toolhead.wait_moves()
        
        reactor = self.printer.get_reactor()
        reactor.update_timer(self.sync_timer, reactor.monotonic() + (1.0 / self.sync_update_rate))
        
        logging.info("Winder: Starting - Motor=%.1f RPM, Spindle=%.1f RPM, Traverse=%.3f mm/s, Layers=%d" 
                    % (self.motor_rpm_target, self.spindle_rpm_target, traverse_speed, layers))
        
        self._start_winding_layer(toolhead, start_y, end_y, traverse_speed, layers)
    
    def _start_winding_layer(self, toolhead, start_y, end_y, speed, layers):
        """Generate continuous back-and-forth motion"""
        for layer in range(layers):
            if not self.is_winding:
                break
            
            toolhead.manual_move([None, end_y, None, None], speed)
            toolhead.wait_moves()
            
            toolhead.manual_move([None, start_y, None, None], speed)
            toolhead.wait_moves()
            
            self.current_layer = layer + 1
            logging.info("Winder: Completed layer %d of %d" % (self.current_layer, layers))
        
        if self.is_winding:
            self.stop_motor()
            logging.info("Winder: Winding complete - %d layers finished" % layers)
    
    cmd_WINDER_START_help = "Start winding operation (RPM=100 LAYERS=1)"
    def cmd_WINDER_START(self, gcmd):
        rpm = gcmd.get_float('RPM', 100.0)
        layers = gcmd.get_int('LAYERS', 1)
        try:
            self.start_winding(rpm, layers)
            gcmd.respond_info("Winding started: %.1f RPM, %d layers" % (rpm, layers))
        except Exception as e:
            raise gcmd.error("Error: %s" % e)
    
    cmd_WINDER_STOP_help = "Stop winding operation"
    def cmd_WINDER_STOP(self, gcmd):
        self.stop_motor()
        gcmd.respond_info("Winding stopped")
    
    cmd_WINDER_STATUS_help = "Report winder status"
    def cmd_WINDER_STATUS(self, gcmd):
        motor_status = "%.1f RPM" % self.motor_measured_rpm if self.motor_freq_counter else "N/A"
        spindle_status = "%.1f RPM" % self.spindle_measured_rpm if self.spindle_freq_counter else "N/A"
        
        status = ("Winder Status:\n"
                 "  Active: %s\n"
                 "  Motor Target: %.1f RPM | Measured: %s\n"
                 "  Spindle Target: %.1f RPM | Measured: %s\n"
                 "  Gear Ratio: %.3f (Motor:Spindle)\n"
                 "  Wire Diameter: %.3f mm\n"
                 "  Current Layer: %d\n"
                 "  Start Position: %.2f mm"
                 % (self.is_winding,
                    self.motor_rpm_target, motor_status,
                    self.spindle_rpm_target, spindle_status,
                    self.spindle_gear_ratio, self.wire_diameter,
                    self.current_layer, self.start_position))
        gcmd.respond_info(status)
    
    cmd_SET_SPINDLE_SPEED_help = "Set spindle speed in RPM"
    def cmd_SET_SPINDLE_SPEED(self, gcmd):
        spindle_rpm = gcmd.get_float('RPM')
        motor_rpm = spindle_rpm / self.spindle_gear_ratio
        self.set_motor_speed(motor_rpm)
        gcmd.respond_info("Motor: %.1f RPM, Spindle: %.1f RPM" % (motor_rpm, spindle_rpm))
    
    cmd_SET_WIRE_DIAMETER_help = "Set wire diameter (mm)"
    def cmd_SET_WIRE_DIAMETER(self, gcmd):
        diameter = gcmd.get_float('DIAMETER')
        self.wire_diameter = diameter
        gcmd.respond_info("Wire diameter set to %.4f mm" % diameter)
    
    def get_status(self, eventtime):
        """Return status for web interface"""
        return {
            'is_winding': self.is_winding,
            'motor_rpm_target': self.motor_rpm_target,
            'motor_rpm_measured': self.motor_measured_rpm,
            'spindle_rpm_target': self.spindle_rpm_target,
            'spindle_rpm_measured': self.spindle_measured_rpm,
            'gear_ratio': self.spindle_gear_ratio,
            'wire_diameter': self.wire_diameter,
            'current_layer': self.current_layer,
            'start_position': self.start_position,
        }

def load_config(config):
    return WinderController(config)
