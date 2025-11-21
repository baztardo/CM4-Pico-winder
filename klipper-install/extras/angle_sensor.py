# Angle Sensor Module (ADC-based)
#
# Copyright (C) 2024
#
# This file may be distributed under the terms of the GNU GPLv3 license.
import logging
import math

REPORT_TIME = 0.100  # Report RPM every 100ms
SAMPLE_TIME = 0.001  # Sample ADC every 1ms
SAMPLE_COUNT = 4     # Average 4 samples
CALLBACK_TIME = 0.01 # Callback every 10ms for buffering

class AngleSensor:
    """ADC-based angle sensor with saturation handling and Hall sensor integration"""
    
    # Pre-calculated constants
    RAD_TO_RPM = 60.0 / (2.0 * math.pi)  # ~9.5493
    MIN_TIME_DIFF = 0.0001  # 100 microseconds minimum for valid RPM calculation
    
    def __init__(self, config):
        self.printer = config.get_printer()
        self.name = config.get_name()
        
        # Pin configuration
        self.sensor_pin = config.get('sensor_pin')
        
        # Sensor parameters
        self.max_angle = config.getfloat('max_angle', 360.0, above=0.0)
        self.sensor_vcc = config.getfloat('sensor_vcc', 5.0, above=0.0)
        
        # Calibration
        self.angle_adc_min = config.getfloat('angle_adc_min', None, minval=0.0, maxval=1.0)
        self.angle_adc_max = config.getfloat('angle_adc_max', None, minval=0.0, maxval=1.0)
        self.angle_auto_calibrate = config.getboolean('angle_auto_calibrate', True)
        
        # Saturation threshold
        self.saturation_threshold = config.getfloat('saturation_threshold', 0.95, minval=0.8, maxval=1.0)
        
        # State
        self.mcu_adc = None
        self.current_rpm = 0.0
        self.current_angle = 0.0  # Current angle in degrees
        self.current_angle_rad = 0.0  # Current angle in radians
        self.angle_revolutions = 0  # Full revolutions tracked
        self.is_saturated = False
        
        # Calibration tracking
        self._angle_adc_observed_min = None
        self._angle_adc_observed_max = None
        self._angle_calibration_samples = 0
        self._angle_calibration_complete = False
        
        # Buffering for RPM calculation
        self.angle_buffer = []
        self.angle_buffer_max = 10  # 10 samples = 100ms at 10ms intervals
        
        # RPM smoothing
        self._angle_smoothed_rpm = 0.0
        
        # Last values
        self.last_angle_value = None
        self.last_angle_time = None
        
        # Hall sensor reference (for saturation handling)
        self.spindle_hall = None
        
        # Register event handlers
        self.printer.register_event_handler("klippy:connect", self.handle_connect)
        
        # Register G-code commands
        gcode = self.printer.lookup_object('gcode')
        gcode.register_command("QUERY_ANGLE_SENSOR", self.cmd_QUERY_ANGLE_SENSOR,
                               desc=self.cmd_QUERY_ANGLE_SENSOR_help)
        gcode.register_command("ANGLE_SENSOR_CALIBRATE", self.cmd_ANGLE_SENSOR_CALIBRATE,
                               desc=self.cmd_ANGLE_SENSOR_CALIBRATE_help)
    
    def handle_connect(self):
        """Setup ADC pin when MCU connects"""
        ppins = self.printer.lookup_object('pins')
        self.mcu_adc = ppins.setup_pin('adc', self.sensor_pin)
        
        # Setup ADC sampling and callback
        self.mcu_adc.setup_adc_sample(SAMPLE_TIME, SAMPLE_COUNT)
        self.mcu_adc.setup_adc_callback(CALLBACK_TIME, self._adc_callback)
        
        # Register with query_adc if available
        try:
            query_adc = self.printer.lookup_object('query_adc')
            query_adc.register_adc(self.name, self.mcu_adc)
        except Exception:
            pass  # query_adc not available - ADC callbacks still work
        
        # Try to get spindle_hall reference for saturation handling
        try:
            self.spindle_hall = self.printer.lookup_object('spindle_hall', None)
        except Exception:
            pass
        
        logging.info("Angle sensor '%s' initialized on pin %s" % (self.name, self.sensor_pin))
    
    def _adc_callback(self, read_time, read_value):
        """ADC callback - processes angle sensor readings"""
        # Auto-calibrate if enabled
        if self.angle_auto_calibrate and not self._angle_calibration_complete:
            if self._angle_adc_observed_min is None or read_value < self._angle_adc_observed_min:
                self._angle_adc_observed_min = read_value
            if self._angle_adc_observed_max is None or read_value > self._angle_adc_observed_max:
                self._angle_adc_observed_max = read_value
            
            self._angle_calibration_samples += 1
            
            # Calibrate after 100 samples or when we see full range
            if self._angle_calibration_samples >= 100 or (
                self._angle_adc_observed_min is not None and 
                self._angle_adc_observed_max is not None and
                (self._angle_adc_observed_max - self._angle_adc_observed_min) > 0.5
            ):
                self._angle_calibration_complete = True
                reactor = self.printer.get_reactor()
                saturation_note = ""
                if self._angle_adc_observed_max >= 0.99:
                    saturation_note = " (SATURATED - consider voltage divider)"
                reactor.register_async_callback(
                    lambda et, sn=saturation_note: logging.info(
                        "Angle sensor '%s' auto-calibrated - ADC range: %.4f to %.4f (span: %.4f, VCC: %.2fV)%s" 
                        % (self.name, self._angle_adc_observed_min, self._angle_adc_observed_max,
                           self._angle_adc_observed_max - self._angle_adc_observed_min,
                           self.sensor_vcc, sn)))
        
        # Determine min/max for mapping
        if self.angle_adc_min is not None and self.angle_adc_max is not None:
            adc_min = self.angle_adc_min
            adc_max = self.angle_adc_max
        elif self._angle_calibration_complete:
            adc_min = self._angle_adc_observed_min
            adc_max = self._angle_adc_observed_max
        else:
            adc_min = 0.0
            adc_max = 1.0
        
        # Map ADC value to 0.0-1.0 range
        adc_range = adc_max - adc_min
        if adc_range > 0.001:
            clamped_adc = max(adc_min, min(adc_max, read_value))
            mapped_value = (clamped_adc - adc_min) / adc_range
        else:
            mapped_value = read_value
        
        # Check for saturation
        self.is_saturated = mapped_value >= self.saturation_threshold or read_value >= adc_max
        
        # Convert to radians
        current_angle_rad = mapped_value * 2.0 * math.pi
        current_angle_deg = current_angle_rad * 180.0 / math.pi
        
        # Add to buffer
        hall_count = 0
        if self.spindle_hall:
            hall_count = self.spindle_hall.get_count()
        
        self.angle_buffer.append((read_time, current_angle_rad, hall_count))
        
        # Keep only last N samples
        if len(self.angle_buffer) > self.angle_buffer_max:
            self.angle_buffer.pop(0)
        
        # Process buffer every 100ms
        if len(self.angle_buffer) >= self.angle_buffer_max:
            self._process_buffer()
        
        # Update last values
        self.last_angle_value = current_angle_rad
        self.last_angle_time = read_time
        self.current_angle_rad = current_angle_rad
        self.current_angle = current_angle_deg
    
    def _process_buffer(self):
        """Process buffered samples to calculate RPM"""
        if len(self.angle_buffer) < 2:
            return
        
        first_time, first_angle, first_hall = self.angle_buffer[0]
        last_time, last_angle, last_hall = self.angle_buffer[-1]
        
        time_diff = last_time - first_time
        if time_diff < self.MIN_TIME_DIFF:
            return
        
        # Calculate angle change
        angle_diff_rad = last_angle - first_angle
        
        # Handle wraparound
        if angle_diff_rad > math.pi:
            angle_diff_rad -= 2.0 * math.pi
        elif angle_diff_rad < -math.pi:
            angle_diff_rad += 2.0 * math.pi
        
        # Calculate RPM
        if not self.is_saturated:
            angular_velocity_rad_s = angle_diff_rad / time_diff
            calculated_rpm = abs(angular_velocity_rad_s) * self.RAD_TO_RPM
        else:
            # Use Hall sensor if saturated
            if self.spindle_hall:
                calculated_rpm = self.spindle_hall.get_rpm()
            else:
                calculated_rpm = 0.0
        
        # Smooth RPM
        alpha = 0.3
        if not hasattr(self, '_angle_smoothed_rpm'):
            self._angle_smoothed_rpm = calculated_rpm
        else:
            self._angle_smoothed_rpm = alpha * calculated_rpm + (1.0 - alpha) * self._angle_smoothed_rpm
        
        self.current_rpm = self._angle_smoothed_rpm
        
        # Clear buffer
        self.angle_buffer = []
    
    def get_rpm(self):
        """Get current RPM"""
        return self.current_rpm
    
    def get_angle(self):
        """Get current angle in degrees"""
        return self.current_angle
    
    def get_status(self, eventtime):
        """Get status for API"""
        return {
            'rpm': self.current_rpm,
            'angle': self.current_angle,
            'angle_rad': self.current_angle_rad,
            'revolutions': self.angle_revolutions,
            'saturated': self.is_saturated,
            'calibrated': self._angle_calibration_complete,
            'adc_min': self._angle_adc_observed_min,
            'adc_max': self._angle_adc_observed_max,
        }
    
    # G-code commands
    cmd_QUERY_ANGLE_SENSOR_help = "Query angle sensor status"
    def cmd_QUERY_ANGLE_SENSOR(self, gcmd):
        if not self.mcu_adc:
            gcmd.respond_info("ERROR: Angle sensor not configured")
            return
        
        value, timestamp = self.mcu_adc.get_last_value()
        
        # Map value
        if self._angle_calibration_complete:
            adc_min = self._angle_adc_observed_min
            adc_max = self._angle_adc_observed_max
        else:
            adc_min = 0.0
            adc_max = 1.0
        
        adc_range = adc_max - adc_min
        if adc_range > 0.001:
            mapped_value = (value - adc_min) / adc_range
        else:
            mapped_value = value
        
        angle_deg = mapped_value * 360.0
        
        gcmd.respond_info("Angle Sensor '%s':" % self.name)
        gcmd.respond_info("  ADC: %.6f (raw), %.6f (mapped)" % (value, mapped_value))
        gcmd.respond_info("  Angle: %.2f°" % angle_deg)
        gcmd.respond_info("  RPM: %.1f" % self.current_rpm)
        gcmd.respond_info("  Saturated: %s" % self.is_saturated)
        if self._angle_calibration_complete:
            gcmd.respond_info("  Calibrated: %.4f - %.4f" % (adc_min, adc_max))
    
    cmd_ANGLE_SENSOR_CALIBRATE_help = "Calibrate angle sensor"
    def cmd_ANGLE_SENSOR_CALIBRATE(self, gcmd):
        action = gcmd.get('ACTION', 'RESET').upper()
        
        if action == 'RESET':
            self._angle_calibration_complete = False
            self._angle_adc_observed_min = None
            self._angle_adc_observed_max = None
            self._angle_calibration_samples = 0
            gcmd.respond_info("Angle sensor calibration reset")
        elif action == 'MANUAL':
            adc_min = gcmd.get_float('MIN', None, minval=0.0, maxval=1.0)
            adc_max = gcmd.get_float('MAX', None, minval=0.0, maxval=1.0)
            if adc_min is not None and adc_max is not None:
                self.angle_adc_min = adc_min
                self.angle_adc_max = adc_max
                self._angle_calibration_complete = True
                gcmd.respond_info("Angle sensor manually calibrated: %.4f - %.4f" % (adc_min, adc_max))
            else:
                gcmd.respond_info("ERROR: MIN and MAX required for manual calibration")
        else:
            gcmd.respond_info("ERROR: Unknown action. Use RESET or MANUAL")

def load_config(config):
    return AngleSensor(config)

def load_config_prefix(config):
    # For [angle_sensor spindle] style sections
    return AngleSensor(config)

