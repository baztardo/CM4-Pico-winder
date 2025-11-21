# Spindle Hall Sensor Module
#
# Copyright (C) 2024
#
# This file may be distributed under the terms of the GNU GPLv3 license.
import logging
from . import pulse_counter

class SpindleHall:
    """Hall sensor for spindle RPM measurement"""
    
    def __init__(self, config):
        self.printer = config.get_printer()
        self.name = config.get_name()
        
        # Pin configuration
        self.hall_pin = config.get('hall_pin')
        
        # Sensor parameters
        self.pulses_per_revolution = config.getint('pulses_per_revolution', 1, minval=1)
        self.sample_time = config.getfloat('sample_time', 0.01, above=0.001)
        self.poll_time = config.getfloat('poll_time', 0.1, above=0.01)
        
        # State
        self.freq_counter = None
        self.current_rpm = 0.0
        self.hall_count = 0
        self._last_count = 0
        
        # RPM smoothing
        self._smoothed_rpm = 0.0
        
        # Register event handlers
        self.printer.register_event_handler("klippy:connect", self.handle_connect)
        
        # Register G-code commands
        gcode = self.printer.lookup_object('gcode')
        gcode.register_command("QUERY_SPINDLE_HALL", self.cmd_QUERY_SPINDLE_HALL,
                               desc=self.cmd_QUERY_SPINDLE_HALL_help)
    
    def handle_connect(self):
        """Setup Hall sensor when MCU connects"""
        logging.info("Spindle Hall sensor '%s' creating counter on pin %s (sample=%.3fs, poll=%.3fs)" 
                    % (self.name, self.hall_pin, self.sample_time, self.poll_time))
        
        # Create frequency counter
        original_counter = pulse_counter.FrequencyCounter(
            self.printer, 
            self.hall_pin,
            self.sample_time,
            self.poll_time
        )
        
        # Access underlying MCU counter to add callback
        mcu_counter = original_counter._counter
        original_callback = mcu_counter._callback
        
        def hall_callback(time, count, count_time):
            """Callback to track Hall sensor pulses"""
            if not hasattr(hall_callback, '_last_count'):
                hall_callback._last_count = 0
            
            delta = count - hall_callback._last_count
            self.hall_count = count
            
            # Update RPM when we see new edges
            if delta > 0:
                # Calculate RPM from frequency
                freq = original_counter.get_frequency()
                if freq > 0:
                    # FrequencyCounter counts edges (both rising and falling)
                    # For pulses_per_revolution=1, 1 pulse = 2 edges
                    edges_per_rev = 2 * self.pulses_per_revolution
                    calculated_rpm = (freq / edges_per_rev) * 60.0
                    
                    # Smooth RPM
                    alpha = 0.3
                    if not hasattr(self, '_smoothed_rpm') or self._smoothed_rpm == 0:
                        self._smoothed_rpm = calculated_rpm
                    else:
                        self._smoothed_rpm = alpha * calculated_rpm + (1.0 - alpha) * self._smoothed_rpm
                    
                    self.current_rpm = self._smoothed_rpm
                else:
                    # No signal - RPM is 0
                    self.current_rpm = 0.0
                    self._smoothed_rpm = 0.0
            
            hall_callback._last_count = count
            
            # Call original callback if it exists
            if original_callback:
                original_callback(time, count, count_time)
        
        mcu_counter.setup_callback(hall_callback)
        self.freq_counter = original_counter
        
        logging.info("Spindle Hall sensor '%s' initialized on %s, counter OID=%d" 
                    % (self.name, self.hall_pin, mcu_counter._oid))
    
    def get_rpm(self):
        """Get current RPM"""
        if self.freq_counter:
            freq = self.freq_counter.get_frequency()
            if freq > 0:
                edges_per_rev = 2 * self.pulses_per_revolution
                return (freq / edges_per_rev) * 60.0
        return 0.0
    
    def get_count(self):
        """Get current pulse count"""
        return self.hall_count
    
    def get_frequency(self):
        """Get current frequency in Hz"""
        if self.freq_counter:
            return self.freq_counter.get_frequency()
        return 0.0
    
    def get_status(self, eventtime):
        """Get status for API"""
        return {
            'rpm': self.current_rpm,
            'count': self.hall_count,
            'frequency': self.get_frequency(),
            'pulses_per_revolution': self.pulses_per_revolution,
        }
    
    # G-code commands
    cmd_QUERY_SPINDLE_HALL_help = "Query spindle Hall sensor status"
    def cmd_QUERY_SPINDLE_HALL(self, gcmd):
        freq = self.get_frequency()
        rpm = self.get_rpm()
        
        gcmd.respond_info("Spindle Hall Sensor '%s':" % self.name)
        gcmd.respond_info("  Pin: %s" % self.hall_pin)
        gcmd.respond_info("  Count: %d" % self.hall_count)
        gcmd.respond_info("  Frequency: %.2f Hz" % freq)
        gcmd.respond_info("  RPM: %.1f" % rpm)
        gcmd.respond_info("  Pulses per revolution: %d" % self.pulses_per_revolution)

def load_config(config):
    return SpindleHall(config)

def load_config_prefix(config):
    # For [spindle_hall main] style sections
    return SpindleHall(config)

