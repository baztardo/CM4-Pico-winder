// CNC Pickup Winder Internal Configuration
// Based on actual SKR Pico hardware from config.h

#ifndef _CNC_WINDER_CONFIG_H
#define _CNC_WINDER_CONFIG_H

// ============================================================================
// HARDWARE PIN CONFIGURATION (SKR Pico)
// ============================================================================

// UART Communication (Pi communication)
#define PI_UART_ID                  uart0
#define PI_UART_TX_PIN              1
#define PI_UART_RX_PIN              0
#define PI_UART_BAUD                115200

// BLDC Spindle Motor (ZS-X11H Driver)
#define SPINDLE_PWM_PIN             3       // PWM speed control
#define SPINDLE_BRAKE_PIN           7       // Brake control (HIGH=brake ON)
#define SPINDLE_DIR_PIN             2       // Direction (HIGH=CW, LOW=CCW)
#define SPINDLE_HALL_A_PIN          15      // Speed feedback (single Hall sensor)
#define SPINDLE_HALL_MONITOR_PIN    22      // Hall monitoring pin

// Traverse Stepper Motor (TMC2209)
#define TRAVERSE_STEP_PIN           5
#define TRAVERSE_DIR_PIN            4
#define TRAVERSE_ENABLE_PIN         6
#define TRAVERSE_HOME_PIN           16
#define TRAVERSE_DIR_INVERT         1       // Invert direction if needed

// Pickup Stepper Motor (if used)
#define PICKUP_STEP_PIN             3
#define PICKUP_DIR_PIN              4
#define PICKUP_ENABLE_PIN           5

// TMC2209 UART (Shared bus for stepper drivers)
#define TMC_UART_ID                 uart1
#define TMC_UART_TX_PIN             8
#define TMC_UART_RX_PIN             9
#define TMC_UART_BAUD               115200

// Safety & Emergency
#define EMERGENCY_STOP_PIN          17
#define ENDSTOP_PIN                 19

// Heartbeat LEDs
#define SCHED_HEARTBEAT_PIN         27      // Scheduler heartbeat
#define ISR_HEARTBEAT_PIN           26      // ISR heartbeat

// ============================================================================
// MECHANICAL PARAMETERS (Actual Hardware)
// ============================================================================

// Bobbin Specifications
#define WINDING_WIDTH_MM            12.0f   // Actual bobbin width
#define WINDING_START_POS_MM        0.5f    // Start 0.5mm from edge
#define BOBBIN_DIAMETER_MM          12.0f   // Bobbin diameter
#define BOBBIN_DIAMETER_UM          (uint32_t)(BOBBIN_DIAMETER_MM * 1000)  // 12000 micrometers

// Wire Specifications
#define WIRE_AWG                    43
#define WINDING_WIRE_DIA_MM         0.056f  // Actual 43 AWG diameter
#define WIRE_DIAMETER_MM            0.056f
#define WIRE_DIAMETER_UM            (uint32_t)(WIRE_DIAMETER_MM * 1000)  // 56 micrometers
#define WIRE_TENSION_FACTOR         0.95f   // 5% compression for tight winding

// Traverse Lead Screw
#define TRAVERSE_PITCH_MM           6.0f    // YOUR ACTUAL 6mm leadscrew
#define TRAVERSE_CARRIAGE_WIDTH     32.0f   // Carriage width in mm
#define TC_START_OFFSET             38.0f    // Start offset from home

// Stepper Calculations (using value from config.h)
// #define Y_STEPS_PER_MM              80.0f   // Defined in config.h
#define TRAVERSE_STEPS_PER_MM       80.0f   // Steps per mm for traverse
#define Y_MAX_ACCEL                 100.0   // mm/s²
#define Y_MAX_VELOCITY              200.0   // mm/s
#define Y_MAX_POSITION_MM           200.0   // Soft limit
#define Y_MIN_POSITION_MM           0.0     // Home position
#define MAX_TRAVERSE_POSITION_UM    (uint32_t)(Y_MAX_POSITION_MM * 1000)  // 200000 micrometers

// Gear System (for BLDC spindle if geared)
#define GEAR_RATIO                  1.0f    // Direct drive (no gearing)

// ============================================================================
// PERFORMANCE PARAMETERS
// ============================================================================

// BLDC Spindle Performance (ZS-X11H Driver)
#define PWM_DUTY_MIN                0.5f    // Minimum 20% to start motor
#define PWM_DUTY_MAX                100.0f  // Maximum 100%
#define MAX_RPM                     2000.0f // Clamped maximum RPM
#define BLDC_DEFAULT_PPR            24      // Pulses per revolution
#define BLDC_DEBOUNCE_US            100     // Debounce time
#define BLDC_SMOOTH_ALPHA           0.1f    // Smoothing factor
#define BLDC_RPM_CALC_INTERVAL      1000000 // RPM calc interval (1 sec)

// Stepper Performance
#define TRAVERSE_CURRENT_MA         1000    // RMS current (mA)
#define TRAVERSE_MICROSTEPS         1       // 1x microstepping (full steps)
#define STEP_PULSE_US               2       // Step pulse width
#define HOLD_CURRENT_PERCENT        30      // 30% of run current when holding
#define POWER_DOWN_DELAY            20      // Delay before reducing current

// Motion Speeds
#define TRAVERSE_HOMING_SPEED       1200    // steps/sec for homing
#define TRAVERSE_RAPID_SPEED        1200    // steps/sec for rapid moves
#define TRAVERSE_RAPID_ACCEL        5000    // steps/sec² for rapid moves
#define TRAVERSE_MIN_WINDING_SPEED  1000    // Minimum speed during winding
#define HOMING_SPEED_MM_PER_SEC     5.0f    // Homing speed in mm/sec

// ============================================================================
// WINDING PARAMETERS
// ============================================================================

// Winding Configuration
#define WINDING_TARGET_TURNS        5000    // Your actual target
#define WINDING_SPINDLE_RPM         1115.0f // Based on your test results
#define WINDING_RAMP_TIME_SEC       10.0f   // Ramp up/down time
#define MIN_WINDING_TURNS           2500
#define MAX_WINDING_TURNS           10000
#define OPERATIONAL_RPM_MIN         1000
#define OPERATIONAL_RPM_MAX         2000

// System Constants
#define NUM_AXES                    2       // Spindle + traverse
#define AXIS_SPINDLE                0
#define AXIS_TRAVERSE               1

// Move Queue
#define MOVE_CHUNKS_CAPACITY        256     // Maximum chunks per axis

// Soft Limits
#define USE_SOFT_LIMITS             1       // Enable soft limits

// ============================================================================
// CONTROL ALGORITHMS
// ============================================================================

// Default Motion Parameters
#define DEFAULT_MAX_VELOCITY        1000.0  // steps/sec
#define DEFAULT_ACCELERATION        2000.0  // steps/sec²
#define DEFAULT_JERK                5000.0  // steps/sec³

// PID Control for Spindle Speed
#define SPINDLE_PID_KP              0.5f
#define SPINDLE_PID_KI              0.1f
#define SPINDLE_PID_KD              0.05f
#define SPINDLE_PID_MAX_INTEGRAL    10000

// TMC2209 Configuration
#define R_SENSE                     0.11f   // Sense resistor value

// Microstepping values for TMC2209:
// 0=1x, 1=2x, 2=4x, 3=8x, 4=16x, 5=32x, 6=64x, 7=128x, 8=256x

// ============================================================================
// TIMING & SCHEDULER
// ============================================================================

// Scheduler Configuration
#define HEARTBEAT_US                100     // Scheduler heartbeat interval
#define HALL_SENSOR_POLL_US         100     // Hall sensor polling
#define STEPPER_DEFAULT_INTERVAL    1000    // Default stepper interval

// ============================================================================
// SAFETY PARAMETERS
// ============================================================================

// Emergency Stop
#define EMERGENCY_STOP_DEBOUNCE_MS  50
#define MOTOR_STOP_TIMEOUT_MS       500

// Fault Detection
#define STALL_CURRENT_THRESHOLD_MA  2000
#define OVERHEAT_TEMP_C             70

// ============================================================================
// DEBUG & MONITORING
// ============================================================================

// Status Update Intervals
#define STATUS_UPDATE_INTERVAL_MS   100
#define DEBUG_OUTPUT_INTERVAL_MS    1000

// BLDC Status
#define BLDC_STATUS_READY           0
#define BLDC_STATUS_RUNNING         1
#define BLDC_STATUS_STOPPED         2
#define BLDC_STATUS_ERROR           3

// Direction constants
#define BLDC_DIRECTION_CW           1       // Clockwise
#define BLDC_DIRECTION_CCW          0       // Counter-clockwise

#endif // _CNC_WINDER_CONFIG_H
