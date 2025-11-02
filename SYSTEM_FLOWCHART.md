# CNC PICKUP WINDER - COMPLETE SYSTEM FLOWCHART
# Control Flow, States, and Sequences

┌─────────────────────────────────────────────────────────────────────────────┐
│                          SYSTEM POWER-ON                                    │
└─────────────────┬───────────────────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           BOOT SEQUENCE                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐   │
│  │   RP2350    │    │   RP2350    │    │   RP2350    │    │   RP2350    │   │
│  │   Reset     │───▶│   Vector    │───▶│   Startup   │───▶│   Init      │   │
│  │             │    │   Table     │    │   Code      │    │   Hardware   │   │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘   │
│                                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐   │
│  │    CM4      │    │    CM4      │    │    CM4      │    │    CM4      │   │
│  │   Power     │───▶│   Linux     │───▶│   Klipper   │───▶│   Mainsail   │   │
│  │   On        │    │   Boot      │    │   Service   │    │   Web UI     │   │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                       INITIALIZATION PHASE                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    RP2350 FIRMWARE INIT                             │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                     │   │
│  │  1. GPIO Pin Configuration                                          │   │
│  │     - BLDC Phase Outputs (U,V,W high/low)                          │   │
│  │     - Hall Sensor Inputs (A,B,C)                                   │   │
│  │     - Stepper Motor Pins (step/dir/enable × 2)                     │   │
│  │     - Safety Inputs (emergency stop, endstop)                      │   │
│  │                                                                     │   │
│  │  2. Peripheral Initialization                                        │   │
│  │     - Timer system setup                                            │   │
│  │     - Interrupt configuration                                       │   │
│  │     - USB serial setup                                              │   │
│  │                                                                     │   │
│  │  3. Motor Controller Setup                                          │   │
│  │     - Stepper structures initialized                                │   │
│  │     - BLDC phase outputs to safe state                              │   │
│  │     - Hall sensor monitoring started                                │   │
│  │                                                                     │   │
│  │  4. Safety System Activation                                        │   │
│  │     - Emergency stop monitoring enabled                             │   │
│  │     - Fault detection initialized                                   │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                     CM4 HOST INIT                                   │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                     │   │
│  │  1. Klipper Service Start                                           │   │
│  │  2. Configuration Loading (cnc_winder_config.cfg)                  │   │
│  │  3. MCU Connection Establishment                                     │   │
│  │  4. Mainsail Web Interface Start                                    │   │
│  │  5. Status Monitoring Activation                                    │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SYSTEM STATES                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    STATE: SYSTEM_READY                               │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  ✓ Motors powered but not moving                                    │   │
│  │  ✓ BLDC spindle at zero RPM                                         │   │
│  │  ✓ Steppers enabled but positioned at home                          │   │
│  │  ✓ Hall sensors being monitored                                     │   │
│  │  ✓ Emergency stop circuit active                                   │   │
│  │  ✓ CM4 connected and communicating                                  │   │
│  │  ✓ Mainsail web interface ready                                     │   │
│  │                                                                     │   │
│  │  Available Commands:                                                │   │
│  │  - config_cnc_winder (reinitialize)                                 │   │
│  │  - home_all (go to homing sequence)                                 │   │
│  │  - get_winder_status (check system)                                 │   │
│  │  - cnc_emergency_stop (shutdown)                                    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────┬───────────────────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                       HOMING SEQUENCE                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                STATE: HOMING_ACTIVE                                  │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                     │   │
│  │  TRIGGER: User presses 'HOME_ALL' button                            │   │
│  │                                                                     │   │
│  │  1. Emergency Stop Check                                            │   │
│  │     └─▶ If active: Abort homing, return to SYSTEM_READY             │   │
│  │                                                                     │   │
│  │  2. Traverse Carriage Homing                                        │   │
│  │     ├─▶ Move toward endstop at HOMING_SPEED_MM_MIN                  │   │
│  │     ├─▶ Detect endstop trigger                                       │   │
│  │     ├─▶ Stop movement, back off HOMING_BACKOFF_MM                    │   │
│  │     └─▶ Set position = 0, apply soft limits                         │   │
│  │                                                                     │   │
│  │  3. Pickup Arm Homing                                               │   │
│  │     ├─▶ Move to known safe position                                 │   │
│  │     └─▶ Set position = 0                                            │   │
│  │                                                                     │   │
│  │  4. BLDC Spindle Zeroing                                            │   │
│  │     ├─▶ Ensure all phases off                                        │   │
│  │     └─▶ Reset RPM counter and position                              │   │
│  │                                                                     │   │
│  │  5. Position Verification                                           │   │
│  │     ├─▶ Check all motors at expected positions                      │   │
│  │     └─▶ Validate encoder readings                                   │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│                      ▼ SUCCESS                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                STATE: HOMING_COMPLETE                               │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  ✓ All motors homed and positioned                                  │   │
│  │  ✓ Positions verified and stored                                    │   │
│  │  ✓ Soft limits active                                               │   │
│  │  ✓ Ready for winding operations                                     │   │
│  │                                                                     │   │
│  │  Available Commands:                                                │   │
│  │  - start_winding TURNS=x RPM=y                                      │   │
│  │  - move_traverse (manual positioning)                               │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│                      ▼ FAILURE                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                STATE: HOMING_FAILED                                 │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  ❌ Homing sequence failed                                          │   │
│  │  ❌ Motors may be in unknown positions                              │   │
│  │  ❌ System requires manual intervention                             │   │
│  │                                                                     │   │
│  │  Recovery Options:                                                  │   │
│  │  - cnc_emergency_stop (complete shutdown)                           │   │
│  │  - Manual repositioning                                             │   │
│  │  - Restart homing sequence                                          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      WINDING OPERATION                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                STATE: WINDING_SETUP                                  │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                     │   │
│  │  TRIGGER: User enters winding parameters                            │   │
│  │                                                                     │   │
│  │  1. Parameter Validation                                             │   │
│  │     ├─▶ Check TURNS (MIN_WINDING_TURNS to MAX_WINDING_TURNS)        │   │
│  │     └─▶ Check RPM (OPERATIONAL_RPM_MIN to OPERATIONAL_RPM_MAX)      │   │
│  │                                                                     │   │
│  │  2. System Readiness Check                                          │   │
│  │     ├─▶ Verify homing completed                                      │   │
│  │     ├─▶ Check emergency stop not active                             │   │
│  │     ├─▶ Validate motor temperatures                                  │   │
│  │     └─▶ Confirm wire feed system ready                               │   │
│  │                                                                     │   │
│  │  3. Target Calculations                                             │   │
│  │     ├─▶ Calculate traverse positions per layer                      │   │
│  │     ├─▶ Determine acceleration profiles                              │   │
│  │     └─▶ Set completion criteria                                      │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│                      ▼                                                     │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                STATE: WINDING_ACTIVE                                │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │                                                                     │   │
│  │  ┌─────────────────────────────────────────────────────────────────┐ │   │
│  │  │             REAL-TIME CONTROL LOOP                             │ │   │
│  │  ├─────────────────────────────────────────────────────────────────┤ │   │
│  │  │                                                                 │ │   │
│  │  │  ┌─▶ Emergency Stop Check                                       │ │   │
│  │  │  │    └─▶ TRUE: → WINDING_ABORTED                              │ │   │
│  │  │  │                                                              │ │   │
│  │  │  ┌─▶ BLDC Spindle Control                                        │ │   │
│  │  │  │  ├─▶ Read Hall sensors                                       │ │   │
│  │  │  │  ├─▶ Commutate motor phases                                  │ │   │
│  │  │  │  ├─▶ Calculate RPM from Hall transitions                     │ │   │
│  │  │  │  └─▶ PID control toward target RPM                           │ │   │
│  │  │  │                                                              │ │   │
│  │  │  ┌─▶ Traverse Synchronization                                     │ │   │
│  │  │  │  ├─▶ Calculate current layer                                 │ │   │
│  │  │  │  ├─▶ Determine target traverse position                      │ │   │
│  │  │  │  └─▶ Move stepper to maintain wire lay pattern               │ │   │
│  │  │  │                                                              │ │   │
│  │  │  ┌─▶ Pickup Winding                                              │ │   │
│  │  │  │  ├─▶ Count spindle revolutions                               │ │   │
│  │  │  │  ├─▶ Track completed turns                                   │ │   │
│  │  │  │  └─▶ Monitor winding progress                                │ │   │
│  │  │  │                                                              │ │   │
│  │  │  ┌─▶ Status Reporting                                            │ │   │
│  │  │  │  └─▶ Send real-time data to CM4                              │ │   │
│  │  │  │                                                              │ │   │
│  │  │  └─▶ Loop every HALL_SENSOR_POLL_US microseconds                │ │   │
│  │  └─────────────────────────────────────────────────────────────────┘ │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│                      ▼ COMPLETION                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                STATE: WINDING_COMPLETE                              │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  ✓ Target turns achieved                                            │   │
│  │  ✓ Spindle decelerated to stop                                      │   │
│  │  ✓ Traverse returned to home position                               │   │
│  │  ✓ Pickup positioned for pickup removal                             │   │
│  │                                                                     │   │
│  │  Available Commands:                                                │   │
│  │  - home_all (prepare for next operation)                            │   │
│  │  - get_winder_status (view completion stats)                        │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│                      ▼ ABORT                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                STATE: WINDING_ABORTED                               │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  ❌ Emergency stop activated                                        │   │
│  │  ❌ Motors stopped immediately                                      │   │
│  │  ❌ Current position may be lost                                    │   │
│  │                                                                     │   │
│  │  Recovery Options:                                                  │   │
│  │  - home_all (recalibrate positions)                                 │   │
│  │  - Manual positioning commands                                      │   │
│  │  - cnc_emergency_stop (if not already triggered)                    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        SHUTDOWN & SAFETY                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │               EMERGENCY STOP SEQUENCE                               │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  TRIGGER: Emergency stop button pressed                             │   │
│  │                                                                     │   │
│  │  1. Immediate Motor Shutdown                                        │   │
│  │     ├─▶ BLDC phases: All OFF                                        │   │
│  │     ├─▶ Steppers: Disabled, timers stopped                          │   │
│  │     └─▶ All PWM outputs: 0% duty cycle                               │   │
│  │                                                                     │   │
│  │  2. State Preservation                                              │   │
│  │     ├─▶ Record last known positions                                 │   │
│  │     ├─▶ Log emergency reason                                        │   │
│  │     └─▶ Set system to SAFE state                                    │   │
│  │                                                                     │   │
│  │  3. Recovery Mode                                                   │   │
│  │     └─▶ Only allow homing and status commands                       │   │
│  │                                                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │               SYSTEM SHUTDOWN                                       │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  1. Controlled Motor Stop                                           │   │
│  │  2. Position Data Save                                              │   │
│  │  3. Hardware Deactivation                                           │   │
│  │  4. Clean Service Shutdown                                          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

## COMMUNICATION PROTOCOL

┌─────────────────────────────────────────────────────────────────────────────┐
│                    CM4 ↔ RP2350 MESSAGE FLOW                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Host Commands (CM4 → Pico):                                               │
│  ├─▶ config_cnc_winder - Initialize CNC system                           │
│  ├─▶ home_all - Start homing sequence                                     │
│  ├─▶ start_winding TURNS=x RPM=y - Begin winding operation               │
│  ├─▶ cnc_emergency_stop - Emergency shutdown                              │
│  ├─▶ get_winder_status - Request status update                           │
│  └─▶ move_traverse DIST=x SPEED=y - Manual traverse movement              │
│                                                                             │
│  Status Reports (Pico → CM4):                                              │
│  ├─▶ cnc_winder_configured pins=... - Configuration complete             │
│  ├─▶ homing_completed - Homing sequence finished                         │
│  ├─▶ winding_started turns=x rpm=y - Winding operation started           │
│  ├─▶ winding_completed turns=x - Winding finished                        │
│  ├─▶ winder_status active=x turns=y/z rpm=a/b layer=c - Real-time status  │
│  ├─▶ cnc_emergency_stop_activated - Emergency stop triggered             │
│  └─▶ layer_changed layer=x position=y - Layer transition report           │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

## ERROR HANDLING

┌─────────────────────────────────────────────────────────────────────────────┐
│                        FAULT DETECTION & RECOVERY                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Critical Faults (Immediate Shutdown):                                     │
│  ├─▶ Emergency stop button pressed                                        │
│  ├─▶ Motor overcurrent detected                                           │
│  ├─▶ Position error exceeds limits                                        │
│  ├─▶ Communication timeout with CM4                                       │
│  └─▶ Invalid Hall sensor sequence                                         │
│                                                                             │
│  Warning Conditions (Logged but Continue):                                 │
│  ├─▶ Motor temperature high                                               │
│  ├─▶ Stepper stall detected                                               │
│  ├─▶ RPM deviation from target                                            │
│  └─▶ Endstop triggered unexpectedly                                        │
│                                                                             │
│  Recovery Strategies:                                                       │
│  ├─▶ Automatic: PID adjustment, position correction                       │
│  ├─▶ User Intervention: Homing, parameter adjustment                      │
│  └─▶ System Reset: Emergency stop, power cycle                            │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

## PERFORMANCE METRICS

┌─────────────────────────────────────────────────────────────────────────────┐
│                      SYSTEM TIMING & PERFORMANCE                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Control Loop Timing:                                                       │
│  ├─▶ Hall Sensor Polling: HALL_SENSOR_POLL_US (100µs)                    │
│  ├─▶ Stepper Pulse Generation: STEPPER_DEFAULT_INTERVAL (1000µs)          │
│  ├─▶ Status Updates: STATUS_UPDATE_INTERVAL_MS (100ms)                    │
│  └─▶ Communication: Variable (USB packet timing)                          │
│                                                                             │
│  System Latencies:                                                          │
│  ├─▶ Emergency Stop Response: <1ms                                        │
│  ├─▶ Motor Commutation: <10µs                                             │
│  ├─▶ Position Update: <50µs                                               │
│  └─▶ Status Report: <5ms                                                  │
│                                                                             │
│  Throughput Targets:                                                        │
│  ├─▶ BLDC RPM Control: 1000-2000 RPM operational                          │
│  ├─▶ Stepper Speed: Up to 1000 steps/sec                                  │
│  ├─▶ Communication: 100 status updates/sec                                │
│  └─▶ Wire Laying: Synchronized to spindle RPM                             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

## STATE TRANSITION DIAGRAM

SYSTEM_READY ──home_all──▶ HOMING_ACTIVE ──success──▶ HOMING_COMPLETE
     │                           │                           │
     │                           │                           │
     │                      failure                    start_winding
     │                           │                           │
     │                           ▼                           ▼
     │                   HOMING_FAILED ◄───────────── WINDING_ACTIVE
     │                           │                           │
     │                           │                           │
     │                           │                    completion/emergency
     │                           │                           │
     │                           │                           ▼
     └───────────────────────────┴──────────────────▶ WINDING_COMPLETE
                                                           │
                                                           │
                                                    emergency
                                                           │
                                                           ▼
                                                    WINDING_ABORTED

Legend:
─▶ Normal flow
◄─ Reverse flow  
━━ Bidirectional
░░ Conditional

