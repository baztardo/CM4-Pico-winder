# Code for handling the kinematics of CNC Winder
# Only Y-axis (traverse) is used
#
# Copyright (C) 2024
#
# This file may be distributed under the terms of the GNU GPLv3 license.
import logging
import stepper
import math

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
    # Pre-calculated constants for angle sensor (avoid recalculating in callback)
    RAD_TO_RPM = 60.0 / (2.0 * math.pi)  # ~9.5493
    MIN_TIME_DIFF = 0.0001  # 100 microseconds minimum for valid RPM calculation
    
    def __init__(self, config):
        self.printer = config.get_printer()
        self.name = config.get_name()
        
        # Load config parameters
        self.motor_pwm_pin = config.get('motor_pwm_pin')
        self.motor_dir_pin = config.get('motor_dir_pin')
        self.motor_brake_pin = config.get('motor_brake_pin', None)
        self.motor_hall_pin = config.get('motor_hall_pin', None)
        self.spindle_hall_pin = config.get('spindle_hall_pin')
        # Optional ADC angle sensor (for better RPM accuracy)
        self.angle_sensor_pin = config.get('angle_sensor_pin', None)
        
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
        self.angle_sensor_adc = None  # ADC for angle sensor
        self.spindle_measured_rpm = 0.0
        self.motor_measured_rpm = 0.0
        self.last_angle_value = None
        self.last_angle_time = None
        self.angle_revolutions = 0  # Track full revolutions (net forward revolutions)
        self.angle_total_rad = 0.0  # Track cumulative angle (with revolutions)
        # Buffer for fast sampling with 100ms reporting
        self.angle_buffer = []  # Buffer of (time, angle) tuples
        self.angle_buffer_max = 10  # Buffer 10 samples (10ms each = 100ms total)
        self.rpm_timer = None
        self.sync_timer = None
        self.current_layer = 0
        self.winding_direction = 1
        self.motor_rpm_target = 0.0
        self.spindle_rpm_target = 0.0
        self.is_winding = False
        self.start_position = self.spindle_edge_offset
        self.current_y_position = 0.0
        
        # Setup pins early so _build_config runs during MCU configuration
        ppins = self.printer.lookup_object('pins')
        self.motor_pwm = ppins.setup_pin('pwm', self.motor_pwm_pin)
        self.motor_pwm.setup_max_duration(0)
        self.motor_pwm.setup_cycle_time(0.001)
        
        self.motor_dir = ppins.setup_pin('digital_out', self.motor_dir_pin)
        self.motor_dir.setup_max_duration(0)
        
        if self.motor_brake_pin:
            self.motor_brake = ppins.setup_pin('digital_out', self.motor_brake_pin)
            self.motor_brake.setup_max_duration(0)
        
        logging.info("Winder: Pins configured early (PWM, DIR, BRAKE)")
        
        # Setup Hall sensors early so they're configured during MCU config
        if self.spindle_hall_pin:
            logging.info("Winder: Creating spindle Hall counter on pin %s (sample=%.3fs, poll=%.3fs)" 
                        % (self.spindle_hall_pin, self.hall_sample_time, self.hall_poll_time))
            original_counter = pulse_counter.FrequencyCounter(
                self.printer, 
                self.spindle_hall_pin,
                self.hall_sample_time,
                self.hall_poll_time
            )
            # Access the underlying MCU_counter to add logging
            mcu_counter = original_counter._counter
            original_callback = mcu_counter._callback
            
            def debug_callback(time, count, count_time):
                if not hasattr(debug_callback, '_last_count'):
                    debug_callback._last_count = 0
                    debug_callback._last_count = count
                delta = count - debug_callback._last_count
                # Only log when we see new edges
                if delta > 0:
                    logging.debug("Winder: Spindle counter - count=%d, delta=%d" % (count, delta))
                debug_callback._last_count = count
                if original_callback:
                    original_callback(time, count, count_time)
            
            mcu_counter.setup_callback(debug_callback)
            self.spindle_freq_counter = original_counter
            logging.info("Winder: Spindle Hall sensor initialized on %s, counter OID=%d" 
                        % (self.spindle_hall_pin, mcu_counter._oid))
        
        if self.motor_hall_pin:
            logging.info("Winder: Creating motor Hall counter on pin %s (sample=%.3fs, poll=%.3fs)" 
                        % (self.motor_hall_pin, self.hall_sample_time, self.hall_poll_time))
            motor_counter_obj = pulse_counter.FrequencyCounter(
                self.printer,
                self.motor_hall_pin,
                self.hall_sample_time,
                self.hall_poll_time
            )
            # Add debug callback for motor too
            motor_mcu_counter = motor_counter_obj._counter
            motor_original_callback = motor_mcu_counter._callback
            
            def motor_debug_callback(time, count, count_time):
                if not hasattr(motor_debug_callback, '_last_count'):
                    motor_debug_callback._last_count = 0
                motor_debug_callback._last_count = count
                delta = count - motor_debug_callback._last_count
                # Only log when we see new edges
                if delta > 0:
                    logging.debug("Winder: Motor counter - count=%d, delta=%d" % (count, delta))
                motor_debug_callback._last_count = count
                if motor_original_callback:
                    motor_original_callback(time, count, count_time)
            
            motor_mcu_counter.setup_callback(motor_debug_callback)
            self.motor_freq_counter = motor_counter_obj
            logging.info("Winder: Motor Hall sensor initialized on %s, counter OID=%d" 
                        % (self.motor_hall_pin, motor_mcu_counter._oid))
        
        # Setup ADC angle sensor if configured
        if self.angle_sensor_pin:
            ppins = self.printer.lookup_object('pins')
            self.angle_sensor_adc = ppins.setup_pin('adc', self.angle_sensor_pin)
            # Sample every 1ms, average 4 samples, but callback every 10ms for fast buffering
            # We'll buffer 10 samples (100ms) and report averaged RPM every 100ms
            self.angle_sensor_adc.setup_adc_sample(0.001, 4)
            self.angle_sensor_adc.setup_adc_callback(0.01, self._angle_sensor_callback)
            query_adc = self.printer.lookup_object('query_adc')
            query_adc.register_adc(self.angle_sensor_pin, self.angle_sensor_adc)
            logging.info("Winder: ADC angle sensor initialized on %s" % self.angle_sensor_pin)
        
        # Register event handlers (only once, not in callbacks!)
        self.printer.register_event_handler("klippy:connect", self._handle_connect)
        self.printer.register_event_handler("klippy:ready", self._handle_ready)
        self.printer.register_event_handler("klippy:shutdown", self._handle_shutdown)
        
        logging.info("Winder: Traverse range: %.2f-%.2fmm, Winding range: %.2f-%.2fmm"
                    % (0.0, self.traverse_max, self.start_position,
                       self.start_position + self.bobbin_width))
        
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
        gcode.register_command('TEST_ANGLE_SENSOR', self.cmd_TEST_ANGLE_SENSOR,
                              desc=self.cmd_TEST_ANGLE_SENSOR_help)
    
    def _angle_sensor_callback(self, read_time, read_value):
        """Callback for ADC angle sensor - calculates RPM from angle changes
        Sensor: 12-bit (4096 steps), 360° range, 0.088° resolution
        Sensor VCC: 3.3V (via voltage divider from 5V supply)
        Sensor output: 0-3.3V (0-360°) - direct connection to RP2040 ADC
        read_value: 0.0 to 1.0 (normalized from 0-4095 ADC counts)
        
        Fast sampling (10ms): Buffer samples for accurate RPM calculation
        Reporting (100ms): Average buffered samples and update RPM
        
        NOTE: This callback must be FAST to meet Klipper timing constraints.
        Keep calculations minimal, logging async, and avoid blocking operations.
        """
        # Convert normalized ADC value (0.0-1.0) to radians (0-2π)
        # Note: Without voltage divider, 5V sensor saturates ADC at 3.3V (read_value = 1.0)
        # Clamp to prevent issues when sensor outputs > 3.3V
        clamped_value = min(1.0, max(0.0, read_value))
        current_angle_rad = clamped_value * 2.0 * math.pi
        current_angle_deg = current_angle_rad * 180.0 / math.pi
        
        # Debug: Log raw ADC value less frequently now that it's working
        if not hasattr(self, '_adc_debug_count'):
            self._adc_debug_count = 0
        self._adc_debug_count += 1
        # Log every 50 readings = 500ms (less spam now that it's working)
        if self._adc_debug_count % 50 == 0:
            reactor = self.printer.get_reactor()
            reactor.register_async_callback(
                lambda et, rv=read_value, cad=current_angle_deg: logging.info(
                    "Winder: ADC debug - raw_value=%.4f, angle=%.2f°" 
                    % (rv, cad)))
        
        # Add to buffer (fast sampling every 10ms)
        self.angle_buffer.append((read_time, current_angle_rad))
        
        # Keep only last N samples (10 samples = 100ms at 10ms intervals)
        if len(self.angle_buffer) > self.angle_buffer_max:
            self.angle_buffer.pop(0)
        
        # Process buffer every 100ms (when we have 10 samples)
        if len(self.angle_buffer) >= self.angle_buffer_max:
            # Get first and last samples from buffer
            first_time, first_angle = self.angle_buffer[0]
            last_time, last_angle = self.angle_buffer[-1]
            
            # Debug: Check if angle is actually changing
            angle_diff_rad_raw = last_angle - first_angle
            # Show raw ADC values from buffer for debugging
            first_adc_raw = first_angle / (2.0 * math.pi)  # Convert back to 0-1.0
            last_adc_raw = last_angle / (2.0 * math.pi)
            
            if abs(angle_diff_rad_raw) < 0.01:  # Less than 0.57° change over 100ms
                # Angle not changing significantly - log debug info with raw ADC values
                reactor = self.printer.get_reactor()
                reactor.register_async_callback(
                    lambda et: logging.warning(
                        "Winder: Angle sensor NOT changing! ADC: %.4f->%.4f (diff=%.4f), Angle: %.2f°->%.2f° (diff=%.4f rad = %.2f°)" 
                        % (first_adc_raw, last_adc_raw, last_adc_raw - first_adc_raw,
                           first_angle * 180.0 / math.pi, last_angle * 180.0 / math.pi, 
                           angle_diff_rad_raw, angle_diff_rad_raw * 180.0 / math.pi)))
            
            # Calculate total angle change (handle wraparound)
            angle_diff_rad = angle_diff_rad_raw
            
            # Handle wraparound - use unwrapped angle tracking for better accuracy
            # Track cumulative angle to avoid wraparound issues
            if not hasattr(self, '_last_unwrapped_angle'):
                self._last_unwrapped_angle = first_angle
                self.angle_total_rad = first_angle
            
            # Calculate change from last unwrapped angle
            unwrapped_diff = last_angle - self._last_unwrapped_angle
            
            # Handle wraparound by finding shortest path
            if unwrapped_diff > math.pi:
                # Large positive jump: wraparound backward (e.g., 10° -> 350°)
                unwrapped_diff -= 2.0 * math.pi
            elif unwrapped_diff < -math.pi:
                # Large negative jump: wraparound forward (e.g., 350° -> 10°)
                unwrapped_diff += 2.0 * math.pi
            
            # Update total angle and revolutions
            self.angle_total_rad += unwrapped_diff
            self.angle_revolutions = int(self.angle_total_rad / (2.0 * math.pi))
            self._last_unwrapped_angle = last_angle
            
            # Use the unwrapped difference for RPM calculation
            angle_diff_rad = unwrapped_diff
            
            # Calculate time difference over the buffer period
            time_diff = last_time - first_time
            
            if time_diff > self.MIN_TIME_DIFF:
                # Calculate angular velocity (rad/s) over the buffer period
                angular_velocity_rad_s = angle_diff_rad / time_diff
                calculated_rpm = abs(angular_velocity_rad_s) * self.RAD_TO_RPM
                
                # Use exponential moving average to smooth RPM
                if not hasattr(self, '_angle_smoothed_rpm'):
                    self._angle_smoothed_rpm = calculated_rpm
                else:
                    alpha = 0.3  # Smoothing factor
                    self._angle_smoothed_rpm = alpha * calculated_rpm + (1.0 - alpha) * self._angle_smoothed_rpm
                
                self.spindle_measured_rpm = self._angle_smoothed_rpm
                
                # Log asynchronously every 100ms (when buffer is processed)
                reactor = self.printer.get_reactor()
                current_angle_deg = last_angle * 180.0 / math.pi
                reactor.register_async_callback(
                    lambda et: logging.info(
                        "Winder: Angle sensor - angle=%.2f°, RPM=%.1f, revs=%d" 
                        % (current_angle_deg, self.spindle_measured_rpm, self.angle_revolutions)))
            
            # Clear buffer for next 100ms period
            self.angle_buffer = []
        
        # Update last values for tracking (used by status commands)
        self.last_angle_value = current_angle_rad
        self.last_angle_time = read_time
    
    def _handle_connect(self):
        """Setup hardware after MCU connects"""
        logging.info("Winder: Setting up hardware...")
        
        # Pins are already set up in __init__, but verify they're ready
        if self.motor_pwm and hasattr(self.motor_pwm, '_set_cmd'):
            if self.motor_pwm._set_cmd is None:
                logging.warning("Winder: PWM _set_cmd still None after connect")
            else:
                logging.info("Winder: PWM pin ready - _set_cmd configured")
        else:
            logging.error("Winder: PWM pin not set up!")
        
        logging.info("Winder: Start position = %.2fmm from home" 
                    % self.start_position)
        
        # Hall sensors are already set up in __init__, just verify
        if self.spindle_freq_counter:
            logging.info("Winder: Spindle Hall counter ready (OID=%d)" 
                        % self.spindle_freq_counter._counter._oid)
        if self.motor_freq_counter:
            logging.info("Winder: Motor Hall counter ready (OID=%d)" 
                        % self.motor_freq_counter._counter._oid)
        
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
            
            # Use angle sensor if available (more accurate than Hall sensor)
            if self.angle_sensor_adc:
                # Angle sensor RPM is calculated in callback, just read it here
                pass  # RPM already updated in _angle_sensor_callback
            elif self.spindle_freq_counter:
                freq = self.spindle_freq_counter.get_frequency()
                # FrequencyCounter counts edges (both rising and falling)
                # For spindle_hall_ppr=1, 1 pulse = 2 edges
                # RPM = (freq / edges_per_rev) * 60
                edges_per_rev = 2 * self.spindle_hall_ppr
                
                if freq > 0:
                    calculated_rpm = (freq / edges_per_rev) * 60.0
                    # Apply calibration: if measured 10 Hz gives 300 RPM but real is 529 RPM
                    # Calibration factor = 529 / 300 = 1.763
                    calibration_factor = 529.0 / 300.0  # Based on your measurement
                    new_rpm = calculated_rpm * calibration_factor
                    
                    # Use exponential moving average to smooth RPM and reduce flickering
                    # Alpha = 0.3 means 30% new value, 70% old value (smoother)
                    if not hasattr(self, '_spindle_smoothed_rpm'):
                        self._spindle_smoothed_rpm = new_rpm
                    else:
                        alpha = 0.3  # Smoothing factor (0.0-1.0, lower = smoother)
                        self._spindle_smoothed_rpm = alpha * new_rpm + (1.0 - alpha) * self._spindle_smoothed_rpm
                    
                    self.spindle_measured_rpm = self._spindle_smoothed_rpm
                    # Reset zero count when we get valid readings
                    if hasattr(self, '_spindle_zero_count'):
                        self._spindle_zero_count = 0
                else:
                    # If freq is 0, keep last known RPM for a short time to avoid flickering
                    # Only set to 0 if we've had no edges for a while
                    if not hasattr(self, '_spindle_zero_count'):
                        self._spindle_zero_count = 0
                        if not hasattr(self, '_spindle_smoothed_rpm'):
                            self.spindle_measured_rpm = 0.0
                    else:
                        self._spindle_zero_count += 1
                        # After 10 consecutive zero readings (~1 second), set to 0
                        if self._spindle_zero_count > 10:
                            self.spindle_measured_rpm = 0.0
                            if hasattr(self, '_spindle_smoothed_rpm'):
                                self._spindle_smoothed_rpm = 0.0
                        # Otherwise keep last value (don't update)
                
                # Log RPM occasionally or when it changes significantly
                if not hasattr(self, '_rpm_log_count'):
                    self._rpm_log_count = 0
                    self._last_logged_rpm = 0.0
                self._rpm_log_count += 1
                # Log every 50 updates or when RPM changes by more than 10
                if self._rpm_log_count % 50 == 0 or abs(self.spindle_measured_rpm - self._last_logged_rpm) > 10:
                    logging.info("Winder: Spindle Hall - freq=%.3f Hz, RPM=%.1f" 
                                % (freq, self.spindle_measured_rpm))
                    self._last_logged_rpm = self.spindle_measured_rpm
            
            if self.motor_freq_counter:
                freq = self.motor_freq_counter.get_frequency()
                # Motor has 8 poles, so 8 pulses per revolution
                # FrequencyCounter counts edges, so 8 pulses = 16 edges per revolution
                edges_per_rev = 2 * self.motor_poles
                self.motor_measured_rpm = (freq / edges_per_rev) * 60.0 if freq > 0 else 0.0
                
                if not hasattr(self, '_motor_rpm_log_count'):
                    self._motor_rpm_log_count = 0
                    self._last_logged_motor_rpm = 0.0
                self._motor_rpm_log_count += 1
                # Log every 50 updates or when RPM changes by more than 10
                if self._motor_rpm_log_count % 50 == 0 or (freq > 0 and abs(self.motor_measured_rpm - self._last_logged_motor_rpm) > 10):
                    logging.info("Winder: Motor Hall - freq=%.3f Hz, RPM=%.1f" 
                                % (freq, self.motor_measured_rpm))
                    self._last_logged_motor_rpm = self.motor_measured_rpm
            
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
        
        # Use lookahead callback to avoid "Timer too close" errors
        def stop_callback(print_time):
            # Ensure minimum spacing between commands
            min_spacing = 0.1
            print_time = max(print_time, toolhead.get_last_move_time() + min_spacing)
            
            try:
                if self.motor_pwm:
                    if hasattr(self.motor_pwm, '_set_cmd') and self.motor_pwm._set_cmd is not None:
                        self.motor_pwm.set_pwm(print_time, 0.0)
            except (AttributeError, Exception) as e:
                logging.warning("Winder: Motor PWM pin error during stop: %s" % e)
            
            try:
                if self.motor_brake:
                    self.motor_brake.set_digital(print_time, 1)  # 1 = brake engaged
            except (AttributeError, Exception) as e:
                logging.warning("Winder: Motor brake pin error during stop: %s" % e)
        
        toolhead.register_lookahead_callback(stop_callback)
        
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
        
        # Use lookahead callback to ensure print_time is properly scheduled
        # Add a small delay to avoid "Timer too close" errors
        def set_pwm_callback(print_time):
            # Ensure minimum spacing between commands (0.1s = 100ms)
            min_spacing = 0.1
            print_time = max(print_time, toolhead.get_last_move_time() + min_spacing)
            
            try:
                # Set direction pin (forward = 0, reverse = 1)
                if self.motor_dir:
                    self.motor_dir.set_digital(print_time, 0)  # Forward
            except (AttributeError, Exception) as e:
                logging.warning("Winder: Motor direction pin error: %s" % e)
            
            try:
                # Release brake
                if self.motor_brake:
                    self.motor_brake.set_digital(print_time, 0)  # 0 = brake released
            except (AttributeError, Exception) as e:
                logging.warning("Winder: Motor brake pin error: %s" % e)
            
            try:
                # Set PWM
                if self.motor_pwm:
                    # Check if PWM is ready (has _set_cmd configured)
                    if not hasattr(self.motor_pwm, '_set_cmd') or self.motor_pwm._set_cmd is None:
                        logging.warning("Winder: Motor PWM pin not ready - _set_cmd not configured yet")
                        return
                    self.motor_pwm.set_pwm(print_time, pwm_duty)
                    logging.debug("Winder: PWM set - pwm_duty=%.3f (%.1f%%)" % (pwm_duty, pwm_duty * 100))
                else:
                    logging.warning("Winder: Motor PWM pin is None")
            except (AttributeError, Exception) as e:
                logging.warning("Winder: Motor PWM pin error: %s" % e)
        
        toolhead.register_lookahead_callback(set_pwm_callback)
        
        logging.info("Winder: Motor speed set - Motor=%.1f RPM (%.1f%%), Spindle=%.1f RPM" 
                    % (motor_rpm, pwm_duty * 100, self.spindle_rpm_target))
    
    def set_motor_direction(self, forward=True):
        """Set motor direction"""
        if self.motor_dir is None:
            return
        
        toolhead = self.printer.lookup_object('toolhead')
        reactor = self.printer.get_reactor()
        eventtime = reactor.monotonic()
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
        # Check if using angle sensor or Hall sensor
        if self.angle_sensor_adc:
            current_angle = self.last_angle_value * 180.0 / math.pi if self.last_angle_value is not None else 0.0
            spindle_status = "%.1f RPM (Angle: %.1f°, Revs: %d)" % (
                self.spindle_measured_rpm, current_angle, 
                self.angle_revolutions if hasattr(self, 'angle_revolutions') else 0)
        elif self.spindle_freq_counter:
            spindle_status = "%.1f RPM" % self.spindle_measured_rpm
        else:
            spindle_status = "N/A"
        
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
    
    cmd_TEST_ANGLE_SENSOR_help = "Test angle sensor - shows current reading"
    def cmd_TEST_ANGLE_SENSOR(self, gcmd):
        """Test command to read angle sensor directly"""
        if not self.angle_sensor_adc:
            gcmd.respond_info("ERROR: Angle sensor not configured (check angle_sensor_pin in config)")
            return
        
        # Get last ADC reading
        last_value, last_time = self.angle_sensor_adc.get_last_value()
        
        if last_value is None:
            gcmd.respond_info("Angle sensor: No reading yet (waiting for first sample)")
            return
        
        # Convert to angle
        angle_deg = last_value * 360.0
        angle_rad = angle_deg * math.pi / 180.0
        
        # Show raw ADC value for debugging
        gcmd.respond_info("DEBUG: Raw ADC value = %.4f (should change 0.0-1.0 as you rotate)" % last_value)
        
        # Show current status
        info = ("Angle Sensor Test:\n"
               "  ADC Value: %.4f (0.0-1.0)\n"
               "  Angle: %.2f° (%.3f rad)\n"
               "  Last Reading: %.3f seconds ago\n"
               "  Current RPM: %.1f\n"
               "  Total Revolutions: %d" 
               % (last_value, angle_deg, angle_rad, 
                  self.printer.get_reactor().monotonic() - last_time if last_time else 0.0,
                  self.spindle_measured_rpm,
                  self.angle_revolutions if hasattr(self, 'angle_revolutions') else 0))
        
        gcmd.respond_info(info)
        gcmd.respond_info("Rotate the sensor manually to see values change. Use WINDER_STATUS to monitor RPM.")
    
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
