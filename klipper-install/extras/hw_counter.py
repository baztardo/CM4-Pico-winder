# Hardware Counter Module - Ultra-fast timer polling
#
# Copyright (C) 2024
#
# This file may be distributed under the terms of the GNU GPLv3 license.
#
# Uses ultra-fast timer polling (10-50 microseconds) to catch every edge
# Follows Klipper architecture (timer-based) but at maximum speed

import logging

class HardwareCounter:
    """Hardware-based edge counter using ultra-fast timer polling"""
    
    def __init__(self, printer, pin, sample_time=0.1):
        self.printer = printer
        self.name = "hw_counter"
        
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
        self._last_count = 0
        self._callback = None
        
        # Register config callback
        self._mcu.register_config_callback(self.build_config)
        
        logging.info("HardwareCounter: Initialized on pin %s (EXTI hardware interrupt mode)" % pin)
    
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
        self._mcu.add_config_cmd("query_hw_counter oid=%d clock=%d sample_ticks=%d"
                                % (self._oid, clock, self._sample_ticks), 
                                is_init=True)
        
        # Register response handler
        self._mcu.register_response(self._handle_hw_counter_state,
                                   "hw_counter_state", self._oid)
        
        logging.info("HardwareCounter: Configured (sample_time=%.3fs, EXTI interrupts enabled)" 
                    % self._sample_time)
    
    def _handle_hw_counter_state(self, params):
        """Handle counter state updates from MCU"""
        count = params['count']
        count_time = self._mcu.clock32_to_clock64(params['count_clock'])
        time = self._mcu.clock_to_print_time(count_time)
        
        # Handle 32-bit overflow
        delta_count = (count - self._last_count) & 0xFFFFFFFF
        self._count = self._last_count + delta_count
        self._last_count = self._count
        
        # Call callback if registered
        if self._callback is not None:
            self._callback(time, self._count, count_time)
    
    def setup_callback(self, callback):
        """Register callback for count updates"""
        self._callback = callback
    
    def get_count(self):
        """Get current count"""
        return self._count
    
    def reset_count(self):
        """Reset count to zero"""
        self._count = 0
        self._last_count = 0
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
    
    def get_status(self, eventtime):
        """Get status for API (compatible with spindle_hall interface)"""
        return {
            'count': self._count,
            'rpm': self.get_rpm(),
            'frequency': self.get_frequency(),
        }

def load_config(config):
    return HardwareCounter(
        config.get_printer(),
        config.get('pin'),
        config.getfloat('sample_time', 0.1, above=0.01)
    )

def load_config_prefix(config):
    return load_config(config)

