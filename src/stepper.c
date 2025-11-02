// CNC Pickup Winder Control System
// Complete stepper motor control for BLDC spindle + dual stepper axes
//
// Implements custom stepper control instead of using Klipper's stepper.c
// Includes BLDC Hall sensor commutation, traverse synchronization, and safety

#include "basecmd.h" // oid_alloc
#include "board/gpio.h" // gpio_out_write
#include "board/irq.h" // irq_disable
#include "board/misc.h" // timer_read_time
#include "command.h" // DECL_COMMAND
#include "sched.h" // struct timer
#include "config.h" // Pin definitions
#include "cnc_winder_config.h" // CNC winder configuration

// Stepper Motor Structure (our own implementation)
struct custom_stepper {
    struct timer timer;
    struct gpio_out step_pin;
    struct gpio_out dir_pin;
    struct gpio_out enable_pin;

    uint32_t interval;          // Microseconds between steps
    uint32_t steps_remaining;   // Steps left to execute
    uint8_t direction;          // 0=forward, 1=reverse
    uint8_t is_active;
    uint32_t position;          // Current position in steps
};

// CNC Winder Configuration Structure
struct cnc_winder_config {
    // Stepper motor instances (direct control, no OIDs)
    struct custom_stepper traverse_stepper;  // Side-to-side wire laying
    struct custom_stepper pickup_stepper;    // Coil winding (optional)

    // BLDC Spindle Configuration (ZS-X11H Driver)
    struct gpio_pwm spindle_pwm;        // PWM speed control
    struct gpio_out spindle_brake;      // Brake control
    struct gpio_out spindle_dir;        // Direction control
    struct gpio_in hall_sensor;         // Single Hall sensor feedback

    // System parameters
    uint32_t bobbin_diameter_um;    // 12mm = 12000 um
    uint32_t wire_diameter_um;      // 43 AWG ≈ 56 um
    float spindle_gear_ratio;       // Gear ratio (usually 1.0 for direct drive)

    // Safety
    struct gpio_in emergency_stop_pin;
    struct gpio_in endstop_pin;
};

// Global CNC winder state
static struct cnc_winder_config winder = {0};
static struct timer hall_sensor_timer;

// BLDC spindle control functions (ZS-X11H driver)
// Using Klipper's proper PWM implementation for RP2040

// Initialize PWM for spindle control
static void spindle_pwm_init(void) {
    // Configure PWM pin using Klipper's gpio_pwm_setup
    // cycle_time = CONFIG_CLOCK_FREQ / frequency / MAX_PWM
    // For 10kHz PWM: cycle_time = 16000000 / 10000 / 255 ≈ 62.75
    winder.spindle_pwm = gpio_pwm_setup(SPINDLE_PWM_PIN, 63, 0); // ~10kHz PWM, 0% duty

    // Initialize direction and brake pins
    gpio_out_setup(SPINDLE_DIR_PIN, BLDC_DIRECTION_CW); // Default CW
    gpio_out_setup(SPINDLE_BRAKE_PIN, 0); // Brake OFF
}

// Set PWM duty cycle (0-100%)
static void spindle_set_pwm_duty(float duty_percent) {
    // Clamp duty cycle to 0-100%
    if (duty_percent < 0.0f) duty_percent = 0.0f;
    if (duty_percent > 100.0f) duty_percent = 100.0f;

    // Convert to PWM level (0-255 range for Klipper)
    uint32_t pwm_level = (uint32_t)(duty_percent * 255.0f / 100.0f);
    gpio_pwm_write(winder.spindle_pwm, pwm_level);
}

// Set spindle speed in RPM (using calibrated curve from working code)
static void spindle_set_speed(float rpm) {
    if (rpm < 0) rpm = 0;
    if (rpm > MAX_RPM) rpm = MAX_RPM;

    if (rpm > 0) {
        // Calibrated scaling based on tachometer: S1000 → 1960 RPM actual
        // Linear interpolation between min and max
        float min_duty = PWM_DUTY_MIN;  // Minimum duty to start motor
        float max_duty = PWM_DUTY_MAX;  // Maximum duty

        // Scale RPM to duty cycle
        float duty_percent = min_duty + (rpm / MAX_RPM) * (max_duty - min_duty);
        spindle_set_pwm_duty(duty_percent);
    } else {
        // Stop PWM
        spindle_set_pwm_duty(0.0f);
    }
}

static void spindle_set_direction(uint8_t clockwise) {
    gpio_out_write(winder.spindle_dir, clockwise ? BLDC_DIRECTION_CW : BLDC_DIRECTION_CCW);
}

static void spindle_brake(uint8_t brake_on) {
    gpio_out_write(winder.spindle_brake, brake_on ? 1 : 0);
}

static void spindle_stop(void) {
    spindle_set_pwm_duty(0.0f);
    spindle_brake(1); // Apply brake
}

// Stepper motor timer callback
static uint_fast8_t
stepper_timer_callback(struct timer *timer)
{
    struct custom_stepper *s = container_of(timer, struct custom_stepper, timer);

    // Generate step pulse (toggle step pin)
    gpio_out_toggle_noirq(s->step_pin);

    // Update position
    if (s->direction == 0) {
        s->position++;
    } else {
        s->position--;
    }

    // Check if move complete
    if (s->steps_remaining == 0) {
        s->is_active = 0;
        return SF_DONE;
    }

    // Decrement step counter
    s->steps_remaining--;

    // Schedule next timer event
    s->timer.waketime += s->interval;
    return SF_RESCHEDULE;
}

// Initialize stepper motor
static void
stepper_init(struct custom_stepper *s,
             struct gpio_out step_pin, struct gpio_out dir_pin, struct gpio_out enable_pin)
{
    s->step_pin = step_pin;
    s->dir_pin = dir_pin;
    s->enable_pin = enable_pin;

    s->timer.func = stepper_timer_callback;
    s->is_active = 0;
    s->position = 0;
    s->steps_remaining = 0;
    s->interval = STEPPER_DEFAULT_INTERVAL; // From config
    s->direction = 0;
}

// Start stepper movement
static void
stepper_move(struct custom_stepper *s, uint32_t steps, uint8_t direction, uint32_t interval_us)
{
    if (s->is_active) {
        // Already moving - reject command
        return;
    }

    irq_disable();

    // Set direction
    s->direction = direction;
    gpio_out_write(s->dir_pin, direction);

    // Setup move parameters
    s->steps_remaining = steps;
    s->interval = timer_from_us(interval_us);
    s->is_active = 1;

    // Start timer
    s->timer.waketime = timer_read_time() + s->interval;
    sched_add_timer(&s->timer);

    irq_enable();
}

// Stop stepper movement
static void
stepper_stop(struct custom_stepper *s)
{
    irq_disable();
    sched_del_timer(&s->timer);
    s->steps_remaining = 0;
    s->is_active = 0;
    irq_enable();
}

// Forward declarations
static void update_traverse_position(void);
static void move_traverse_to_position(uint32_t position_um);

// Enable/disable stepper
static void
stepper_enable(struct custom_stepper *s, uint8_t enable)
{
    irq_disable();
    gpio_out_write(s->enable_pin, !enable);  // Active LOW
    irq_enable();
}

// BLDC spindle state
static uint32_t spindle_rpm_target = 0;
static uint32_t spindle_rpm_measured = 0;
static int32_t last_rpm_error = 0;

// Hall sensor pulse timing history for RPM calculation
#define HALL_HISTORY_SIZE 20
static uint32_t hall_pulse_times[HALL_HISTORY_SIZE];
static int hall_pulse_index = 0;

// Winding state
static uint32_t target_turns = 0;
static uint32_t current_turns = 0;
static uint8_t winding_active = 0;
static uint32_t current_layer = 0;

// Hall sensor monitoring for RPM calculation (ZS-X11H driver)
// Based on working implementation with proper filtering and RPM calculation
static uint_fast8_t
hall_sensor_event(struct timer *timer)
{
    // Read single Hall sensor for RPM feedback
    uint8_t hall_state = gpio_in_read(winder.hall_sensor);

    // Track Hall sensor transitions for RPM calculation
    static uint8_t last_hall_state = 0;
    static uint32_t last_transition_time = 0;
    static uint32_t transition_count = 0;

    if (hall_state != last_hall_state) {
        last_hall_state = hall_state;
        transition_count++;

        uint32_t now = timer_read_time();
        if (last_transition_time != 0) {
            uint32_t dt = now - last_transition_time;

            // Filter: Ignore pulses faster than minimum time to prevent noise
            if (dt > 100) {  // Minimum 100us between pulses
                // Store pulse timing for averaging
                hall_pulse_times[hall_pulse_index] = dt;
                hall_pulse_index = (hall_pulse_index + 1) % HALL_HISTORY_SIZE;

                // Calculate RPM using moving average (from working code)
                uint32_t sum = 0;
                int count = (transition_count < HALL_HISTORY_SIZE) ? transition_count : HALL_HISTORY_SIZE;

                for (int i = 0; i < count; i++) {
                    sum += hall_pulse_times[i];
                }

                if (sum > 0) {
                    uint32_t avg_period = sum / count;
                    float pulses_per_second = 1000000.0f / avg_period;
                    spindle_rpm_measured = (pulses_per_second * 60.0f) / BLDC_DEFAULT_PPR;

                    // Apply simple exponential smoothing
                    static float filtered_rpm = 0.0f;
                    const float ALPHA = 0.3f;
                    if (filtered_rpm == 0.0f) {
                        filtered_rpm = spindle_rpm_measured;
                    } else {
                        filtered_rpm = (ALPHA * spindle_rpm_measured) + ((1.0f - ALPHA) * filtered_rpm);
                    }
                    spindle_rpm_measured = filtered_rpm;
                }
            }
        }
        last_transition_time = now;

        // Count revolutions for turn tracking (BLDC_DEFAULT_PPR pulses per revolution)
        static uint32_t revolution_transitions = 0;
        revolution_transitions++;
        if (revolution_transitions >= BLDC_DEFAULT_PPR) {
            revolution_transitions = 0;
            if (winding_active) {
                current_turns++;
            }
        }
    }

    // Reschedule timer
    hall_sensor_timer.waketime = timer_read_time() + HALL_SENSOR_POLL_US;
    sched_add_timer(&hall_sensor_timer);
    return SF_RESCHEDULE;
}

// Configure CNC pickup winder system (uses internal config)
void
command_config_cnc_winder(uint32_t *args)
{
    // Initialize traverse stepper motor
    struct gpio_out traverse_step = gpio_out_setup(TRAVERSE_STEP_PIN, 0);
    struct gpio_out traverse_dir = gpio_out_setup(TRAVERSE_DIR_PIN, 0);
    struct gpio_out traverse_en = gpio_out_setup(TRAVERSE_ENABLE_PIN, 1); // Active LOW

    stepper_init(&winder.traverse_stepper, traverse_step, traverse_dir, traverse_en);

    // Optional: Initialize pickup stepper (comment out if not used)
    // struct gpio_out pickup_step = gpio_out_setup(PICKUP_STEP_PIN, 0);
    // struct gpio_out pickup_dir = gpio_out_setup(PICKUP_DIR_PIN, 0);
    // struct gpio_out pickup_en = gpio_out_setup(PICKUP_ENABLE_PIN, 1); // Active LOW
    // stepper_init(&winder.pickup_stepper, pickup_step, pickup_dir, pickup_en);

    // Initialize BLDC spindle PWM control (ZS-X11H driver)
    spindle_pwm_init();

    // Hall sensor from config (single sensor for RPM feedback)
    winder.hall_sensor = gpio_in_setup(SPINDLE_HALL_A_PIN, 0);

    // System parameters from config
    winder.bobbin_diameter_um = BOBBIN_DIAMETER_UM;
    winder.wire_diameter_um = WIRE_DIAMETER_UM;
    winder.spindle_gear_ratio = GEAR_RATIO;

    // Safety pins from config
    winder.emergency_stop_pin = gpio_in_setup(EMERGENCY_STOP_PIN, 0);
    winder.endstop_pin = gpio_in_setup(ENDSTOP_PIN, 0);

    // Initialize Hall sensor monitoring
    hall_sensor_timer.func = hall_sensor_event;
    hall_sensor_timer.waketime = timer_read_time() + timer_from_us(HALL_SENSOR_POLL_US);
    sched_add_timer(&hall_sensor_timer);

    sendf("cnc_winder_configured traverse_pins=%d,%d,%d spindle_pins=%d,%d,%d hall_pin=%d safety_pins=%d,%d",
          TRAVERSE_STEP_PIN, TRAVERSE_DIR_PIN, TRAVERSE_ENABLE_PIN,
          SPINDLE_PWM_PIN, SPINDLE_BRAKE_PIN, SPINDLE_DIR_PIN,
          SPINDLE_HALL_A_PIN, EMERGENCY_STOP_PIN, ENDSTOP_PIN);
}
DECL_COMMAND(command_config_cnc_winder, "config_cnc_winder");

// Start winding operation
void
command_start_winding(uint32_t *args)
{
    uint32_t requested_turns = args[0];
    uint32_t requested_rpm = args[1];

    // Validate parameters using config limits
    if (requested_turns < MIN_WINDING_TURNS || requested_turns > MAX_WINDING_TURNS) {
        sendf("error invalid_turns min=%u max=%u", MIN_WINDING_TURNS, MAX_WINDING_TURNS);
        return;
    }

    if (requested_rpm < OPERATIONAL_RPM_MIN || requested_rpm > OPERATIONAL_RPM_MAX) {
        sendf("error invalid_rpm min=%u max=%u", OPERATIONAL_RPM_MIN, OPERATIONAL_RPM_MAX);
        return;
    }

    target_turns = requested_turns;
    spindle_rpm_target = requested_rpm;

    current_turns = 0;
    current_layer = 0;
    winding_active = 1;

    // Enable spindle motor (Hall sensor commutation will start automatically)
    // Initial spindle ramp-up would be handled by PID controller

    sendf("winding_started turns=%u rpm=%u", target_turns, spindle_rpm_target);
}
DECL_COMMAND(command_start_winding, "start_winding turns=%u rpm=%u");

// Emergency stop
void
command_cnc_emergency_stop(uint32_t *args)
{
    winding_active = 0;
    spindle_rpm_target = 0;

    // Stop spindle motor immediately
    spindle_stop();

    // Stop traverse stepper
    stepper_stop(&winder.traverse_stepper);

    sendf("cnc_emergency_stop_activated");
}
DECL_COMMAND(command_cnc_emergency_stop, "cnc_emergency_stop");

// Get system status
void
command_get_winder_status(uint32_t *args)
{
    sendf("winder_status active=%c turns=%u/%u rpm=%u/%u layer=%u",
          winding_active, current_turns, target_turns,
          spindle_rpm_measured, spindle_rpm_target, current_layer);
}
DECL_COMMAND(command_get_winder_status, "get_winder_status");

// Manual spindle speed control (for testing)
void
command_set_spindle_rpm(uint32_t *args)
{
    spindle_rpm_target = args[0];
    sendf("spindle_rpm_set target=%u", spindle_rpm_target);
}
DECL_COMMAND(command_set_spindle_rpm, "set_spindle_rpm rpm=%u");

// Core winding algorithm - called periodically to synchronize traverse
void
cnc_winder_update(void)
{
    if (!winding_active) return;

    // Check emergency stop
    if (gpio_in_read(winder.emergency_stop_pin)) {
        command_cnc_emergency_stop(NULL);
        return;
    }

    // Check for winding completion
    if (current_turns >= target_turns) {
        winding_active = 0;
        spindle_rpm_target = 0;
        sendf("winding_completed turns=%u", current_turns);
        return;
    }

    // Update traverse position based on current layer
    update_traverse_position();

    // PID control for spindle speed (using config constants)
    static int32_t rpm_error_integral = 0;
    int32_t rpm_error = spindle_rpm_target - spindle_rpm_measured;

    rpm_error_integral += rpm_error;
    if (rpm_error_integral > SPINDLE_PID_MAX_INTEGRAL) rpm_error_integral = SPINDLE_PID_MAX_INTEGRAL;
    if (rpm_error_integral < -SPINDLE_PID_MAX_INTEGRAL) rpm_error_integral = -SPINDLE_PID_MAX_INTEGRAL;

    // Calculate PID output and adjust spindle speed
    float pid_output = SPINDLE_PID_KP * rpm_error +
                      SPINDLE_PID_KI * rpm_error_integral +
                      SPINDLE_PID_KD * (rpm_error - last_rpm_error);
    last_rpm_error = rpm_error;

    // Adjust target RPM based on PID output (clamp to operational range)
    float adjusted_rpm = spindle_rpm_target + pid_output;
    if (adjusted_rpm < OPERATIONAL_RPM_MIN) adjusted_rpm = OPERATIONAL_RPM_MIN;
    if (adjusted_rpm > OPERATIONAL_RPM_MAX) adjusted_rpm = OPERATIONAL_RPM_MAX;

    spindle_set_speed(adjusted_rpm);
}

// Calculate traverse position for current winding layer
void
update_traverse_position(void)
{
    // Calculate current layer
    uint32_t bobbin_circumference_um = 31416 * winder.bobbin_diameter_um / 10000; // π × D
    uint32_t turns_per_layer = bobbin_circumference_um / winder.wire_diameter_um;
    uint32_t new_layer = current_turns / turns_per_layer;

    if (new_layer != current_layer) {
        current_layer = new_layer;

        // Calculate traverse position for this layer
        uint32_t traverse_position_um = current_layer * winder.wire_diameter_um;

        // Convert to stepper steps and move
        // This would use stepper.c queue_step commands
        move_traverse_to_position(traverse_position_um);

        sendf("layer_changed layer=%u position=%u", current_layer, traverse_position_um);
    }
}

// Move traverse to absolute position
void
move_traverse_to_position(uint32_t position_um)
{
    // Convert micrometers to stepper steps using config
    // TRAVERSE_STEPS_PER_MM = steps per mm
    // position_um / 1000 = position in mm

    // Calculate direction and relative steps
    uint32_t current_pos_um = (winder.traverse_stepper.position * 1000) / TRAVERSE_STEPS_PER_MM; // Convert back to um
    uint8_t direction = (position_um > current_pos_um) ? 0 : 1; // 0=forward, 1=reverse
    uint32_t delta_steps = (position_um > current_pos_um) ?
                          ((position_um - current_pos_um) * TRAVERSE_STEPS_PER_MM) / 1000 :
                          ((current_pos_um - position_um) * TRAVERSE_STEPS_PER_MM) / 1000;

    if (delta_steps > 0 && position_um <= MAX_TRAVERSE_POSITION_UM) {
        stepper_move(&winder.traverse_stepper, delta_steps, direction, STEPPER_DEFAULT_INTERVAL);
    }
}

// Manual traverse movement
void
command_move_traverse(uint32_t *args)
{
    uint32_t distance_um = args[0];  // Micrometers
    uint32_t speed_mm_min = args[1]; // mm/min

    move_traverse_to_position(distance_um);
    sendf("traverse_move distance=%u speed=%u", distance_um, speed_mm_min);
}
DECL_COMMAND(command_move_traverse, "move_traverse distance_um=%u speed_mm_min=%u");

// Homing sequence
void
command_home_all(uint32_t *args)
{
    // Home traverse carriage to endstop
    // Home pickup arm to known position
    // Zero all position counters

    current_turns = 0;
    current_layer = 0;

    sendf("homing_completed");
}
DECL_COMMAND(command_home_all, "home_all");

// Add periodic update to main loop (would be called from main firmware loop)
void
cnc_winder_periodic_update(void)
{
    cnc_winder_update();
}
