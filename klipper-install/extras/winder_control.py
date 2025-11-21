# Winder Control Module - Main Coordinator
#
# Coordinates BLDC motor, angle sensor, Hall sensor, and traverse
# for CNC guitar string winding operations
#
# Copyright (C) 2024
#
# This file may be distributed under the terms of the GNU GPLv3 license.
import logging
import math

class WinderControl:
    """Main coordinator for winder system"""
    
    def __init__(self, config):
        self.printer = config.get_printer()
        self.name = config.get_name()
        
        # Lookup sub-modules (with fallbacks)
        bldc_name = config.get('bldc_motor', 'bldc_motor')
        angle_name = config.get('angle_sensor', 'angle_sensor')
        hall_name = config.get('spindle_hall', 'spindle_hall')
        traverse_name = config.get('traverse', 'traverse')
        
        try:
            self.bldc_motor = self.printer.lookup_object(bldc_name)
        except Exception:
            logging.warning("WinderControl: BLDC motor '%s' not found - motor control disabled" % bldc_name)
            self.bldc_motor = None
        
        try:
            self.angle_sensor = self.printer.lookup_object(angle_name, None)
        except Exception:
            self.angle_sensor = None
        
        try:
            self.spindle_hall = self.printer.lookup_object(hall_name)
        except Exception:
            logging.warning("WinderControl: Spindle Hall sensor '%s' not found" % hall_name)
            self.spindle_hall = None
        
        try:
            self.traverse = self.printer.lookup_object(traverse_name)
        except Exception:
            logging.warning("WinderControl: Traverse '%s' not found" % traverse_name)
            self.traverse = None
        
        # Winding parameters
        self.gear_ratio = config.getfloat('gear_ratio', 0.667, above=0.0, below=1.0)
        self.wire_diameter = config.getfloat('wire_diameter', 0.056, above=0.001)
        self.bobbin_width = config.getfloat('bobbin_width', 12.0, above=0.0)
        self.spindle_edge_offset = config.getfloat('spindle_edge', 38.0, minval=0.0)
        self.home_offset = config.getfloat('home_offset', 2.0, minval=0.0)
        
        # Speed limits
        self.max_spindle_rpm = config.getfloat('max_spindle_rpm', 2000.0, above=0.0)
        self.min_spindle_rpm = config.getfloat('min_spindle_rpm', 10.0, above=0.0)
        
        # Sync parameters
        self.sync_update_rate = config.getfloat('sync_update_rate', 10.0, above=1.0, below=50.0)
        self.sync_tolerance = config.getfloat('sync_tolerance', 0.01, above=0.0, below=0.1)
        
        # State
        self.is_winding = False
        self.current_layer = 0
        self.winding_direction = 1
        self.spindle_rpm_target = 0.0
        self.spindle_rpm_measured = 0.0
        
        # Timers
        self.sync_timer = None
        
        # Register event handlers
        self.printer.register_event_handler("klippy:connect", self.handle_connect)
        self.printer.register_event_handler("klippy:ready", self.handle_ready)
        self.printer.register_event_handler("klippy:shutdown", self.handle_shutdown)
        
        # Register G-code commands
        gcode = self.printer.lookup_object('gcode')
        gcode.register_command("WINDER_START", self.cmd_WINDER_START,
                               desc=self.cmd_WINDER_START_help)
        gcode.register_command("WINDER_STOP", self.cmd_WINDER_STOP,
                               desc=self.cmd_WINDER_STOP_help)
        gcode.register_command("WINDER_SET_RPM", self.cmd_WINDER_SET_RPM,
                               desc=self.cmd_WINDER_SET_RPM_help)
        gcode.register_command("WINDER_SET_LAYER", self.cmd_WINDER_SET_LAYER,
                               desc=self.cmd_WINDER_SET_LAYER_help)
        gcode.register_command("QUERY_WINDER", self.cmd_QUERY_WINDER,
                               desc=self.cmd_QUERY_WINDER_help)
        
        logging.info("WinderControl '%s' initialized" % self.name)
    
    def handle_connect(self):
        """Setup when MCU connects"""
        # Start sync timer
        reactor = self.printer.get_reactor()
        self.sync_timer = reactor.register_timer(self._sync_traverse_to_spindle,
                                                 reactor.NEVER)
    
    def handle_ready(self):
        """Called when Klipper is ready"""
        logging.info("WinderControl '%s' ready" % self.name)
    
    def handle_shutdown(self):
        """Emergency shutdown"""
        self.stop_winding()
    
    def get_spindle_rpm(self):
        """Get current spindle RPM (blended from sensors)"""
        hall_rpm = 0.0
        angle_rpm = 0.0
        
        # Get RPM from Hall sensor (primary)
        if self.spindle_hall:
            hall_rpm = self.spindle_hall.get_rpm()
        
        # Get RPM from angle sensor (secondary)
        if self.angle_sensor:
            angle_rpm = self.angle_sensor.get_rpm()
            is_saturated = self.angle_sensor.is_saturated if hasattr(self.angle_sensor, 'is_saturated') else False
            
            # Blend sensors if both available and angle not saturated
            if hall_rpm > 0 and angle_rpm > 0 and not is_saturated:
                # 70% Hall (reliable), 30% Angle (fine-tune)
                return 0.7 * hall_rpm + 0.3 * angle_rpm
            elif hall_rpm > 0:
                # Use Hall sensor (more reliable, especially during saturation)
                return hall_rpm
            elif angle_rpm > 0:
                # Fallback to angle sensor
                return angle_rpm
        
        # Return Hall sensor if available
        return hall_rpm if hall_rpm > 0 else 0.0
    
    def calculate_traverse_speed(self, spindle_rpm, wire_diameter):
        """Calculate traverse speed to match spindle RPM"""
        if spindle_rpm <= 0:
            return 0.0
        revs_per_second = spindle_rpm / 60.0
        traverse_speed = revs_per_second * wire_diameter
        return traverse_speed
    
    def _sync_traverse_to_spindle(self, eventtime):
        """Real-time sync adjustment based on measured RPM"""
        if not self.is_winding:
            return self.printer.get_reactor().NEVER
        
        try:
            # Get measured RPM
            measured_rpm = self.get_spindle_rpm()
            if measured_rpm <= 0:
                measured_rpm = self.spindle_rpm_target  # Fallback to target
            
            self.spindle_rpm_measured = measured_rpm
            
            # Calculate required traverse speed
            required_speed = self.calculate_traverse_speed(measured_rpm, self.wire_diameter)
            
            if required_speed > 0 and self.traverse:
                toolhead = self.printer.lookup_object('toolhead')
                current_speed = toolhead.get_status(eventtime)['max_velocity']
                
                # Calculate speed error
                speed_error = abs(required_speed - current_speed) / required_speed if required_speed > 0 else 1.0
                
                # Only update if error is significant (>5%)
                if speed_error > 0.05:
                    def update_velocity_callback(print_time):
                        min_spacing = 0.05
                        base_time = max(print_time, toolhead.get_last_move_time() + min_spacing)
                        toolhead.set_max_velocities(required_speed * 1.1, None, None, None)
                    
                    toolhead.register_lookahead_callback(update_velocity_callback)
            
            return eventtime + (1.0 / self.sync_update_rate)
            
        except Exception as e:
            logging.warning("WinderControl: Sync error: %s" % e)
            return eventtime + 0.1
    
    def start_winding(self, spindle_rpm, layers=1, direction='forward'):
        """Start winding operation"""
        if spindle_rpm < self.min_spindle_rpm:
            raise ValueError("RPM too low (min: %.1f)" % self.min_spindle_rpm)
        if spindle_rpm > self.max_spindle_rpm:
            raise ValueError("RPM too high (max: %.1f)" % self.max_spindle_rpm)
        
        # Check printer state
        try:
            state_msg, state = self.printer.get_state_message()
            if state != 'ready':
                raise ValueError("Printer not ready (state: %s)" % state)
        except Exception as e:
            logging.warning("WinderControl: Could not check printer state: %s" % e)
        
        self.is_winding = True
        self.current_layer = 0
        self.spindle_rpm_target = spindle_rpm
        self.winding_direction = 1 if direction == 'forward' else -1
        
        # Calculate motor RPM
        motor_rpm = spindle_rpm / self.gear_ratio
        
        # Start BLDC motor
        if self.bldc_motor:
            self.bldc_motor.start_motor(rpm=motor_rpm, forward=(direction == 'forward'))
        else:
            logging.warning("WinderControl: BLDC motor not available - cannot start motor")
        
        # Calculate traverse speed
        traverse_speed = self.calculate_traverse_speed(spindle_rpm, self.wire_diameter)
        
        # Start sync timer
        reactor = self.printer.get_reactor()
        reactor.update_timer(self.sync_timer, reactor.monotonic() + (1.0 / self.sync_update_rate))
        
        # Start traverse motion (if available)
        if self.traverse:
            start_y = self.spindle_edge_offset
            end_y = self.spindle_edge_offset + self.bobbin_width
            
            # Start traverse motion after motor has started
            def start_traverse_callback(eventtime):
                try:
                    if self.traverse.is_homed:
                        # Start layer winding
                        self._start_winding_layer(start_y, end_y, traverse_speed, layers)
                    else:
                        logging.warning("WinderControl: Traverse not homed - motor running but traverse motion skipped")
                except Exception as e:
                    logging.error("WinderControl: Error starting traverse: %s" % e)
            
            reactor.register_callback(start_traverse_callback, reactor.monotonic() + 1.2)
        
        logging.info("WinderControl: Starting - Spindle=%.1f RPM, Motor=%.1f RPM, Traverse=%.3f mm/s, Layers=%d" %
                    (spindle_rpm, motor_rpm, traverse_speed, layers))
    
    def _start_winding_layer(self, start_y, end_y, traverse_speed, layers):
        """Start winding layer motion"""
        toolhead = self.printer.lookup_object('toolhead')
        
        for layer in range(layers):
            # Move forward
            toolhead.manual_move([None, end_y, None, None], traverse_speed)
            # Move backward
            toolhead.manual_move([None, start_y, None, None], traverse_speed)
        
        self.current_layer = layers
    
    def stop_winding(self):
        """Stop winding operation"""
        self.is_winding = False
        
        # Stop BLDC motor
        if self.bldc_motor:
            self.bldc_motor.stop_motor()
        
        # Stop sync timer
        reactor = self.printer.get_reactor()
        if self.sync_timer:
            reactor.update_timer(self.sync_timer, reactor.NEVER)
        
        logging.info("WinderControl: Stopped")
    
    def get_status(self, eventtime):
        """Get status for API"""
        return {
            'is_winding': self.is_winding,
            'spindle_rpm_target': self.spindle_rpm_target,
            'spindle_rpm_measured': self.get_spindle_rpm(),
            'current_layer': self.current_layer,
            'wire_diameter': self.wire_diameter,
            'bobbin_width': self.bobbin_width,
            'gear_ratio': self.gear_ratio,
        }
    
    # G-code commands
    cmd_WINDER_START_help = "Start winding operation"
    def cmd_WINDER_START(self, gcmd):
        rpm = gcmd.get_float('RPM', minval=self.min_spindle_rpm, maxval=self.max_spindle_rpm)
        layers = gcmd.get_int('LAYERS', 1, minval=1)
        direction = gcmd.get('DIRECTION', 'forward').lower()
        
        try:
            self.start_winding(rpm, layers, direction)
            gcmd.respond_info("Winder started: %.1f RPM, %d layers, %s" % (rpm, layers, direction))
        except Exception as e:
            gcmd.respond_info("ERROR: %s" % str(e))
    
    cmd_WINDER_STOP_help = "Stop winding operation"
    def cmd_WINDER_STOP(self, gcmd):
        self.stop_winding()
        gcmd.respond_info("Winder stopped")
    
    cmd_WINDER_SET_RPM_help = "Set winding RPM"
    def cmd_WINDER_SET_RPM(self, gcmd):
        rpm = gcmd.get_float('RPM', minval=self.min_spindle_rpm, maxval=self.max_spindle_rpm)
        self.spindle_rpm_target = rpm
        
        if self.bldc_motor:
            motor_rpm = rpm / self.gear_ratio
            self.bldc_motor.set_rpm(motor_rpm)
        
        gcmd.respond_info("Winder RPM set to %.1f" % rpm)
    
    cmd_WINDER_SET_LAYER_help = "Set current layer"
    def cmd_WINDER_SET_LAYER(self, gcmd):
        layer = gcmd.get_int('LAYER', minval=0)
        self.current_layer = layer
        gcmd.respond_info("Winder layer set to %d" % layer)
    
    cmd_QUERY_WINDER_help = "Query winder status"
    def cmd_QUERY_WINDER(self, gcmd):
        status = self.get_status(None)
        gcmd.respond_info("Winder Control '%s':" % self.name)
        gcmd.respond_info("  Winding: %s" % status['is_winding'])
        gcmd.respond_info("  RPM: %.1f / %.1f (target)" % (status['spindle_rpm_measured'], status['spindle_rpm_target']))
        gcmd.respond_info("  Layer: %d" % status['current_layer'])
        gcmd.respond_info("  Wire diameter: %.3f mm" % status['wire_diameter'])
        gcmd.respond_info("  Bobbin width: %.2f mm" % status['bobbin_width'])

def load_config(config):
    return WinderControl(config)

def load_config_prefix(config):
    # For [winder_control main] style sections
    return WinderControl(config)

