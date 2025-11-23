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
        
        # Create MCU counter EARLY (in __init__) so build_config runs during MCU config phase
        # This ensures query_counter command with is_init=True gets sent properly
        logging.info("Spindle Hall sensor '%s' creating counter on pin %s (sample=%.3fs, poll=%.3fs)" 
                    % (self.name, self.hall_pin, self.sample_time, self.poll_time))
        
        mcu_counter = pulse_counter.MCU_counter(
            self.printer,
            self.hall_pin,
            self.sample_time,
            self.poll_time
        )
        def hall_callback(time, count, count_time):
            """Callback to track Hall sensor pulses and calculate RPM"""
            if not hasattr(hall_callback, '_last_count'):
                hall_callback._last_count = 0
                hall_callback._last_time = None
                hall_callback._callback_num = 0
            
            hall_callback._callback_num += 1
            
            # DEBUG: Log EVERY callback for first 20
            if hall_callback._callback_num <= 20:
                logging.info("Spindle Hall callback #%d: time=%.3f, count=%d, count_time=%.3f" %
                            (hall_callback._callback_num, time, count, count_time))
            
            # Update count
            delta = count - hall_callback._last_count
            self.hall_count = count
            
            # Calculate RPM from count changes
            if delta > 0 and hall_callback._last_time is not None:
                delta_time = count_time - hall_callback._last_time
                if delta_time > 0:
                    # Calculate frequency (edges per second)
                    freq = delta / delta_time
                    # Convert to RPM (pulses_per_revolution=1, 2 edges per pulse)
                    edges_per_rev = 2 * self.pulses_per_revolution
                    calculated_rpm = (freq / edges_per_rev) * 60.0
                    
                    # Smooth RPM
                    alpha = 0.3
                    if self._smoothed_rpm == 0:
                        self._smoothed_rpm = calculated_rpm
                    else:
                        self._smoothed_rpm = alpha * calculated_rpm + (1.0 - alpha) * self._smoothed_rpm
                    
                    self.current_rpm = self._smoothed_rpm
                    
                    # Debug logging occasionally
                    if hall_callback._callback_num % 50 == 0:
                        logging.info("Spindle Hall: delta=%d, delta_time=%.3f, freq=%.2f Hz, RPM=%.1f" %
                                    (delta, delta_time, freq, calculated_rpm))
            
            hall_callback._last_count = count
            hall_callback._last_time = count_time
        
        mcu_counter.setup_callback(hall_callback)
        self.freq_counter = mcu_counter
        
        logging.info("Spindle Hall sensor '%s' initialized on %s, counter OID=%d" 
                    % (self.name, self.hall_pin, mcu_counter._oid))
        
        # Register event handlers
        self.printer.register_event_handler("klippy:ready", self.handle_ready)
        
        # Register G-code commands
        gcode = self.printer.lookup_object('gcode')
        gcode.register_command("QUERY_SPINDLE_HALL", self.cmd_QUERY_SPINDLE_HALL,
                               desc=self.cmd_QUERY_SPINDLE_HALL_help)
    
    def handle_ready(self):
        """Ensure counter is started when system is ready"""
        # The counter should already be started by build_config, but log to confirm
        if self.freq_counter:
            mcu = self.freq_counter._mcu
            logging.info("Spindle Hall sensor '%s' ready - counter OID=%d on MCU '%s'" %
                        (self.name, self.freq_counter._oid, mcu._name))
    
    def get_rpm(self):
        """Get current RPM"""
        return self.current_rpm
    
    def get_count(self):
        """Get current pulse count"""
        return self.hall_count
    
    def reset_count(self):
        """Reset the pulse count to zero"""
        self.hall_count = 0
        self._last_count = 0
        logging.info("Spindle Hall sensor '%s' count reset to 0" % self.name)
    
    def get_frequency(self):
        """Get current frequency in Hz"""
        # Calculate frequency from RPM
        if self.current_rpm > 0:
            edges_per_rev = 2 * self.pulses_per_revolution
            return (self.current_rpm / 60.0) * edges_per_rev
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
