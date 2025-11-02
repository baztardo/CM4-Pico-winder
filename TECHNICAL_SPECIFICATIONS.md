# CNC PICKUP WINDER - TECHNICAL SPECIFICATIONS
# Professional-Grade Precision Winding Machine

## SYSTEM REQUIREMENTS

### Performance Targets
- **Spindle Speed:** 1000-2000 RPM operational, 3200 RPM max
- **Turn Accuracy:** ±1 turn on 2500-10000 turn coils  
- **Wire Precision:** 43 AWG copper wire laying
- **Position Accuracy:** 0.01mm traverse positioning
- **Response Time:** <1ms motor control latency

### Mechanical Specifications  
- **BLDC Spindle:** 40:60 gear ratio, Hall sensor feedback
- **Traverse Carriage:** Stepper motor, 12mm bobbin diameter
- **Pickup Assembly:** Stepper motor, precision winding
- **Wire Gauge:** 43 AWG (0.056mm diameter)
- **Safety:** Hardware emergency stop, single endstop homing

## CONTROL SYSTEM ARCHITECTURE

### RP2350 Pico 2 (Real-Time Controller)
**Responsibilities:**
- BLDC spindle commutation (3-phase/6-phase)
- Stepper motor pulse generation (2 axes)
- Hall sensor processing (interrupt-driven)
- Encoder counting (quadrature)
- Emergency stop handling
- Real-time motion synchronization

**Performance Requirements:**
- 10kHz+ control loop frequency
- <10µs interrupt latency
- Precise timing (microsecond accuracy)
- Multi-axis coordination

### CM4 Host (Motion Planning & Interface)
**Responsibilities:**
- Motion trajectory planning
- G-code interpretation (winding programs)
- Touchscreen interface management
- Parameter storage and recall
- Safety monitoring and logging
- Remote access and diagnostics

**Interface Requirements:**
- Real-time status updates
- Parameter adjustment on-the-fly
- Job progress monitoring
- Error reporting and recovery

## MOTION CONTROL ALGORITHMS

### BLDC Spindle Control
```
RPM Target: 1500
Gear Ratio: 40:60 (0.667:1)
Motor RPM Required: 1500 × 60/40 = 2250 RPM

Hall Sensor Sequence:
Phase A: □□□□□□□□□□
Phase B: □□□□□□□□□□  
Phase C: □□□□□□□□□□
         ↑ 60° steps (6-phase)

Commutation Table:
Hall ABC | Phase Output
000      | Invalid
001      | Phase C+, B-
010      | Phase B+, A-  
011      | Phase B+, C-
100      | Phase A+, C-
101      | Phase A+, B-
110      | Phase C+, A-
111      | Invalid
```

### Traverse Synchronization
```
Bobbin Circumference: π × 12mm = 37.7mm
Wire Diameter: 0.056mm (43 AWG)
Turns per Layer: 37.7mm / 0.056mm ≈ 674 turns

Traverse Distance per Layer: 0.056mm
Spindle RPM: 1500
Traverse Speed: 1500 RPM × 0.056mm/rev = 84mm/min
```

### Acceleration Profiles
```
Ramp-up: 0 → 1500 RPM over 2 seconds
S-curve acceleration to minimize vibration
PID control: Kp=0.5, Ki=0.1, Kd=0.05
Anti-windup protection
```

## SAFETY & RELIABILITY

### Emergency Stop System
- Hardware interrupt on emergency button
- Immediate motor shutdown (all axes)
- Safe state recovery procedure
- Error logging and notification

### Fault Detection
- Motor stall detection (current monitoring)
- Position error checking (encoder vs commanded)
- Over-temperature protection
- Power supply monitoring

### Recovery Procedures
- Homing sequence after emergency stop
- Position verification and correction
- Wire tension recovery
- Job resume capability

## DEVELOPMENT PRIORITIES

### Phase 1: Core Motor Control
1. BLDC spindle speed control ✓ (Partially done)
2. Basic stepper positioning ✓ (Framework done)
3. Encoder feedback integration ⏳ (Next priority)

### Phase 2: Synchronization  
4. Traverse-spindle synchronization ⏳
5. Wire laying algorithm ⏳
6. Turn counting and completion ⏳

### Phase 3: Interface & Safety
7. Touchscreen control system ⏳
8. Safety systems implementation ⏳
9. Performance optimization ⏳

## SUCCESS METRICS

- **Stability:** 8+ hours continuous operation
- **Accuracy:** <0.1% position error
- **Reliability:** <1 fault per 1000 operations  
- **Usability:** <5 minute job setup time
- **Safety:** Zero false emergencies, 100% emergency stop response

This is a sophisticated industrial control system requiring precision real-time programming, advanced motion control algorithms, and robust safety systems.

