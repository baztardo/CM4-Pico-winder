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
        # Reduced update rate to avoid "Timer too close" errors
        # Klipper can only handle so many MCU commands per second
        # 10 Hz = updates every 100ms (safe for MCU timing constraints)
        self.sync_update_rate = config.getfloat('sync_update_rate', 10.0, above=1.0, below=50.0)
        
        # Initialize state
        self.motor_pwm = None
        self.motor_dir = None
        self.motor_brake = None
        self.spindle_freq_counter = None
        self.motor_freq_counter = None
        self.angle_sensor_adc = None  # ADC for angle sensor
        self.spindle_measured_rpm = 0.0
        self.spindle_hall_rpm = 0.0  # Hall sensor RPM (PRIMARY)
        self.spindle_angle_rpm = 0.0  # Angle sensor RPM (SECONDARY)
        self.motor_measured_rpm = 0.0
        self.last_angle_value = None
        self.last_angle_time = None
        self.angle_revolutions = 0  # Track full revolutions (net forward revolutions)
        self.angle_total_rad = 0.0  # Track cumulative angle (with revolutions)
        # Buffer for fast sampling with 100ms reporting
        self.angle_buffer = []  # Buffer of (time, angle) tuples
        self.angle_buffer_max = 10  # Buffer 10 samples (10ms each = 100ms total)
        
        # Auto-calibration for angle sensor (min/max mapping)
        # Config options for manual calibration
        self.angle_adc_min = config.getfloat('angle_adc_min', None, minval=0.0, maxval=1.0)
        self.angle_adc_max = config.getfloat('angle_adc_max', None, minval=0.0, maxval=1.0)
        self.angle_auto_calibrate = config.getboolean('angle_auto_calibrate', True)
        # Sensor VCC voltage (for reference - helps understand saturation)
        self.angle_sensor_vcc = config.getfloat('angle_sensor_vcc', 5.0, above=0.0)
        # Runtime calibration tracking
        self._angle_adc_observed_min = None
        self._angle_adc_observed_max = None
        self._angle_calibration_samples = 0
        self._angle_calibration_complete = False
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
                delta = count - debug_callback._last_count
                # Store current count for angle sensor to use
                if not hasattr(self, '_spindle_hall_count'):
                    self._spindle_hall_count = count
                self._spindle_hall_count = count
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
            # Register with query_adc if available (optional - only needed for QUERY_ADC command)
            # If query_adc doesn't exist, ADC will still work via callbacks
            try:
                query_adc = self.printer.lookup_object('query_adc')
                query_adc.register_adc(self.angle_sensor_pin, self.angle_sensor_adc)
            except Exception:
                # query_adc not available (no adc_temperature section) - ADC callbacks still work!
                # This is fine - the angle sensor will work via callbacks, just can't query via QUERY_ADC
                pass
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
        gcode.register_command('ANGLE_SENSOR_CALIBRATE', self.cmd_ANGLE_SENSOR_CALIBRATE,
                              desc=self.cmd_ANGLE_SENSOR_CALIBRATE_help)
    
    def _angle_sensor_callback(self, read_time, read_value):
        """Callback for ADC angle sensor - calculates RPM from angle changes
        Sensor: 12-bit (4096 steps), 360° range, 0.088° resolution
        Sensor VCC: Configurable (default 5V, actual may be different like 3.848V)
        Sensor output: 0-VCC (0-360°) - connected to TH0 (PA0) with built-in conditioning
        read_value: 0.0 to 1.0 (normalized from 0-4095 ADC counts)
        
        Auto-calibration: Tracks min/max ADC values and maps them to 0-360°
        Uses Hall sensor to handle saturation: When ADC saturates, Hall sensor tracks revolutions.
        Distinguishes stillness from rotation: When saturated, checks Hall sensor to detect rotation.
        
        Fast sampling (10ms): Buffer samples for accurate RPM calculation
        Reporting (100ms): Average buffered samples and update RPM
        
        NOTE: This callback must be FAST to meet Klipper timing constraints.
        Keep calculations minimal, logging async, and avoid blocking operations.
        """
        # Auto-calibrate min/max ADC values if enabled
        if self.angle_auto_calibrate and not self._angle_calibration_complete:
            if self._angle_adc_observed_min is None or read_value < self._angle_adc_observed_min:
                self._angle_adc_observed_min = read_value
            if self._angle_adc_observed_max is None or read_value > self._angle_adc_observed_max:
                self._angle_adc_observed_max = read_value
            
            self._angle_calibration_samples += 1
            # Calibrate after 100 samples (1 second) or when we see a full range
            if self._angle_calibration_samples >= 100 or (
                self._angle_adc_observed_min is not None and 
                self._angle_adc_observed_max is not None and
                (self._angle_adc_observed_max - self._angle_adc_observed_min) > 0.5
            ):
                self._angle_calibration_complete = True
                reactor = self.printer.get_reactor()
                saturation_note = ""
                if self._angle_adc_observed_max >= 0.99:
                    saturation_note = " (SATURATED at max - consider voltage divider to use full range)"
                reactor.register_async_callback(
                    lambda et, sn=saturation_note: logging.info(
                        "Winder: Angle sensor auto-calibrated - ADC range: %.4f to %.4f (span: %.4f, VCC: %.2fV)%s" 
                        % (self._angle_adc_observed_min, self._angle_adc_observed_max,
                           self._angle_adc_observed_max - self._angle_adc_observed_min,
                           self.angle_sensor_vcc, sn)))
        
        # Determine actual min/max for mapping
        if self.angle_adc_min is not None and self.angle_adc_max is not None:
            # Manual calibration from config
            adc_min = self.angle_adc_min
            adc_max = self.angle_adc_max
        elif self._angle_calibration_complete:
            # Use auto-calibrated values
            adc_min = self._angle_adc_observed_min
            adc_max = self._angle_adc_observed_max
        else:
            # Not calibrated yet - use full range (0.0-1.0)
            adc_min = 0.0
            adc_max = 1.0
        
        # Map ADC value to 0.0-1.0 range using calibrated min/max
        adc_range = adc_max - adc_min
        if adc_range > 0.001:  # Avoid division by zero
            # Clamp to observed range, then map to 0-1
            clamped_adc = max(adc_min, min(adc_max, read_value))
            mapped_value = (clamped_adc - adc_min) / adc_range
        else:
            # Range too small - use raw value
            mapped_value = read_value
        
        # Check for saturation (mapped value >= 0.99 or read_value >= adc_max)
        is_saturated = mapped_value >= 0.99 or read_value >= adc_max
        
        # Initialize Hall sensor tracking
        if not hasattr(self, '_last_hall_count'):
            if hasattr(self, '_spindle_hall_count'):
                self._last_hall_count = self._spindle_hall_count
            else:
                self._last_hall_count = 0
        
        if not hasattr(self, '_saturated_revolutions'):
            self._saturated_revolutions = 0  # Track extra revolutions while saturated
        
        if not hasattr(self, '_last_angle_base'):
            self._last_angle_base = 0.0  # Base angle (0-2π) from ADC
        
        # Get current Hall sensor count
        current_hall_count = 0
        if hasattr(self, '_spindle_hall_count'):
            current_hall_count = self._spindle_hall_count
        
        # Check if Hall sensor has incremented (new revolution)
        hall_incremented = False
        hall_delta = 0
        if current_hall_count > self._last_hall_count:
            hall_delta = current_hall_count - self._last_hall_count
            hall_incremented = True
            self._last_hall_count = current_hall_count
        
        if is_saturated:
            # In saturation zone - use Hall sensor to track revolutions
            # Each Hall increment = 1 full revolution = 2π radians
            if hall_incremented:
                # Hall sensor incremented while saturated - add full revolution
                self._saturated_revolutions += hall_delta
                # Log when we detect a revolution while saturated
                reactor = self.printer.get_reactor()
                reactor.register_async_callback(
                    lambda et, hd=hall_delta, sr=self._saturated_revolutions: logging.info(
                        "Winder: Saturated - Hall sensor incremented by %d, total saturated revs=%d" 
                        % (hd, sr)))
            
            # While saturated, use Hall sensor count to determine angle
            # Base angle is 360° (saturated), plus any extra revolutions from Hall sensor
            # Convert to 0-1.0 range: saturated = 1.0, but we track revolutions separately
            clamped_value = 1.0  # Always 360° while saturated
            # The actual angle will be calculated as: base (360°) + revolutions * 360°
        else:
            # Normal reading, not saturated - use mapped value
            clamped_value = min(1.0, max(0.0, mapped_value))
            
            # If we were saturated and just exited, reset saturated revolutions
            # (the actual angle reading will be used now)
            if hasattr(self, '_was_saturated') and self._was_saturated:
                # Just exited saturation - reset counter, use actual reading
                if self._saturated_revolutions > 0:
                    reactor = self.printer.get_reactor()
                    reactor.register_async_callback(
                        lambda et, sr=self._saturated_revolutions: logging.info(
                            "Winder: Exited saturation - had %d saturated revolutions, now using ADC" 
                            % sr))
                self._saturated_revolutions = 0
            
            self._last_angle_base = clamped_value
        
        # Track saturation state
        self._was_saturated = is_saturated
        
        # Convert normalized ADC value (0.0-1.0) to radians (0-2π)
        current_angle_rad = clamped_value * 2.0 * math.pi
        current_angle_deg = current_angle_rad * 180.0 / math.pi
        
        # Debug: Log raw ADC value DISABLED (was spamming logs)
        # Uncomment below to enable debug logging every 10 seconds:
        # if not hasattr(self, '_adc_debug_count'):
        #     self._adc_debug_count = 0
        # self._adc_debug_count += 1
        # if self._adc_debug_count % 1000 == 0:  # Log every 1000 readings = 10 seconds
        if False:  # Disabled
            reactor = self.printer.get_reactor()
            cal_status = ""
            if self._angle_calibration_complete:
                cal_status = " (calibrated: %.4f-%.4f)" % (adc_min, adc_max)
            reactor.register_async_callback(
                lambda et, rv=read_value, mv=mapped_value, cad=current_angle_deg, cs=cal_status: logging.info(
                    "Winder: ADC debug - raw=%.4f, mapped=%.4f, angle=%.2f°%s" 
                    % (rv, mv, cad, cs)))
        
        # Add to buffer (fast sampling every 10ms)
        # Store Hall count with each sample for saturation handling
        self.angle_buffer.append((read_time, current_angle_rad, current_hall_count))
        
        # Keep only last N samples (10 samples = 100ms at 10ms intervals)
        if len(self.angle_buffer) > self.angle_buffer_max:
            self.angle_buffer.pop(0)
        
        # Process buffer every 100ms (when we have 10 samples)
        if len(self.angle_buffer) >= self.angle_buffer_max:
            # Get first and last samples from buffer
            first_time, first_angle, first_hall_count = self.angle_buffer[0]
            last_time, last_angle, last_hall_count = self.angle_buffer[-1]
            
            # Calculate Hall sensor change over buffer period
            hall_count_delta = last_hall_count - first_hall_count
            
            # Debug: Check if angle is actually changing
            angle_diff_rad_raw = last_angle - first_angle
            # Show raw ADC values from buffer for debugging
            first_adc_raw = first_angle / (2.0 * math.pi)  # Convert back to 0-1.0
            last_adc_raw = last_angle / (2.0 * math.pi)
            
            # Calculate total angle change (handle wraparound and saturation)
            # When saturated, use Hall sensor to calculate RPM
            # When not saturated, use angle sensor as before
            
            # Check if we're currently saturated (check last sample in buffer)
            is_currently_saturated = is_saturated
            
            # Check if sensor is actually still (not rotating)
            # When saturated, check Hall sensor - if Hall is incrementing, it's rotating through the gap
            is_actually_still = False
            if abs(angle_diff_rad_raw) < 0.01:  # Less than 0.57° change over 100ms
                # ADC not changing - but check if Hall sensor indicates rotation
                if is_currently_saturated:
                    # When saturated, use Hall sensor to detect rotation
                    if hall_count_delta == 0:
                        # ADC saturated AND Hall sensor not incrementing = sitting still
                        is_actually_still = True
                    # else: Hall sensor incrementing = rotating through saturation gap (not still)
                else:
                    # Not saturated and ADC not changing = sitting still
                    is_actually_still = True
            
            if is_actually_still:
                # Sensor still logging DISABLED (was spamming logs)
                # Uncomment below to enable:
                # if not hasattr(self, '_still_log_count'):
                #     self._still_log_count = 0
                # self._still_log_count += 1
                # if self._still_log_count % 100 == 0:  # Log every 100 times = 10 seconds when still
                #     reactor = self.printer.get_reactor()
                #     hall_info = ""
                #     if is_currently_saturated:
                #         hall_info = " (saturated, Hall delta=%d)" % hall_count_delta
                #     reactor.register_async_callback(
                #         lambda et, hinfo=hall_info: logging.debug(
                #             "Winder: Angle sensor still - ADC: %.4f->%.4f, Angle: %.2f°->%.2f°%s" 
                #             % (first_adc_raw, last_adc_raw,
                #                first_angle * 180.0 / math.pi, last_angle * 180.0 / math.pi, hinfo)))
                pass  # Logging disabled
            
            # Calculate time difference over the buffer period
            time_diff = last_time - first_time
            
            if time_diff > self.MIN_TIME_DIFF:
                calculated_rpm = 0.0
                
                if is_currently_saturated:
                    # Saturated - use Hall sensor frequency for RPM calculation
                    if self.spindle_freq_counter:
                        freq = self.spindle_freq_counter.get_frequency()
                        # FrequencyCounter counts edges (both rising and falling)
                        # For spindle_hall_ppr=1, 1 pulse = 2 edges
                        # RPM = (freq / edges_per_rev) * 60
                        edges_per_rev = 2 * self.spindle_hall_ppr
                        if freq > 0:
                            calculated_rpm = (freq / edges_per_rev) * 60.0
                            # Apply calibration factor if needed
                            calibration_factor = 529.0 / 300.0  # Based on previous measurement
                            calculated_rpm *= calibration_factor
                        else:
                            # No Hall sensor signal - RPM is 0
                            calculated_rpm = 0.0
                    else:
                        # No Hall sensor available - can't calculate RPM while saturated
                        calculated_rpm = 0.0
                    
                    # For angle tracking while saturated, use Hall sensor count over buffer period
                    # Each Hall increment = 1 full revolution = 2π radians
                    if hall_count_delta > 0:
                        # Hall sensor incremented during buffer period - calculate angle change
                        angle_diff_rad = hall_count_delta * 2.0 * math.pi
                        # Update total angle tracking
                        if not hasattr(self, '_last_unwrapped_angle'):
                            self._last_unwrapped_angle = 0.0
                            self.angle_total_rad = 0.0
                        self.angle_total_rad += angle_diff_rad
                        self.angle_revolutions = int(self.angle_total_rad / (2.0 * math.pi))
                    else:
                        # No Hall increment in this period - angle didn't change
                        angle_diff_rad = 0.0
                else:
                    # Not saturated - use angle sensor as before
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
                    # Add any saturated revolutions that occurred
                    if hasattr(self, '_saturated_revolutions') and self._saturated_revolutions > 0:
                        self.angle_total_rad += self._saturated_revolutions * 2.0 * math.pi
                        self._saturated_revolutions = 0  # Reset after adding
                    self.angle_revolutions = int(self.angle_total_rad / (2.0 * math.pi))
                    self._last_unwrapped_angle = last_angle
                    
                    # Use the unwrapped difference for RPM calculation
                    angle_diff_rad = unwrapped_diff
                    
                    # Calculate angular velocity (rad/s) over the buffer period
                    angular_velocity_rad_s = angle_diff_rad / time_diff
                    calculated_rpm = abs(angular_velocity_rad_s) * self.RAD_TO_RPM
                
                # Use exponential moving average to smooth RPM
                if not hasattr(self, '_angle_smoothed_rpm'):
                    self._angle_smoothed_rpm = calculated_rpm
                else:
                    alpha = 0.3  # Smoothing factor
                    self._angle_smoothed_rpm = alpha * calculated_rpm + (1.0 - alpha) * self._angle_smoothed_rpm
                
                # Store angle sensor RPM separately (will be blended with Hall sensor in _update_rpm_safe)
                # When saturated, this will be set from Hall sensor in the saturation handling code above
                if not is_currently_saturated:
                    # Not saturated - store angle sensor RPM
                    self.spindle_angle_rpm = self._angle_smoothed_rpm
                # Note: When saturated, RPM is calculated from Hall sensor frequency above,
                # and spindle_angle_rpm will be updated in _update_rpm_safe to use Hall sensor
                
                # For backward compatibility, also update spindle_measured_rpm
                # But _update_rpm_safe will blend with Hall sensor for final value
                self.spindle_measured_rpm = self._angle_smoothed_rpm
                
                # Angle sensor logging DISABLED (was spamming logs)
                # Uncomment below to enable logging every 10 seconds:
                # if not hasattr(self, '_angle_log_count'):
                #     self._angle_log_count = 0
                # self._angle_log_count += 1
                # if self._angle_log_count % 100 == 0:  # Log every 100 buffers = 10 seconds
                #     reactor = self.printer.get_reactor()
                #     current_angle_deg = last_angle * 180.0 / math.pi
                #     reactor.register_async_callback(
                #         lambda et: logging.info(
                #             "Winder: Angle sensor - angle=%.2f°, RPM=%.1f, revs=%d" 
                #             % (current_angle_deg, self.spindle_measured_rpm, self.angle_revolutions)))
            
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
        """Periodic callback to update RPM from Hall sensors
        For precise wire layering (43AWG on 12mm bobbin), RPM accuracy is critical.
        Strategy:
        - Hall sensor: PRIMARY (1 pulse/rev = accurate RPM, no saturation)
        - Angle sensor: SECONDARY (fine-tune when not saturated, better resolution)
        - Blend both sources for best accuracy
        """
        try:
            state_msg, state = self.printer.get_state_message()
            if state != 'ready':
                return eventtime + 0.5
            
            # For critical sync applications, use Hall sensor as PRIMARY
            # Hall sensor: 1 pulse/rev = accurate RPM, no saturation issues
            # Angle sensor: Better resolution but has saturation gap
            # Blend both sources when angle sensor is not saturated
            
            hall_rpm = None
            angle_rpm = None
            
            # Get Hall sensor RPM (PRIMARY - reliable, no saturation)
            # For 43AWG wire layering, Hall sensor is MORE reliable than angle sensor
            # because: 1 pulse/rev = accurate RPM, no saturation issues
            if self.spindle_freq_counter:
                freq = self.spindle_freq_counter.get_frequency()
                # FrequencyCounter counts edges (both rising and falling)
                # For spindle_hall_ppr=1, 1 pulse = 2 edges
                # RPM = (freq / edges_per_rev) * 60
                edges_per_rev = 2 * self.spindle_hall_ppr
                
                if freq > 0:
                    calculated_rpm = (freq / edges_per_rev) * 60.0
                    # Apply calibration: if measured 10 Hz gives 300 RPM but real is 529 RPM
                    # Calibration factor = 529 / 300 = 1.763
                    calibration_factor = 529.0 / 300.0  # Based on previous measurement
                    hall_rpm = calculated_rpm * calibration_factor
                    
                    # Use exponential moving average to smooth RPM and reduce flickering
                    # Alpha = 0.3 means 30% new value, 70% old value (smoother)
                    if not hasattr(self, '_hall_smoothed_rpm'):
                        self._hall_smoothed_rpm = hall_rpm
                    else:
                        alpha = 0.3  # Smoothing factor (0.0-1.0, lower = smoother)
                        self._hall_smoothed_rpm = alpha * hall_rpm + (1.0 - alpha) * self._hall_smoothed_rpm
                    
                    hall_rpm = self._hall_smoothed_rpm
                    # Reset zero count when we get valid readings
                    if hasattr(self, '_spindle_zero_count'):
                        self._spindle_zero_count = 0
                else:
                    # If freq is 0, keep last known RPM for a short time to avoid flickering
                    # Only set to 0 if we've had no edges for a while
                    if not hasattr(self, '_spindle_zero_count'):
                        self._spindle_zero_count = 0
                        if hasattr(self, '_hall_smoothed_rpm'):
                            hall_rpm = self._hall_smoothed_rpm
                        else:
                            hall_rpm = 0.0
                    else:
                        self._spindle_zero_count += 1
                        # After 10 consecutive zero readings (~1 second), set to 0
                        if self._spindle_zero_count > 10:
                            hall_rpm = 0.0
                            if hasattr(self, '_hall_smoothed_rpm'):
                                self._hall_smoothed_rpm = 0.0
                        else:
                            # Keep last value
                            if hasattr(self, '_hall_smoothed_rpm'):
                                hall_rpm = self._hall_smoothed_rpm
                            else:
                                hall_rpm = 0.0
                
                # Log RPM occasionally or when it changes significantly
                if not hasattr(self, '_rpm_log_count'):
                    self._rpm_log_count = 0
                    self._last_logged_rpm = 0.0
                self._rpm_log_count += 1
                # Log every 50 updates or when RPM changes by more than 10
                if self._rpm_log_count % 50 == 0 or (hall_rpm is not None and abs(hall_rpm - self._last_logged_rpm) > 10):
                    logging.info("Winder: Spindle Hall - freq=%.3f Hz, RPM=%.1f" 
                                % (freq, hall_rpm if hall_rpm is not None else 0.0))
                    if hall_rpm is not None:
                        self._last_logged_rpm = hall_rpm
            
            # Store Hall sensor RPM (PRIMARY)
            if hall_rpm is not None:
                self.spindle_hall_rpm = hall_rpm
            
            # Get angle sensor RPM (SECONDARY - fine-tune when not saturated)
            # Angle sensor RPM is calculated in _angle_sensor_callback
            # It's stored in self.spindle_measured_rpm, but we need to track it separately
            # to blend with Hall sensor properly
            if self.angle_sensor_adc:
                # Angle sensor RPM is updated in callback
                # Check if it was recently calculated (not saturated)
                # The callback sets self.spindle_measured_rpm when not saturated
                # When saturated, callback uses Hall sensor RPM
                angle_rpm = self.spindle_measured_rpm
                # Check if angle sensor is currently saturated
                is_angle_saturated = hasattr(self, '_was_saturated') and self._was_saturated
                if not is_angle_saturated and angle_rpm > 0:
                    # Angle sensor not saturated - use its RPM
                    self.spindle_angle_rpm = angle_rpm
                else:
                    # Angle sensor saturated - it's using Hall sensor RPM, so use Hall directly
                    self.spindle_angle_rpm = hall_rpm if hall_rpm is not None else self.spindle_angle_rpm
            
            # Blend Hall sensor (PRIMARY) with angle sensor (SECONDARY) for best accuracy
            # For critical sync applications (43AWG wire), prioritize Hall sensor
            # Hall sensor: 1 pulse/rev = accurate RPM, no saturation
            # Angle sensor: Better resolution when not saturated, but has gaps
            if self.spindle_hall_rpm > 0:
                if self.spindle_angle_rpm > 0 and not (hasattr(self, '_was_saturated') and self._was_saturated):
                    # Both available and angle sensor not saturated - blend (70% Hall, 30% Angle)
                    # Hall sensor is PRIMARY for reliability, angle sensor fine-tunes
                    final_rpm = 0.7 * self.spindle_hall_rpm + 0.3 * self.spindle_angle_rpm
                else:
                    # Angle sensor saturated or not available - use Hall sensor only (100%)
                    # This ensures continuous accurate RPM even during saturation gaps
                    final_rpm = self.spindle_hall_rpm
            elif self.spindle_angle_rpm > 0:
                # Only angle sensor available - use it (fallback, but not ideal)
                final_rpm = self.spindle_angle_rpm
            else:
                # No sensors available - keep last value
                final_rpm = self.spindle_measured_rpm if hasattr(self, 'spindle_measured_rpm') else 0.0
            
            # Update measured RPM (used by sync algorithm)
            self.spindle_measured_rpm = final_rpm
            
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
        """Real-time sync adjustment based on Hall feedback
        Optimized to avoid "Timer too close" errors:
        - Reduced update rate (default 10 Hz instead of 50 Hz)
        - Only update when speed change is significant (>5% difference)
        - Use lookahead callback to properly schedule MCU commands
        - Updates max_velocity which affects future manual_move() calls
        
        NOTE: manual_move() uses the speed parameter directly, but max_velocity
        acts as a cap. The sync algorithm adjusts max_velocity to ensure future
        moves can use the correct speed. For continuous sync, the speed parameter
        passed to manual_move() should be updated based on measured RPM.
        """
        if not self.is_winding:
            return self.printer.get_reactor().NEVER
        
        try:
            # Use measured RPM if available (from Hall sensor or angle sensor blend)
            # Fall back to target RPM if sensors not available
            measured_rpm = self.spindle_measured_rpm if self.spindle_measured_rpm > 0 else self.spindle_rpm_target
            required_speed = self.calculate_traverse_speed(measured_rpm, self.wire_diameter)
            
            toolhead = self.printer.lookup_object('toolhead')
            current_speed = toolhead.get_status(eventtime)['max_velocity']
            
            if required_speed > 0:
                # Calculate speed error percentage
                speed_error = abs(required_speed - current_speed) / required_speed if required_speed > 0 else 1.0
                
                # Only update if error is significant (>5%) to reduce MCU command frequency
                # This prevents "Timer too close" errors while maintaining sync accuracy
                # For 43AWG wire (0.056mm), 5% error = 0.003mm/s difference (acceptable)
                if speed_error > 0.05:  # 5% threshold
                    # Use lookahead callback to properly schedule the velocity update
                    # This ensures proper timing and avoids "Timer too close" errors
                    def update_velocity_callback(print_time):
                        # Ensure minimum spacing from last move to avoid timing conflicts
                        min_spacing = 0.05  # 50ms minimum spacing
                        base_time = max(print_time, toolhead.get_last_move_time() + min_spacing)
                        
                        # Update traverse max_velocity (with 10% margin for safety)
                        # This allows future manual_move() calls to use speeds up to required_speed * 1.1
                        toolhead.set_max_velocities(required_speed * 1.1, None, None, None)
                    
                    toolhead.register_lookahead_callback(update_velocity_callback)
                    
                    # Log only when significant change occurs (reduce log spam)
                    if not hasattr(self, '_last_logged_sync_speed'):
                        self._last_logged_sync_speed = 0.0
                    if abs(required_speed - self._last_logged_sync_speed) > 0.01:  # Log if >0.01 mm/s change
                        logging.info("Winder: Sync - Traverse speed: %.3f mm/s (RPM: %.1f, error: %.1f%%)"
                                    % (required_speed, measured_rpm, speed_error * 100))
                        self._last_logged_sync_speed = required_speed
            
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
        reactor = self.printer.get_reactor()
        
        # Use sequential reactor callbacks with large delays to avoid "Timer too close"
        # NOTE: Brake pin is optional - only PWM stop is required
        def stop_pwm_callback(eventtime):
            """Stop PWM (REQUIRED)"""
            try:
                print_time = toolhead.mcu.estimated_print_time(eventtime)
                # Large spacing: 300ms
                pwm_time = print_time + 0.3
                if self.motor_pwm:
                    if hasattr(self.motor_pwm, '_set_cmd') and self.motor_pwm._set_cmd is not None:
                        self.motor_pwm.set_pwm(pwm_time, 0.0)
                        logging.info("Winder: PWM stopped")
                    else:
                        logging.warning("Winder: PWM pin not ready - cannot stop PWM")
                else:
                    logging.warning("Winder: PWM pin not configured - cannot stop PWM")
            except Exception as e:
                logging.warning("Winder: Error stopping PWM: %s" % e)
        
        def engage_brake_callback(eventtime):
            """Engage brake (OPTIONAL - not required for testing)"""
            try:
                if self.motor_brake:
                    print_time = toolhead.mcu.estimated_print_time(eventtime)
                    # Large spacing: 300ms after PWM stop
                    brake_time = print_time + 0.3
                    self.motor_brake.set_digital(brake_time, 1)  # 1 = brake engaged
                    logging.info("Winder: Brake engaged")
                else:
                    logging.info("Winder: Brake pin not configured - skipping (OK for testing)")
            except Exception as e:
                logging.warning("Winder: Brake pin not available (OK for testing): %s" % e)
        
        # Schedule stop commands with large delays: 0.2s, 0.5s
        reactor.register_callback(stop_pwm_callback, reactor.monotonic() + 0.2)
        reactor.register_callback(engage_brake_callback, reactor.monotonic() + 0.5)
        
        logging.info("Winder: Motor stop requested")
    
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
        # Add spacing between commands to avoid "Timer too close" errors
        def set_pwm_callback(print_time):
            # Ensure minimum spacing from last move
            min_spacing = 0.1
            base_time = max(print_time, toolhead.get_last_move_time() + min_spacing)
            
            # Space out commands to avoid "Timer too close" error
            # Each command needs at least min_schedule_time spacing
            mcu = toolhead.mcu
            min_sched = mcu.min_schedule_time()
            
            cmd_time = base_time
            
            try:
                # Set direction pin first (forward = 0, reverse = 1)
                if self.motor_dir:
                    self.motor_dir.set_digital(cmd_time, 0)  # Forward
                    cmd_time += min_sched * 2  # Space out next command
            except (AttributeError, Exception) as e:
                logging.warning("Winder: Motor direction pin error: %s" % e)
            
            try:
                # Release brake second
                if self.motor_brake:
                    self.motor_brake.set_digital(cmd_time, 0)  # 0 = brake released
                    cmd_time += min_sched * 2  # Space out next command
            except (AttributeError, Exception) as e:
                logging.warning("Winder: Motor brake pin error: %s" % e)
            
            try:
                # Set PWM last
                if self.motor_pwm:
                    # Check if PWM is ready (has _set_cmd configured)
                    if not hasattr(self.motor_pwm, '_set_cmd') or self.motor_pwm._set_cmd is None:
                        logging.warning("Winder: Motor PWM pin not ready - _set_cmd not configured yet")
                        return
                    self.motor_pwm.set_pwm(cmd_time, pwm_duty)
                    logging.debug("Winder: PWM set - pwm_duty=%.3f (%.1f%%) at time %.3f" % (pwm_duty, pwm_duty * 100, cmd_time))
                else:
                    logging.warning("Winder: Motor PWM pin is None")
            except (AttributeError, Exception) as e:
                logging.warning("Winder: Motor PWM pin error: %s" % e)
        
        toolhead.register_lookahead_callback(set_pwm_callback)
        
        logging.info("Winder: Motor speed set - Motor=%.1f RPM (%.1f%%), Spindle=%.1f RPM" 
                    % (motor_rpm, pwm_duty * 100, self.spindle_rpm_target))
    
    def set_motor_direction(self, forward=True):
        """Set motor direction with proper timing"""
        if self.motor_dir is None:
            return
        
        toolhead = self.printer.lookup_object('toolhead')
        reactor = self.printer.get_reactor()
        eventtime = reactor.monotonic()
        # Use large spacing to avoid timing conflicts
        print_time = toolhead.mcu.estimated_print_time(eventtime) + 0.2
        
        try:
            self.motor_dir.set_digital(print_time, 0 if forward else 1)
            logging.debug("Winder: Motor direction set - forward=%s" % forward)
        except (AttributeError, Exception) as e:
            logging.warning("Winder: Motor direction pin error: %s" % e)
    
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
        
        # Check if MCU is shutdown - if so, can't start
        toolhead = self.printer.lookup_object('toolhead')
        try:
            state_msg, state = self.printer.get_state_message()
            if state != 'ready':
                raise ValueError("Printer not ready (state: %s). Run FIRMWARE_RESTART first." % state)
        except Exception as e:
            logging.warning("Winder: Could not check printer state: %s" % e)
        
        # Set winding flag FIRST so status shows correctly
        self.is_winding = True
        self.current_layer = 0
        
        required_motor_rpm = spindle_rpm / self.spindle_gear_ratio
        self.motor_rpm_target = required_motor_rpm
        self.spindle_rpm_target = spindle_rpm
        
        traverse_speed = self.calculate_traverse_speed(self.spindle_rpm_target, self.wire_diameter)
        
        start_y = self.start_position
        end_y = self.start_position + self.bobbin_width
        
        toolhead.wait_moves()
        
        reactor = self.printer.get_reactor()
        
        # Start sync timer
        reactor.update_timer(self.sync_timer, reactor.monotonic() + (1.0 / self.sync_update_rate))
        
        logging.info("Winder: Starting - Motor=%.1f RPM, Spindle=%.1f RPM, Traverse=%.3f mm/s, Layers=%d" 
                    % (self.motor_rpm_target, self.spindle_rpm_target, traverse_speed, layers))
        
        # Start motor with LARGE delays between commands to avoid "Timer too close"
        # Use sequential reactor callbacks with increasing delays
        # NOTE: Brake and DIR pins are optional for testing - motor can run with PWM only
        def set_direction_callback(eventtime):
            """Set motor direction (OPTIONAL - not required for testing)"""
            try:
                if self.motor_dir:
                    toolhead = self.printer.lookup_object('toolhead')
                    print_time = toolhead.mcu.estimated_print_time(eventtime) + 0.2
                    self.motor_dir.set_digital(print_time, 0)  # Forward
                    logging.info("Winder: Motor direction set (forward)")
                else:
                    logging.info("Winder: Motor direction pin not configured - skipping (OK for testing)")
            except Exception as e:
                logging.warning("Winder: Direction pin not available (OK for testing): %s" % e)
                # Don't fail - motor can run without direction pin
        
        def release_brake_callback(eventtime):
            """Release brake (OPTIONAL - not required for testing)"""
            try:
                if self.motor_brake:
                    toolhead = self.printer.lookup_object('toolhead')
                    print_time = toolhead.mcu.estimated_print_time(eventtime) + 0.2
                    self.motor_brake.set_digital(print_time, 0)  # 0 = brake released
                    logging.info("Winder: Brake released")
                else:
                    logging.info("Winder: Brake pin not configured - skipping (OK for testing)")
            except Exception as e:
                logging.warning("Winder: Brake pin not available (OK for testing): %s" % e)
                # Don't fail - motor can run without brake pin
        
        def set_pwm_callback(eventtime):
            """Set PWM speed (REQUIRED - this is what actually starts the motor)"""
            try:
                # Calculate PWM duty cycle
                pwm_duty_raw = required_motor_rpm / self.max_motor_rpm
                # Apply minimum PWM threshold (some motors need minimum duty to start)
                min_pwm_duty = 0.05  # 5% minimum duty cycle
                pwm_duty = max(min_pwm_duty, min(pwm_duty_raw, 1.0))
                
                logging.info("Winder: Setting PWM - required_motor_rpm=%.1f, max_motor_rpm=%.1f" 
                            % (required_motor_rpm, self.max_motor_rpm))
                logging.info("Winder: PWM calculation - raw=%.4f (%.2f%%), final=%.4f (%.2f%%) [min=%.2f%%]" 
                            % (pwm_duty_raw, pwm_duty_raw * 100, pwm_duty, pwm_duty * 100, min_pwm_duty * 100))
                
                toolhead = self.printer.lookup_object('toolhead')
                print_time = toolhead.mcu.estimated_print_time(eventtime) + 0.2
                
                if self.motor_pwm:
                    # Check if PWM pin is ready
                    if not hasattr(self.motor_pwm, '_set_cmd'):
                        logging.error("Winder: ✗ Motor PWM pin missing _set_cmd attribute")
                        logging.error("Winder: PWM pin type: %s, attributes: %s" % (type(self.motor_pwm), dir(self.motor_pwm)))
                        self.is_winding = False
                        return
                    
                    if self.motor_pwm._set_cmd is None:
                        logging.error("Winder: ✗ Motor PWM pin _set_cmd is None - pin not initialized")
                        logging.error("Winder: PWM pin type: %s, attributes: %s" % (type(self.motor_pwm), dir(self.motor_pwm)))
                        self.is_winding = False
                        return
                    
                    # PWM pin is ready - set PWM
                    logging.info("Winder: PWM pin ready - _set_cmd exists, setting PWM at time %.3f" % print_time)
                    self.motor_pwm.set_pwm(print_time, pwm_duty)
                    logging.info("Winder: ✓ Motor started - PWM duty: %.4f (%.2f%%)" % (pwm_duty, pwm_duty * 100))
                    # Keep is_winding = True (already set earlier)
                else:
                    logging.error("Winder: ✗ Motor PWM pin is None - pin not configured")
                    logging.error("Winder: Check config - motor_pwm_pin should be PC9")
                    self.is_winding = False  # PWM is required - fail if not configured
            except Exception as e:
                logging.error("Winder: ✗ Error setting PWM: %s" % e)
                import traceback
                logging.error("Winder: Traceback: %s" % traceback.format_exc())
                self.is_winding = False  # PWM is required - fail on error
        
        def start_traverse_callback(eventtime):
            """Start traverse motion after motor has started (optional - don't fail if traverse not ready)"""
            try:
                # Check if traverse is homed before starting
                toolhead = self.printer.lookup_object('toolhead')
                status = toolhead.get_status(eventtime)
                homed_axes = status.get('homed_axes', '')
                
                if 'y' in homed_axes:
                    self._start_winding_layer(toolhead, start_y, end_y, traverse_speed, layers)
                    logging.info("Winder: Traverse motion started")
                else:
                    logging.warning("Winder: Traverse not homed - motor running but traverse motion skipped")
                    logging.warning("Winder: Home traverse with G28 Y to enable traverse motion")
            except Exception as e:
                logging.error("Winder: Error starting traverse: %s" % e)
                # Don't set is_winding = False - motor can still run without traverse
        
        # Schedule commands with large delays: 0.2s, 0.5s, 0.8s, 1.2s
        # Increased delays to ensure no timing conflicts
        reactor.register_callback(set_direction_callback, reactor.monotonic() + 0.2)
        reactor.register_callback(release_brake_callback, reactor.monotonic() + 0.5)
        reactor.register_callback(set_pwm_callback, reactor.monotonic() + 0.8)
        reactor.register_callback(start_traverse_callback, reactor.monotonic() + 1.2)
    
    def _start_winding_layer(self, toolhead, start_y, end_y, speed, layers):
        """Generate continuous back-and-forth motion with dynamic speed sync
        The sync algorithm (_sync_traverse_to_spindle) adjusts max_velocity in real-time
        based on measured spindle RPM. This ensures traverse speed matches spindle speed
        for accurate wire layering (critical for 43AWG wire).
        """
        # Set initial max_velocity to allow sync algorithm to work
        # Sync algorithm will adjust this dynamically based on measured RPM
        toolhead.set_max_velocities(speed * 1.1, None, None, None)
        
        for layer in range(layers):
            if not self.is_winding:
                break
            
            # Move forward (start_y -> end_y)
            # Speed will be dynamically adjusted by sync algorithm via max_velocity
            toolhead.manual_move([None, end_y, None, None], speed)
            toolhead.wait_moves()
            
            if not self.is_winding:
                break
            
            # Move backward (end_y -> start_y)
            # Speed will be dynamically adjusted by sync algorithm via max_velocity
            toolhead.manual_move([None, start_y, None, None], speed)
            toolhead.wait_moves()
            
            self.current_layer = layer + 1
            logging.info("Winder: Completed layer %d of %d (RPM: %.1f, Speed: %.3f mm/s)" 
                        % (self.current_layer, layers, self.spindle_measured_rpm, speed))
        
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
        
        # Calculate mapped value if calibrated
        if self.angle_adc_min is not None and self.angle_adc_max is not None:
            adc_min = self.angle_adc_min
            adc_max = self.angle_adc_max
        elif self._angle_calibration_complete:
            adc_min = self._angle_adc_observed_min
            adc_max = self._angle_adc_observed_max
        else:
            adc_min = 0.0
            adc_max = 1.0
        
        adc_range = adc_max - adc_min
        if adc_range > 0.001:
            clamped_adc = max(adc_min, min(adc_max, last_value))
            mapped_value = (clamped_adc - adc_min) / adc_range
            mapped_angle_deg = mapped_value * 360.0
        else:
            mapped_value = last_value
            mapped_angle_deg = angle_deg
        
        # Show raw ADC value for debugging
        cal_info = ""
        if self._angle_calibration_complete or (self.angle_adc_min is not None):
            cal_info = " (calibrated: %.4f-%.4f, mapped: %.4f)" % (adc_min, adc_max, mapped_value)
        gcmd.respond_info("DEBUG: Raw ADC value = %.4f%s" % (last_value, cal_info))
        
        # Show current status
        info = ("Angle Sensor Test:\n"
               "  Raw ADC: %.4f (0.0-1.0)\n"
               "  Mapped ADC: %.4f\n"
               "  Angle (raw): %.2f° (%.3f rad)\n"
               "  Angle (mapped): %.2f°\n"
               "  Last Reading: %.3f seconds ago\n"
               "  Current RPM: %.1f\n"
               "  Total Revolutions: %d" 
               % (last_value, mapped_value, angle_deg, angle_rad, mapped_angle_deg,
                  self.printer.get_reactor().monotonic() - last_time if last_time else 0.0,
                  self.spindle_measured_rpm,
                  self.angle_revolutions if hasattr(self, 'angle_revolutions') else 0))
        
        gcmd.respond_info(info)
        gcmd.respond_info("Rotate the sensor manually to see values change. Use WINDER_STATUS to monitor RPM.")
    
    cmd_ANGLE_SENSOR_CALIBRATE_help = "Calibrate angle sensor min/max values (RESET to clear, MANUAL MIN=0.1 MAX=0.9 to set)"
    def cmd_ANGLE_SENSOR_CALIBRATE(self, gcmd):
        """Calibrate or reset angle sensor min/max mapping"""
        if not self.angle_sensor_adc:
            gcmd.respond_info("ERROR: Angle sensor not configured")
            return
        
        action = gcmd.get('RESET', None)
        if action is not None:
            # Reset calibration
            self._angle_adc_observed_min = None
            self._angle_adc_observed_max = None
            self._angle_calibration_samples = 0
            self._angle_calibration_complete = False
            gcmd.respond_info("Angle sensor calibration reset - will auto-calibrate on next rotation")
            return
        
        manual_min = gcmd.get_float('MIN', None)
        manual_max = gcmd.get_float('MAX', None)
        if manual_min is not None and manual_max is not None:
            # Manual calibration
            if manual_min >= manual_max:
                raise gcmd.error("MIN must be less than MAX")
            self.angle_adc_min = manual_min
            self.angle_adc_max = manual_max
            self._angle_calibration_complete = True
            gcmd.respond_info("Angle sensor manually calibrated: MIN=%.4f, MAX=%.4f" % (manual_min, manual_max))
            return
        
        # Show current calibration status
        status = "Angle Sensor Calibration Status:\n"
        if self.angle_adc_min is not None and self.angle_adc_max is not None:
            status += "  Mode: Manual\n"
            status += "  MIN: %.4f\n" % self.angle_adc_min
            status += "  MAX: %.4f\n" % self.angle_adc_max
            status += "  Range: %.4f\n" % (self.angle_adc_max - self.angle_adc_min)
        elif self._angle_calibration_complete:
            status += "  Mode: Auto-calibrated\n"
            status += "  MIN: %.4f\n" % self._angle_adc_observed_min
            status += "  MAX: %.4f\n" % self._angle_adc_observed_max
            status += "  Range: %.4f\n" % (self._angle_adc_observed_max - self._angle_adc_observed_min)
            status += "  Samples: %d\n" % self._angle_calibration_samples
        else:
            status += "  Mode: Not calibrated (using full 0.0-1.0 range)\n"
            status += "  Samples collected: %d\n" % self._angle_calibration_samples
            if self._angle_adc_observed_min is not None:
                status += "  Observed MIN: %.4f\n" % self._angle_adc_observed_min
            if self._angle_adc_observed_max is not None:
                status += "  Observed MAX: %.4f\n" % self._angle_adc_observed_max
        
        # Get current reading
        last_value, last_time = self.angle_sensor_adc.get_last_value()
        if last_value is not None:
            status += "  Current ADC: %.4f\n" % last_value
        
        status += "\nTo reset: ANGLE_SENSOR_CALIBRATE RESET=1"
        status += "\nTo set manually: ANGLE_SENSOR_CALIBRATE MIN=0.1 MAX=0.9"
        gcmd.respond_info(status)
    
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
