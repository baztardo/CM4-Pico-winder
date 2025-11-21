# BLDC Motor Control Module
#
# Copyright (C) 2024
#
# This file may be distributed under the terms of the GNU GPLv3 license.
import logging

class BLDCMotor:
    def __init__(self, config):
        self.printer = config.get_printer()
        self.name = config.get_name()
        
        # Pin configuration
        self.pwm_pin_name = config.get('pwm_pin')
        self.dir_pin_name = config.get('dir_pin')
        self.brake_pin_name = config.get('brake_pin', None)
        self.power_pin_name = config.get('power_pin', None)
        
        # Motor parameters
        self.max_rpm = config.getfloat('max_rpm', 3000.0, above=0.0)
        self.min_rpm = config.getfloat('min_rpm', 10.0, above=0.0)
        self.pwm_frequency = config.getfloat('pwm_frequency', 1000.0, above=0.0)
        self.min_pwm_duty = config.getfloat('min_pwm_duty', 0.05, minval=0.0, maxval=1.0)
        
        # Direction control
        # BLDC controller: DIR pin LOW = change direction, HIGH = normal
        # So MCU LOW → level shifter LOW → direction change
        self.dir_inverted = config.getboolean('dir_inverted', False)
        
        # Brake control
        # BLDC controller: Brake pin HIGH = brake ON, LOW = brake OFF
        # So MCU HIGH → level shifter HIGH → brake ON
        self.brake_inverted = config.getboolean('brake_inverted', False)
        
        # State
        self.current_rpm = 0.0
        self.target_rpm = 0.0
        self.is_running = False
        self.direction_forward = True
        self.brake_engaged = False
        self.power_on = False
        
        # Hardware pins (set up in connect)
        self.mcu_pwm = None
        self.mcu_dir = None
        self.mcu_brake = None
        self.mcu_power = None
        
        # Register event handlers
        self.printer.register_event_handler("klippy:connect", self.handle_connect)
        self.printer.register_event_handler("klippy:shutdown", self.handle_shutdown)
        
        # Register G-code commands
        gcode = self.printer.lookup_object('gcode')
        gcode.register_command("BLDC_START", self.cmd_BLDC_START,
                               desc=self.cmd_BLDC_START_help)
        gcode.register_command("BLDC_STOP", self.cmd_BLDC_STOP,
                               desc=self.cmd_BLDC_STOP_help)
        gcode.register_command("BLDC_SET_RPM", self.cmd_BLDC_SET_RPM,
                               desc=self.cmd_BLDC_SET_RPM_help)
        gcode.register_command("BLDC_SET_DIR", self.cmd_BLDC_SET_DIR,
                               desc=self.cmd_BLDC_SET_DIR_help)
        gcode.register_command("BLDC_SET_BRAKE", self.cmd_BLDC_SET_BRAKE,
                               desc=self.cmd_BLDC_SET_BRAKE_help)
        gcode.register_command("BLDC_SET_POWER", self.cmd_BLDC_SET_POWER,
                               desc=self.cmd_BLDC_SET_POWER_help)
        gcode.register_command("QUERY_BLDC", self.cmd_QUERY_BLDC,
                               desc=self.cmd_QUERY_BLDC_help)
    
    def handle_connect(self):
        """Setup hardware pins when MCU connects"""
        ppins = self.printer.lookup_object('pins')
        toolhead = self.printer.lookup_object('toolhead')
        
        # Setup PWM pin
        self.mcu_pwm = ppins.setup_pin('pwm', self.pwm_pin_name)
        self.mcu_pwm.setup_max_duration(0)
        self.mcu_pwm.setup_cycle_time(1.0 / self.pwm_frequency)
        
        # Setup DIR pin
        self.mcu_dir = ppins.setup_pin('digital_out', self.dir_pin_name)
        self.mcu_dir.setup_max_duration(0)
        
        # Setup Brake pin (if configured)
        if self.brake_pin_name:
            self.mcu_brake = ppins.setup_pin('digital_out', self.brake_pin_name)
            self.mcu_brake.setup_max_duration(0)
            # Initialize brake OFF
            print_time = toolhead.get_last_move_time()
            brake_value = 0 if not self.brake_inverted else 1
            self.mcu_brake.set_digital(print_time, brake_value)
        
        # Setup Power pin (if configured)
        if self.power_pin_name:
            self.mcu_power = ppins.setup_pin('digital_out', self.power_pin_name)
            self.mcu_power.setup_max_duration(0)
            # Initialize power OFF
            print_time = toolhead.get_last_move_time()
            self.mcu_power.set_digital(print_time, 0)
            self.power_on = False
        
        logging.info("BLDC Motor '%s' connected: PWM=%s, DIR=%s, Brake=%s, Power=%s" %
                     (self.name, self.pwm_pin_name, self.dir_pin_name,
                      self.brake_pin_name or "None", self.power_pin_name or "None"))
    
    def handle_shutdown(self):
        """Emergency stop on shutdown"""
        self.stop_motor()
    
    def set_power(self, enable):
        """Enable/disable motor power"""
        if self.mcu_power is None:
            logging.warning("BLDC Motor: Power pin not configured")
            return
        
        toolhead = self.printer.lookup_object('toolhead')
        print_time = toolhead.get_last_move_time()
        
        self.mcu_power.set_digital(print_time, 1 if enable else 0)
        self.power_on = enable
        
        logging.info("BLDC Motor: Power %s" % ("ON" if enable else "OFF"))
    
    def set_direction(self, forward=True):
        """Set motor direction
        
        Args:
            forward: True for forward, False for reverse
        """
        if self.mcu_dir is None:
            logging.warning("BLDC Motor: DIR pin not configured")
            return
        
        toolhead = self.printer.lookup_object('toolhead')
        print_time = toolhead.get_last_move_time()
        
        self.direction_forward = forward
        
        # BLDC controller: LOW = change direction, HIGH = normal
        # If dir_inverted=False: MCU LOW → direction change
        # If dir_inverted=True: MCU HIGH → direction change
        if self.dir_inverted:
            dir_value = 1 if not forward else 0
        else:
            dir_value = 0 if not forward else 1
        
        self.mcu_dir.set_digital(print_time, dir_value)
        
        logging.info("BLDC Motor: Direction %s" % ("FORWARD" if forward else "REVERSE"))
    
    def set_brake(self, engage=True):
        """Set brake state
        
        Args:
            engage: True to engage brake, False to release
        """
        if self.mcu_brake is None:
            logging.warning("BLDC Motor: Brake pin not configured")
            return
        
        toolhead = self.printer.lookup_object('toolhead')
        print_time = toolhead.get_last_move_time()
        
        self.brake_engaged = engage
        
        # BLDC controller: HIGH = brake ON, LOW = brake OFF
        # If brake_inverted=False: MCU HIGH → brake ON
        # If brake_inverted=True: MCU LOW → brake ON
        if self.brake_inverted:
            brake_value = 0 if engage else 1
        else:
            brake_value = 1 if engage else 0
        
        self.mcu_brake.set_digital(print_time, brake_value)
        
        logging.info("BLDC Motor: Brake %s" % ("ENGAGED" if engage else "RELEASED"))
    
    def set_rpm(self, rpm):
        """Set motor RPM
        
        Args:
            rpm: Target RPM (0 to max_rpm)
        """
        if self.mcu_pwm is None:
            logging.warning("BLDC Motor: PWM pin not configured")
            return
        
        # Clamp RPM to valid range
        rpm = max(0.0, min(rpm, self.max_rpm))
        
        if rpm < self.min_rpm and rpm > 0:
            rpm = self.min_rpm
        
        self.target_rpm = rpm
        
        if rpm == 0.0:
            self.stop_motor()
            return
        
        # Calculate PWM duty cycle
        # Linear mapping: 0 RPM = 0%, max_rpm = 100%
        # But enforce minimum duty cycle
        duty_cycle = rpm / self.max_rpm
        duty_cycle = max(self.min_pwm_duty, min(duty_cycle, 1.0))
        
        toolhead = self.printer.lookup_object('toolhead')
        print_time = toolhead.get_last_move_time()
        
        # Set PWM
        self.mcu_pwm.set_pwm(print_time, duty_cycle)
        self.current_rpm = rpm
        self.is_running = True
        
        logging.info("BLDC Motor: RPM set to %.1f (duty: %.1f%%)" %
                     (rpm, duty_cycle * 100.0))
    
    def start_motor(self, rpm=None, forward=True):
        """Start motor with specified RPM and direction
        
        Args:
            rpm: Target RPM (uses current target if None)
            forward: Direction (True=forward, False=reverse)
        """
        # Ensure power is on
        if self.mcu_power and not self.power_on:
            self.set_power(True)
        
        # Release brake
        if self.mcu_brake and self.brake_engaged:
            self.set_brake(False)
        
        # Set direction
        self.set_direction(forward)
        
        # Set RPM
        if rpm is not None:
            self.set_rpm(rpm)
        elif self.target_rpm > 0:
            self.set_rpm(self.target_rpm)
        else:
            self.set_rpm(self.min_rpm)
    
    def stop_motor(self):
        """Stop motor (set RPM to 0)"""
        if self.mcu_pwm is None:
            return
        
        toolhead = self.printer.lookup_object('toolhead')
        print_time = toolhead.get_last_move_time()
        
        # Set PWM to 0
        self.mcu_pwm.set_pwm(print_time, 0.0)
        
        self.current_rpm = 0.0
        self.target_rpm = 0.0
        self.is_running = False
        
        logging.info("BLDC Motor: Stopped")
    
    def get_status(self, eventtime):
        """Get motor status for API"""
        return {
            'rpm': self.current_rpm,
            'target_rpm': self.target_rpm,
            'is_running': self.is_running,
            'direction': 'forward' if self.direction_forward else 'reverse',
            'brake_engaged': self.brake_engaged,
            'power_on': self.power_on,
            'pwm_pin': self.pwm_pin_name,
            'dir_pin': self.dir_pin_name,
            'brake_pin': self.brake_pin_name,
            'power_pin': self.power_pin_name,
        }
    
    # G-code commands
    cmd_BLDC_START_help = "Start BLDC motor"
    def cmd_BLDC_START(self, gcmd):
        rpm = gcmd.get_float('RPM', self.target_rpm, minval=0.0)
        forward = gcmd.get('DIRECTION', 'forward').lower() == 'forward'
        self.start_motor(rpm=rpm, forward=forward)
        gcmd.respond_info("BLDC Motor started: %.1f RPM, %s" %
                         (rpm, "forward" if forward else "reverse"))
    
    cmd_BLDC_STOP_help = "Stop BLDC motor"
    def cmd_BLDC_STOP(self, gcmd):
        self.stop_motor()
        gcmd.respond_info("BLDC Motor stopped")
    
    cmd_BLDC_SET_RPM_help = "Set BLDC motor RPM"
    def cmd_BLDC_SET_RPM(self, gcmd):
        rpm = gcmd.get_float('RPM', minval=0.0, maxval=self.max_rpm)
        self.set_rpm(rpm)
        gcmd.respond_info("BLDC Motor RPM set to %.1f" % rpm)
    
    cmd_BLDC_SET_DIR_help = "Set BLDC motor direction"
    def cmd_BLDC_SET_DIR(self, gcmd):
        direction = gcmd.get('DIRECTION', 'forward').lower()
        forward = direction in ['forward', 'fwd', 'f']
        self.set_direction(forward)
        gcmd.respond_info("BLDC Motor direction set to %s" %
                         ("forward" if forward else "reverse"))
    
    cmd_BLDC_SET_BRAKE_help = "Set BLDC motor brake"
    def cmd_BLDC_SET_BRAKE(self, gcmd):
        engage = gcmd.get('ENGAGE', '1').lower() in ['1', 'true', 'yes', 'on']
        self.set_brake(engage)
        gcmd.respond_info("BLDC Motor brake %s" %
                         ("engaged" if engage else "released"))
    
    cmd_BLDC_SET_POWER_help = "Set BLDC motor power"
    def cmd_BLDC_SET_POWER(self, gcmd):
        enable = gcmd.get('ENABLE', '1').lower() in ['1', 'true', 'yes', 'on']
        self.set_power(enable)
        gcmd.respond_info("BLDC Motor power %s" %
                         ("ON" if enable else "OFF"))
    
    cmd_QUERY_BLDC_help = "Query BLDC motor status"
    def cmd_QUERY_BLDC(self, gcmd):
        status = self.get_status(None)
        gcmd.respond_info("BLDC Motor Status:")
        gcmd.respond_info("  RPM: %.1f / %.1f (target)" %
                         (status['rpm'], status['target_rpm']))
        gcmd.respond_info("  Running: %s" % status['is_running'])
        gcmd.respond_info("  Direction: %s" % status['direction'])
        gcmd.respond_info("  Brake: %s" % ("engaged" if status['brake_engaged'] else "released"))
        gcmd.respond_info("  Power: %s" % ("ON" if status['power_on'] else "OFF"))
        gcmd.respond_info("  Pins: PWM=%s, DIR=%s, Brake=%s, Power=%s" %
                         (status['pwm_pin'], status['dir_pin'],
                          status['brake_pin'] or "None", status['power_pin'] or "None"))

def load_config(config):
    return BLDCMotor(config)

def load_config_prefix(config):
    # For [bldc_motor spindle] style sections
    return BLDCMotor(config)

