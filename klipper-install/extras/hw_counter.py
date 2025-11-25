# Hardware Counter Module - Ultra-fast timer polling
#
# Copyright (C) 2024
#
# This file may be distributed under the terms of the GNU GPLv3 license.
#
# Uses ultra-fast timer polling (10-50 microseconds) to catch every edge
# Follows Klipper architecture (timer-based) but at maximum speed

import logging
import math

class HardwareCounter:
    """Hardware-based edge counter using ultra-fast timer polling"""
    
    def __init__(self, printer, pin, sample_time=0.1):
        self.printer = printer
        self.name = "hw_counter"
        self.gcode = printer.lookup_object('gcode')
        
        # Pin configuration
        ppins = printer.lookup_object('pins')
        pin_params = ppins.lookup_pin(pin, can_pullup=True)
        self._mcu = pin_params['chip']
        self._oid = self._mcu.create_oid()
        self._pin = pin_params['pin']
        self._pullup = pin_params['pullup']
        
        # Timing
        self._sample_time = sample_time
        self._sample_ticks = 0
        
        # State
        self._count = 0
        self._total_count = 0
        self._last_raw_count = None
        self._callback = None
        self._force_cmd = None
        
        # Register config callback
        self._mcu.register_config_callback(self.build_config)
        
        logging.info("HardwareCounter: Initialized on pin %s (EXTI hardware interrupt mode)" % pin)
        
        # Calibration mode
        self.calibration_mode = False
        self.calibration_data = []  # Store (count, raw_adc, angle_deg)
        self.calibration_adc_min = None
        self.calibration_adc_max = None
        
        # G-code commands
        self.gcode.register_command("QUERY_HW_COUNTER", self.cmd_QUERY_HW_COUNTER,
                                    desc="Report hardware hall counter status")
        self.gcode.register_command("CALIBRATE_ANGLE_SENSOR", self.cmd_CALIBRATE_ANGLE_SENSOR,
                                    desc="Start/stop angle sensor calibration mode")
    
    def build_config(self):
        """Configure MCU hardware counter"""
        # Send config command with pull_up parameter
        self._mcu.add_config_cmd("config_hw_counter oid=%d pin=%s pull_up=%d"
                                % (self._oid, self._pin, self._pullup))
        
        # Calculate sample ticks
        self._sample_ticks = self._mcu.seconds_to_clock(self._sample_time)
        
        # Get clock for query command
        clock = self._mcu.get_query_slot(self._oid)
        
        # Send query command
        self._mcu.add_config_cmd("query_hw_counter oid=%d clock=%u sample_ticks=%u"
                                % (self._oid, clock, self._sample_ticks), 
                                is_init=True)
        
        # Register response handler
        self._mcu.register_response(self._handle_hw_counter_state,
                                   "hw_counter_state", self._oid)
        
        # Lookup force command for synchronous updates
        self._force_cmd = self._mcu.lookup_command(
            "force_hw_counter oid=%c", cq=self._mcu.alloc_command_queue())
        
        logging.info("HardwareCounter: Configured (sample_time=%.3fs, EXTI interrupts enabled)" 
                    % self._sample_time)
    
    def _handle_hw_counter_state(self, params):
        """Handle counter state updates from MCU"""
        raw_count = params['count']
        count_time = self._mcu.clock32_to_clock64(params['count_clock'])
        time = self._mcu.clock_to_print_time(count_time)
        
        if self._last_raw_count is None:
            self._last_raw_count = raw_count
        
        # Handle 32-bit overflow
        delta_count = (raw_count - self._last_raw_count) & 0xFFFFFFFF
        self._total_count += delta_count
        self._count = self._total_count
        self._last_raw_count = raw_count
        
        # Log calibration data if in calibration mode and count changed
        if self.calibration_mode and delta_count > 0:
            self._log_calibration_data()
        
        # Call callback if registered
        if self._callback is not None:
            self._callback(time, self._count, count_time)
    
    def setup_callback(self, callback):
        """Register callback for count updates"""
        self._callback = callback
    
    # G-code helpers
    def cmd_QUERY_HW_COUNTER(self, gcmd):
        gcmd.respond_info("Hardware Hall Counter:")
        gcmd.respond_info("  Pin: %s" % self._pin)
        gcmd.respond_info("  Count: %d" % self._count)
        gcmd.respond_info("  Sample time: %.4fs" % self._sample_time)
        gcmd.respond_info("  RPM: %.2f" % self.get_rpm())
    
    def get_count(self):
        """Get current count"""
        return self._count
    
    def force_update(self):
        """Request an immediate MCU state report"""
        if self._force_cmd is None:
            return
        self._force_cmd.send([self._oid])
        self.printer.get_reactor().pause(self._sample_time * 1.5)
    
    def reset_count(self):
        """Reset count to zero"""
        self._count = 0
        self._total_count = 0
        self._last_raw_count = None
        logging.info("HardwareCounter: Count reset to 0")
    
    def get_rpm(self):
        """Calculate RPM from edge count (compatible with spindle_hall interface)"""
        # Calculate RPM from recent count changes
        if hasattr(self, '_last_rpm_time') and hasattr(self, '_last_rpm_count'):
            current_time = self.printer.get_reactor().monotonic()
            time_delta = current_time - self._last_rpm_time
            count_delta = self._count - self._last_rpm_count
            
            if time_delta > 0.1 and count_delta > 0:  # At least 100ms between calculations
                # 2 edges per revolution (rising + falling)
                revolutions = count_delta / 2.0
                rpm = (revolutions / time_delta) * 60.0
                
                # Update for next calculation
                self._last_rpm_time = current_time
                self._last_rpm_count = self._count
                self._current_rpm = rpm
                return rpm
        
        # Initialize or return last known RPM
        if not hasattr(self, '_last_rpm_time'):
            self._last_rpm_time = self.printer.get_reactor().monotonic()
            self._last_rpm_count = self._count
            self._current_rpm = 0.0
        
        return self._current_rpm if hasattr(self, '_current_rpm') else 0.0
    
    def get_frequency(self):
        """Get frequency in Hz (compatible with spindle_hall interface)"""
        rpm = self.get_rpm()
        if rpm > 0:
            return (rpm / 60.0) * 2.0  # 2 edges per revolution
        return 0.0
    
    def _log_calibration_data(self):
        """Log RAW ADC and angle when hall pulse fires (calibration mode)"""
        try:
            # Get angle sensor
            angle_sensor = self.printer.lookup_object('angle_sensor', None)
            if angle_sensor:
                # Get RAW ADC value from the last ADC callback
                raw_adc = getattr(angle_sensor, '_last_raw_adc', None)
                
                # Get mapped angle
                angle = angle_sensor.get_angle()
                angle_deg = angle % 360.0
                
                # Track min/max RAW ADC
                if raw_adc is not None:
                    if self.calibration_adc_min is None or raw_adc < self.calibration_adc_min:
                        self.calibration_adc_min = raw_adc
                    if self.calibration_adc_max is None or raw_adc > self.calibration_adc_max:
                        self.calibration_adc_max = raw_adc
                    
                    self.calibration_data.append((self._count, raw_adc, angle_deg))
                    logging.info("CALIBRATION: Hall count=%d, RAW_ADC=%.6f, Angle=%.2f°" 
                                % (self._count, raw_adc, angle_deg))
                else:
                    logging.warning("CALIBRATION: Hall count=%d, RAW_ADC=None (not available yet)" 
                                   % self._count)
        except Exception as e:
            logging.error("Error logging calibration data: %s" % e)
    
    def get_status(self, eventtime):
        """Get status for API (compatible with spindle_hall interface)"""
        return {
            'count': self._count,
            'rpm': self.get_rpm(),
            'frequency': self.get_frequency(),
        }
    
    cmd_CALIBRATE_ANGLE_SENSOR_help = "Start/stop angle sensor calibration"
    def cmd_CALIBRATE_ANGLE_SENSOR(self, gcmd):
        """Toggle calibration mode - logs RAW ADC and angle at every hall pulse"""
        action = gcmd.get('ACTION', 'START').upper()
        
        if action == 'START':
            self.calibration_mode = True
            self.calibration_data = []
            self.calibration_adc_min = None
            self.calibration_adc_max = None
            gcmd.respond_info("Angle sensor calibration STARTED - logging RAW ADC at each hall pulse")
            logging.info("=" * 80)
            logging.info("ANGLE SENSOR CALIBRATION STARTED")
            logging.info("=" * 80)
        elif action == 'STOP':
            self.calibration_mode = False
            gcmd.respond_info("Angle sensor calibration STOPPED - %d samples collected" % len(self.calibration_data))
            
            # Analyze results
            if len(self.calibration_data) > 0:
                raw_adcs = [d[1] for d in self.calibration_data]
                angles = [d[2] for d in self.calibration_data]
                
                # RAW ADC statistics
                adc_mean = sum(raw_adcs) / len(raw_adcs)
                adc_std = (sum((a - adc_mean)**2 for a in raw_adcs) / len(raw_adcs)) ** 0.5
                adc_min = min(raw_adcs)
                adc_max = max(raw_adcs)
                
                # Angle statistics
                angle_mean = sum(angles) / len(angles)
                angle_std = (sum((a - angle_mean)**2 for a in angles) / len(angles)) ** 0.5
                angle_min = min(angles)
                angle_max = max(angles)
                
                logging.info("=" * 80)
                logging.info("CALIBRATION RESULTS:")
                logging.info("-" * 80)
                logging.info("HALL PULSES:")
                logging.info("  Total samples: %d" % len(self.calibration_data))
                logging.info("-" * 80)
                logging.info("RAW ADC AT HALL PULSES:")
                logging.info("  Mean: %.6f" % adc_mean)
                logging.info("  Std dev: %.6f (±%.2f%%)" % (adc_std, (adc_std/adc_mean)*100 if adc_mean > 0 else 0))
                logging.info("  Min: %.6f" % adc_min)
                logging.info("  Max: %.6f" % adc_max)
                logging.info("  Range: %.6f (%.2f%% of full scale)" % (adc_max - adc_min, (adc_max - adc_min)*100))
                if adc_std < 0.01:
                    logging.info("  ✓ EXCELLENT: Very repeatable (±%.4f)" % adc_std)
                elif adc_std < 0.05:
                    logging.info("  ✓ GOOD: Repeatable (±%.4f)" % adc_std)
                else:
                    logging.info("  ✗ WARNING: High variation (±%.4f)" % adc_std)
                logging.info("-" * 80)
                logging.info("RAW ADC RANGE (during entire run):")
                if self.calibration_adc_min is not None and self.calibration_adc_max is not None:
                    logging.info("  Min: %.6f" % self.calibration_adc_min)
                    logging.info("  Max: %.6f" % self.calibration_adc_max)
                    logging.info("  Span: %.6f (%.2f%% of full scale)" 
                                % (self.calibration_adc_max - self.calibration_adc_min,
                                   (self.calibration_adc_max - self.calibration_adc_min)*100))
                    if self.calibration_adc_min < 0.05 or self.calibration_adc_max > 0.95:
                        logging.info("  ✗ WARNING: Sensor approaching saturation!")
                    else:
                        logging.info("  ✓ GOOD: No saturation detected")
                logging.info("-" * 80)
                logging.info("ANGLE AT HALL PULSES:")
                logging.info("  Mean: %.2f°" % angle_mean)
                logging.info("  Std dev: %.2f°" % angle_std)
                logging.info("  Min: %.2f°" % angle_min)
                logging.info("  Max: %.2f°" % angle_max)
                logging.info("  Range: %.2f°" % (angle_max - angle_min))
                if angle_std < 5.0:
                    logging.info("  ✓ GOOD: Repeatable (±%.1f°)" % angle_std)
                else:
                    logging.info("  ✗ BAD: Too much variation (±%.1f°)" % angle_std)
                logging.info("=" * 80)
                
                gcmd.respond_info("RAW ADC: %.6f (±%.6f) | Angle: %.2f° (±%.2f°)" 
                                 % (adc_mean, adc_std, angle_mean, angle_std))
        else:
            gcmd.respond_info("Usage: CALIBRATE_ANGLE_SENSOR ACTION=START|STOP")

def load_config(config):
    return HardwareCounter(
        config.get_printer(),
        config.get('pin'),
        config.getfloat('sample_time', 0.1, above=0.01)
    )

def load_config_prefix(config):
    return load_config(config)

