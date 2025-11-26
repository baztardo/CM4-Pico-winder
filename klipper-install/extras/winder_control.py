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
        self.wire_coating_margin = config.getfloat('wire_coating_margin', 0.0, minval=0.0, maxval=0.020)
        self.bobbin_width = config.getfloat('bobbin_width', 12.0, above=0.0)
        self.spindle_edge_offset = config.getfloat('spindle_edge', 38.0, minval=0.0)
        self.home_offset = config.getfloat('home_offset', 2.0, minval=0.0)
        
        # Calculate effective wire diameter (bare wire + coating)
        self.effective_wire_diameter = self.wire_diameter + self.wire_coating_margin
        
        # Speed limits
        self.max_spindle_rpm = config.getfloat('max_spindle_rpm', 2000.0, above=0.0)
        self.min_spindle_rpm = config.getfloat('min_spindle_rpm', 10.0, above=0.0)
        
        # Motor speed calibration factor (compensates for non-linear motor response)
        self.motor_speed_calibration = config.getfloat('motor_speed_calibration', 1.0, above=0.5, below=2.0)
        
        # Hall sensor correction factor (compensates for missed edges / double edges)
        # Can be < 1.0 if counting both edges (e.g., 0.5 for edge-to-revolution conversion)
        self.hall_sensor_correction = config.getfloat('hall_sensor_correction', 1.0, minval=0.1, maxval=5.0)
        
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
    
    def calculate_traverse_speed(self, spindle_rpm, wire_diameter=None):
        """Calculate traverse speed to match spindle RPM
        
        Args:
            spindle_rpm: Spindle RPM
            wire_diameter: Wire diameter (defaults to effective_wire_diameter)
        """
        if spindle_rpm <= 0:
            return 0.0
        
        # Use effective wire diameter (bare + coating) if not specified
        if wire_diameter is None:
            wire_diameter = self.effective_wire_diameter
        
        revs_per_second = spindle_rpm / 60.0
        traverse_speed = revs_per_second * wire_diameter
        return traverse_speed
    
    def _sync_traverse_to_spindle(self, eventtime):
        """Real-time sync adjustment based on measured RPM with motor feedback correction"""
        if not self.is_winding:
            return self.printer.get_reactor().NEVER
        
        # DISABLED: Closed-loop RPM correction causing "Timer too close" MCU shutdowns
        # The unstable RPM readings (0-300 RPM jumps) cause constant motor speed changes
        # that overwhelm the MCU scheduler, especially at slow traverse speeds (0.36mm/s)
        #
        # TODO: Re-enable after fixing:
        # 1. Angle sensor RPM calculation (needs better filtering)
        # 2. Hall sensor not working (Count: 0)
        # 3. Add rate limiting to motor speed changes (max 1 change per second)
        
        return eventtime + (1.0 / self.sync_update_rate)
    
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
        
        # Move to start position FIRST (before starting motor)
        if self.traverse:
            is_homed = self.traverse.check_homed() if hasattr(self.traverse, 'check_homed') else self.traverse.is_homed
            if is_homed:
                start_y = self.spindle_edge_offset
                gcode = self.printer.lookup_object('gcode')
                toolhead = self.printer.lookup_object('toolhead')
                current_pos = toolhead.get_position()
                
                logging.info("WinderControl: Moving to start position Y%.2f from Y%.2f" % (start_y, current_pos[1]))
                gcode.run_script_from_command("G1 Y%.2f F300" % start_y)
                logging.info("WinderControl: At start position Y%.2f" % start_y)
            else:
                logging.warning("WinderControl: Traverse not homed - cannot move to start position. Run G28 Y first.")
        
        self.is_winding = True
        self.current_layer = 0
        self.spindle_rpm_target = spindle_rpm
        self.winding_direction = 1 if direction == 'forward' else -1
        
        # Track winding session for completion report
        reactor = self.printer.get_reactor()
        self.winding_start_time = reactor.monotonic()
        self.winding_commanded_rpm = spindle_rpm
        self.winding_commanded_layers = layers
        self.winding_expected_turns = 0  # Will be calculated below
        
        # Reset sensor turn counters at start
        if self.angle_sensor and hasattr(self.angle_sensor, 'reset_turn_count'):
            self.angle_sensor.reset_turn_count()
        if self.spindle_hall and hasattr(self.spindle_hall, 'reset_count'):
            self.spindle_hall.reset_count()
        
        # Calculate motor RPM with calibration factor
        motor_rpm = (spindle_rpm / self.gear_ratio) * self.motor_speed_calibration
        
        # Start BLDC motor
        if self.bldc_motor:
            self.bldc_motor.start_motor(rpm=motor_rpm, forward=(direction == 'forward'))
        else:
            logging.warning("WinderControl: BLDC motor not available - cannot start motor")
        
        # Calculate traverse speed using effective wire diameter
        traverse_speed = self.calculate_traverse_speed(spindle_rpm)
        
        # Calculate expected turns per layer for verification
        # NOTE: 1 layer = 1 pass (either forward OR backward)
        traverse_per_layer = self.bobbin_width
        turns_per_layer = traverse_per_layer / self.effective_wire_diameter
        total_expected_turns = turns_per_layer * layers
        
        logging.info("WinderControl: Wire diameter: %.4f mm bare + %.4f mm coating = %.4f mm effective" %
                    (self.wire_diameter, self.wire_coating_margin, self.effective_wire_diameter))
        logging.info("WinderControl: Expected turns per layer: %.1f (%.3f mm / %.4f mm wire)" %
                    (turns_per_layer, self.bobbin_width, self.effective_wire_diameter))
        logging.info("WinderControl: Total expected turns for %d layers: %.1f" %
                    (layers, total_expected_turns))
        
        # Store for completion report
        self.winding_expected_turns = total_expected_turns
        logging.info("WinderControl: Traverse speed: %.4f mm/s (%.1f RPM × %.4f mm wire)" %
                    (traverse_speed, spindle_rpm, self.effective_wire_diameter))
        logging.info("WinderControl: Gear ratio: %.3f (motor RPM %.1f → spindle RPM %.1f)" %
                    (self.gear_ratio, motor_rpm, spindle_rpm))
        
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
                    # Check if homed
                    is_homed = self.traverse.check_homed() if hasattr(self.traverse, 'check_homed') else self.traverse.is_homed
                    
                    if is_homed:
                        # Start layer winding (already at start position from earlier move)
                        logging.info("WinderControl: Starting traverse motion - start=%.2f, end=%.2f, speed=%.3f mm/s" %
                                    (start_y, end_y, traverse_speed))
                        self._start_winding_layer(start_y, end_y, traverse_speed, layers)
                    else:
                        logging.warning("WinderControl: Traverse not homed - motor running but traverse motion skipped. Run G28 Y first.")
                except Exception as e:
                    logging.error("WinderControl: Error starting traverse: %s" % e)
                    import traceback
                    logging.error("WinderControl: Traceback: %s" % traceback.format_exc())
            
            reactor.register_callback(start_traverse_callback, reactor.monotonic() + 1.2)
        
        logging.info("WinderControl: Starting - Spindle=%.1f RPM, Motor=%.1f RPM, Traverse=%.3f mm/s, Layers=%d" %
                    (spindle_rpm, motor_rpm, traverse_speed, layers))
    
    def _start_winding_layer(self, start_y, end_y, traverse_speed, layers):
        """Start winding layer motion with proper back-and-forth using non-blocking callbacks"""
        reactor = self.printer.get_reactor()
        
        # State for the winding loop
        self.winding_state = {
            'current_pass': 0,   # 1 pass == 1 layer
            'total_passes': layers,
            'start_y': start_y,
            'end_y': end_y,
            'traverse_speed': traverse_speed,
            'direction': 'forward'  # Start moving forward
        }
        
        # Start first move
        self._execute_next_winding_move()
    
    def _execute_next_winding_move(self):
        """Execute next move in winding sequence (non-blocking)"""
        if not self.is_winding or not hasattr(self, 'winding_state'):
            return
        
        state = self.winding_state
        
        # Check if all passes complete
        if state['current_pass'] >= state['total_passes']:
            logging.info("WinderControl: Winding complete - %d layers finished" % state['total_passes'])
            self.stop_winding()
            return
        
        gcode = self.printer.lookup_object('gcode')
        
        # Determine target position based on direction
        moving_forward = state['direction'] == 'forward'
        target_y = state['end_y'] if moving_forward else state['start_y']
        next_direction = 'backward' if moving_forward else 'forward'
        
        logging.info("WinderControl: Layer %d/%d - Moving %s to %.2f mm at %.3f mm/s" %
                    (state['current_pass'] + 1, state['total_passes'],
                     "FORWARD" if moving_forward else "BACKWARD",
                     target_y, state['traverse_speed']))
        
        # Increment pass count and expose to completion report
        state['current_pass'] += 1
        self.current_layer = state['current_pass']
        
        # Queue the move using G-code (uses proper trapezoid acceleration!)
        # Convert mm/s to mm/min for F parameter
        feedrate_mm_min = state['traverse_speed'] * 60.0
        gcode.run_script_from_command("G1 Y%.3f F%.1f" % (target_y, feedrate_mm_min))
        
        # Get toolhead to register callback for when move completes
        toolhead = self.printer.lookup_object('toolhead')
        
        # Update direction for next move
        if state['current_pass'] >= state['total_passes']:
            logging.info("WinderControl: Winding complete - %d layers finished" % state['total_passes'])
            # Stop winding after move completes
            def stop_callback(print_time):
                reactor = self.printer.get_reactor()
                reactor.register_callback(lambda et: self.stop_winding(), reactor.monotonic() + 0.1)
            toolhead.register_lookahead_callback(stop_callback)
            return
        
        state['direction'] = next_direction
        
        # Schedule next move AFTER current move completes (using lookahead callback)
        def schedule_next_move(print_time):
            reactor = self.printer.get_reactor()
            reactor.register_callback(lambda et: self._execute_next_winding_move(), reactor.monotonic() + 0.1)
        
        toolhead.register_lookahead_callback(schedule_next_move)
    
    def _generate_completion_report(self):
        """Generate detailed completion report with all calibration data"""
        reactor = self.printer.get_reactor()
        winding_duration = reactor.monotonic() - self.winding_start_time
        
        # Get sensor turn counts
        angle_turns = 0
        hall_turns = 0
        hall_turns_raw = 0
        measured_rpm = 0.0
        
        # Prioritize Hall sensor for RPM (more reliable than angle sensor)
        if self.spindle_hall and hasattr(self.spindle_hall, 'get_count'):
            hall_turns_raw = self.spindle_hall.get_count()
            # Apply correction factor to compensate for missed edges
            hall_turns = int(hall_turns_raw * self.hall_sensor_correction)
            measured_rpm = self.spindle_hall.get_rpm()
        
        if self.angle_sensor and hasattr(self.angle_sensor, 'get_turn_count'):
            angle_turns = self.angle_sensor.get_turn_count()
            # Only use angle sensor RPM if Hall sensor unavailable
            if measured_rpm == 0.0:
                measured_rpm = self.angle_sensor.get_rpm()
        
        # Fallback RPM calculation based on hall counts and duration
        if measured_rpm == 0.0 and hall_turns > 0 and winding_duration > 0:
            measured_rpm = (hall_turns / winding_duration) * 60.0
        
        # Calculate traverse distance
        traverse_distance = self.bobbin_width * self.current_layer
        
        # Log completion report
        logging.info("=" * 60)
        logging.info("WINDING COMPLETION REPORT")
        logging.info("=" * 60)
        logging.info("COMMANDED PARAMETERS:")
        logging.info("  RPM: %.1f" % self.winding_commanded_rpm)
        logging.info("  Layers: %d" % self.winding_commanded_layers)
        logging.info("  Expected turns: %.1f" % self.winding_expected_turns)
        logging.info("")
        logging.info("MEASURED RESULTS:")
        logging.info("  Actual RPM: %.1f (%.1f%% of target)" % 
                    (measured_rpm, (measured_rpm / self.winding_commanded_rpm * 100) if self.winding_commanded_rpm > 0 else 0))
        logging.info("  Angle sensor turns: %d" % angle_turns)
        logging.info("  Hall sensor turns (raw): %d" % hall_turns_raw)
        logging.info("  Hall sensor turns (corrected): %d (×%.2f)" % (hall_turns, self.hall_sensor_correction))
        logging.info("  Layers completed: %d" % self.current_layer)
        logging.info("  Duration: %.1f seconds" % winding_duration)
        logging.info("")
        logging.info("ACCURACY:")
        if angle_turns > 0:
            angle_error = ((angle_turns - self.winding_expected_turns) / self.winding_expected_turns * 100) if self.winding_expected_turns > 0 else 0
            logging.info("  Angle sensor error: %+.1f%% (%+d turns)" % (angle_error, angle_turns - int(self.winding_expected_turns)))
        if hall_turns > 0:
            hall_error = ((hall_turns - self.winding_expected_turns) / self.winding_expected_turns * 100) if self.winding_expected_turns > 0 else 0
            logging.info("  Hall sensor error (corrected): %+.1f%% (%+d turns)" % (hall_error, hall_turns - int(self.winding_expected_turns)))
        if angle_turns > 0 and hall_turns > 0:
            sensor_sync = abs(angle_turns - hall_turns)
            logging.info("  Sensor sync difference: %d turns" % sensor_sync)
            if sensor_sync > 2:
                logging.warning("  WARNING: Sensors out of sync by %d turns!" % sensor_sync)
        logging.info("")
        logging.info("SYSTEM PARAMETERS:")
        logging.info("  Wire diameter: %.4f mm (%.4f bare + %.4f coating)" % 
                    (self.effective_wire_diameter, self.wire_diameter, self.wire_coating_margin))
        logging.info("  Bobbin width: %.3f mm" % self.bobbin_width)
        logging.info("  Traverse distance: %.3f mm" % traverse_distance)
        logging.info("  Gear ratio: %.3f" % self.gear_ratio)
        logging.info("  Motor calibration: %.3f" % self.motor_speed_calibration)
        logging.info("  Hall sensor correction: %.2f" % self.hall_sensor_correction)
        logging.info("=" * 60)
    
    def stop_winding(self):
        """Stop winding operation"""
        self.is_winding = False
        
        # Stop BLDC motor
        if self.bldc_motor:
            self.bldc_motor.stop_motor()

        # Force hall counter to report one last time
        if self.spindle_hall and hasattr(self.spindle_hall, 'force_update'):
            self.spindle_hall.force_update()

        # Allow spindle to coast down and capture final hall counts
        reactor = self.printer.get_reactor()
        if self.spindle_hall and hasattr(self.spindle_hall, 'get_count'):
            settle_deadline = reactor.monotonic() + 1.0
            last_count = self.spindle_hall.get_count()
            while reactor.monotonic() < settle_deadline:
                reactor.pause(0.05)
                new_count = self.spindle_hall.get_count()
                if new_count == last_count:
                    break
                last_count = new_count
            if hasattr(self.spindle_hall, 'force_update'):
                self.spindle_hall.force_update()
        
        # Stop sync timer
        if self.sync_timer:
            reactor.update_timer(self.sync_timer, reactor.NEVER)
        
        # Reset max velocities to default (120 mm/s from printer.cfg)
        try:
            toolhead = self.printer.lookup_object('toolhead')
            # Get default max velocity from config
            kin = toolhead.get_kinematics()
            if hasattr(kin, 'max_velocity'):
                default_velocity = kin.max_velocity
            else:
                default_velocity = 120.0  # Fallback to config value
            toolhead.set_max_velocities(default_velocity, None, None, None)
            logging.info("WinderControl: Reset max velocity to %.1f mm/s" % default_velocity)
        except Exception as e:
            logging.warning("WinderControl: Could not reset max velocity: %s" % e)
        
        # Clear winding state
        if hasattr(self, 'winding_state'):
            delattr(self, 'winding_state')
        
        # Generate completion report AFTER spindle stops
        if hasattr(self, 'winding_start_time'):
            self._generate_completion_report()
        
        logging.info("WinderControl: Stopped")
    
    def get_status(self, eventtime):
        """Get status for API"""
        return {
            'is_winding': self.is_winding,
            'spindle_rpm_target': self.spindle_rpm_target,
            'spindle_rpm_measured': self.get_spindle_rpm(),
            'current_layer': self.current_layer,
            'wire_diameter': self.wire_diameter,
            'wire_coating_margin': self.wire_coating_margin,
            'effective_wire_diameter': self.effective_wire_diameter,
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

