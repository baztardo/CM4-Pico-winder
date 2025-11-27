# RPM Calibration Test Results

## Test Conditions
- **Duration**: 10 seconds per test
- **Spindle Hall**: 1 pulse/revolution (PA15)
- **BLDC Hall**: 18 pulses/revolution (PA1)
- **Current motor_speed_calibration**: 1.09

## Raw Data

| Test | Commanded RPM | Spindle Count | BLDC Count | Spindle Turns | BLDC Turns | Drift |
|------|---------------|---------------|------------|---------------|------------|-------|
| 1    | 100           | 8             | 133        | 8.00          | 7.39       | 0.61  |
| 2    | 300           | 13            | 234        | 13.00         | 13.00      | 0.00  |
| 3    | 500           | 38            | 690        | 38.00         | 38.33      | 0.33  |
| 4    | 1000          | 103           | 1852       | 103.00        | 102.89     | 0.11  |

## Calculated Results

| Test | Commanded RPM | Actual RPM | Calibration Factor | Error % |
|------|---------------|------------|-------------------|---------|
| 1    | 100           | 48         | 2.08              | -52%    |
| 2    | 300           | 78         | 3.85              | -74%    |
| 3    | 500           | 228        | 2.19              | -54%    |
| 4    | 1000          | 618        | 1.62              | -38%    |

**Actual RPM = (Spindle Count / 10 seconds) × 60**

## Analysis

### 1. Counter Synchronization (Drift)
✅ **EXCELLENT** - Both counters track within 0.61 turns maximum
- Test 1: 0.61 turns drift (7.6% - acceptable at low speed/count)
- Test 2: 0.00 turns drift (PERFECT!)
- Test 3: 0.33 turns drift (0.87% - excellent)
- Test 4: 0.11 turns drift (0.11% - excellent)

**Conclusion**: The 18 pulses/rev calibration is accurate. Counters are synchronized.

### 2. Motor Speed Calibration (Linearity)
❌ **NON-LINEAR** - Calibration factor varies significantly with RPM

| RPM Range | Calibration Factor | Trend |
|-----------|-------------------|-------|
| 100       | 2.08              | Low   |
| 300       | 3.85              | High  |
| 500       | 2.19              | Medium|
| 1000      | 1.62              | Low   |

**This is NOT a simple linear calibration issue!**

### 3. Possible Causes

1. **PWM-to-RPM relationship is non-linear**
   - Motor controller may have dead zones at low PWM
   - Motor may have different efficiency curves at different speeds

2. **Load-dependent behavior**
   - Motor may respond differently under no-load vs loaded conditions

3. **PWM frequency or duty cycle issues**
   - Current: 1000 Hz PWM frequency
   - May need adjustment for this specific motor

4. **Acceleration time not accounted for**
   - Motor takes time to reach target speed
   - 10-second test may include ramp-up time

### 4. Recommendations

#### Option A: Multi-point calibration table
Create a lookup table mapping commanded RPM to actual calibration factors:
```python
rpm_calibration_table = {
    100: 2.08,
    300: 3.85,
    500: 2.19,
    1000: 1.62
}
```

#### Option B: Test with longer duration
Run 30-second tests to eliminate acceleration effects:
- Discard first 5 seconds (acceleration)
- Measure steady-state RPM over remaining 25 seconds

#### Option C: PWM characterization
Test PWM duty cycle directly:
- 10%, 20%, 30%, 40%, 50%, 60%, 70%, 80%, 90% duty
- Map duty cycle to actual RPM
- Create proper transfer function

#### Option D: Closed-loop control (RECOMMENDED)
Use the BLDC hall counter for real-time feedback:
- Measure actual RPM every 100ms
- Adjust PWM dynamically to maintain target RPM
- This is what you've been asking for all along!

## Next Steps

1. **Verify acceleration time**: Run 30-second tests to see if calibration factors stabilize
2. **Test at winding RPM (163.5)**: Get calibration factor at actual working speed
3. **Implement closed-loop control**: Use BLDC hall feedback to maintain constant RPM
4. **Test under load**: Repeat tests with wire tension to see real-world behavior

## Conclusion

✅ **Hardware is ROCK SOLID**: Counters are accurate and synchronized
❌ **Motor control is non-linear**: Simple calibration factor won't work
🎯 **Solution**: Implement closed-loop RPM control using BLDC hall feedback

**The foundation is perfect. Now we need smart control logic.**

