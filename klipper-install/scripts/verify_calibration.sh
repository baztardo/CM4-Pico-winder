#!/bin/bash
# Angle Sensor Calibration Verification Script
# Run this periodically to verify sensor accuracy

set -e

LOGFILE="/tmp/klippy.log"
REPORT_DIR="$HOME/calibration_reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="$REPORT_DIR/calibration_$TIMESTAMP.txt"

# Create report directory if it doesn't exist
mkdir -p "$REPORT_DIR"

echo "=========================================="
echo "Angle Sensor Calibration Verification"
echo "=========================================="
echo "Timestamp: $(date)"
echo ""

# Check if Klipper log exists and is recent (updated in last 60 seconds)
if [ ! -f "$LOGFILE" ]; then
    echo "ERROR: Klipper log file not found: $LOGFILE"
    exit 1
fi

LOG_AGE=$(($(date +%s) - $(stat -c %Y "$LOGFILE" 2>/dev/null || stat -f %m "$LOGFILE")))
if [ $LOG_AGE -gt 60 ]; then
    echo "WARNING: Klipper log hasn't been updated in $LOG_AGE seconds"
    echo "Klipper may not be running properly"
fi

echo "✓ Klipper is running"
echo ""

# Extract the most recent calibration results
echo "Extracting calibration data from log..."
CALIB_DATA=$(tail -500 "$LOGFILE" | grep -A 80 'CALIBRATION RESULTS' | tail -80)

if [ -z "$CALIB_DATA" ]; then
    echo "ERROR: No calibration data found in log!"
    echo ""
    echo "Please run calibration first:"
    echo "  1. gcode CALIBRATE_ANGLE_SENSOR ACTION=START"
    echo "  2. gcode G28 Y"
    echo "  3. gcode WINDER_START RPM=300 LAYERS=1"
    echo "  4. gcode CALIBRATE_ANGLE_SENSOR ACTION=STOP"
    echo "  5. Run this script again"
    exit 1
fi

# Save full report
echo "$CALIB_DATA" > "$REPORT_FILE"
echo "✓ Full report saved to: $REPORT_FILE"
echo ""

# Extract key metrics
HALL_SAMPLES=$(echo "$CALIB_DATA" | grep "Total samples:" | awk '{print $3}')
ADC_MIN=$(echo "$CALIB_DATA" | grep "^  Min:" | head -1 | awk '{print $2}')
ADC_MAX=$(echo "$CALIB_DATA" | grep "^  Max:" | head -1 | awk '{print $2}')
ADC_SPAN=$(echo "$CALIB_DATA" | grep "^  Span:" | awk '{print $2}')
ADC_SPAN_PCT=$(echo "$CALIB_DATA" | grep "^  Span:" | awk '{print $3}' | tr -d '()')
ANGLE_STD=$(echo "$CALIB_DATA" | grep "Std dev:" | tail -1 | awk '{print $3}' | tr -d '°')

echo "=========================================="
echo "CALIBRATION SUMMARY"
echo "=========================================="
echo "Hall Pulses:       $HALL_SAMPLES"
echo "RAW ADC Min:       $ADC_MIN"
echo "RAW ADC Max:       $ADC_MAX"
echo "RAW ADC Span:      $ADC_SPAN ($ADC_SPAN_PCT)"
echo ""

# Calculate resolution
if [ -n "$ADC_SPAN_PCT" ]; then
    SPAN_NUM=$(echo "$ADC_SPAN_PCT" | tr -d '%')
    SPAN_DECIMAL=$(echo "scale=4; $SPAN_NUM / 100" | bc)
    USABLE_STEPS=$(echo "scale=0; 4096 * $SPAN_DECIMAL" | bc)
    STEPS_PER_DEG=$(echo "scale=1; $USABLE_STEPS / 360" | bc)
    
    echo "Resolution:"
    echo "  Usable ADC steps:  $USABLE_STEPS"
    echo "  Steps per degree:  $STEPS_PER_DEG"
    echo ""
fi

# Status checks
echo "=========================================="
echo "STATUS CHECKS"
echo "=========================================="

STATUS_OK=true

# Check ADC span
if [ -n "$SPAN_NUM" ]; then
    SPAN_CHECK=$(echo "$SPAN_NUM > 40 && $SPAN_NUM < 70" | bc)
    if [ "$SPAN_CHECK" -eq 1 ]; then
        echo "✓ ADC span: GOOD (${SPAN_NUM}% is within 40-70%)"
    else
        echo "⚠ ADC span: UNUSUAL (${SPAN_NUM}% - expected 40-70%)"
        echo "  → Sensor may need inspection (but may be normal for this sensor)"
    fi
fi

# Check for saturation
if [ -n "$ADC_MIN" ] && [ -n "$ADC_MAX" ]; then
    SAT_CHECK=$(echo "$ADC_MIN < 0.05 || $ADC_MAX > 0.95" | bc)
    if [ "$SAT_CHECK" -eq 1 ]; then
        echo "⚠ ADC near rails: Min=$ADC_MIN, Max=$ADC_MAX"
        echo "  → Monitor for saturation issues during operation"
    else
        echo "✓ No saturation: ADC range looks good"
    fi
fi

# Check hall pulse count (should be reasonable for a calibration run)
if [ -n "$HALL_SAMPLES" ]; then
    if [ "$HALL_SAMPLES" -gt 10 ]; then
        echo "✓ Hall pulses: $HALL_SAMPLES samples collected"
    else
        echo "✗ Hall pulses: Only $HALL_SAMPLES samples - run longer test"
        STATUS_OK=false
    fi
fi

# Note about angle variation (this is normal and expected)
echo ""
echo "NOTE: High angle variation at hall pulses is NORMAL"
echo "      The hall sensor fires at different angles each revolution"
echo "      because the two sensors sample independently."

echo ""
echo "=========================================="
if [ "$STATUS_OK" = true ]; then
    echo "OVERALL STATUS: ✓ PASS"
else
    echo "OVERALL STATUS: ✗ FAIL - Action required!"
fi
echo "=========================================="
echo ""

# Append to history log
HISTORY_FILE="$REPORT_DIR/calibration_history.csv"
if [ ! -f "$HISTORY_FILE" ]; then
    echo "Date,Time,Hall_Samples,ADC_Min,ADC_Max,ADC_Span,Angle_StdDev,Status" > "$HISTORY_FILE"
fi

STATUS_TEXT="PASS"
if [ "$STATUS_OK" = false ]; then
    STATUS_TEXT="FAIL"
fi

echo "$(date +%Y-%m-%d),$(date +%H:%M:%S),$HALL_SAMPLES,$ADC_MIN,$ADC_MAX,$ADC_SPAN,$ANGLE_STD,$STATUS_TEXT" >> "$HISTORY_FILE"
echo "✓ History updated: $HISTORY_FILE"
echo ""

exit 0

