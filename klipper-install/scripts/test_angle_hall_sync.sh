#!/bin/bash
# Test: Angle Sensor and Hall Pulse Synchronization
# 
# This test:
# 1. Spins motor at low RPM
# 2. Records ADC value when each hall pulse fires
# 3. Analyzes repeatability and range

RPM=${1:-300}
PULSES=${2:-50}
DURATION=$((PULSES * 60 / RPM + 5))  # Time for N pulses + 5s buffer

echo "======================================================================"
echo "ANGLE SENSOR & HALL PULSE SYNCHRONIZATION TEST"
echo "======================================================================"
echo ""
echo "Test Parameters:"
echo "  RPM: $RPM"
echo "  Target pulses: $PULSES"
echo "  Duration: ${DURATION}s"
echo ""
echo "This will:"
echo "  1. Clear relevant log data"
echo "  2. Start motor at ${RPM} RPM"
echo "  3. Record for ${DURATION} seconds"
echo "  4. Stop motor"
echo "  5. Analyze ADC values at hall pulse times"
echo ""
echo "Press ENTER to start..."
read

# Mark start in log
echo "" >> /tmp/klippy.log
echo "=== SYNC TEST START $(date) ===" >> /tmp/klippy.log

# Start motor
echo "Starting motor..."
(echo '{"id": 1, "method": "gcode/script", "params": {"script": "BLDC_START RPM='${RPM}'"}}'; echo -ne '\x03') | nc -U /tmp/klippy_uds -w 1 > /dev/null 2>&1

sleep 2
echo "Recording data for ${DURATION} seconds..."
echo "(Motor running at ${RPM} RPM)"

# Wait for test duration
for i in $(seq 1 $DURATION); do
    echo -n "."
    sleep 1
done
echo ""

# Stop motor
echo "Stopping motor..."
(echo '{"id": 2, "method": "gcode/script", "params": {"script": "BLDC_STOP"}}'; echo -ne '\x03') | nc -U /tmp/klippy_uds -w 1 > /dev/null 2>&1

echo "=== SYNC TEST END $(date) ===" >> /tmp/klippy.log

sleep 2

echo ""
echo "======================================================================"
echo "ANALYZING DATA..."
echo "======================================================================"
echo ""

# Extract test data between markers
TEST_DATA=$(awk '/SYNC TEST START/,/SYNC TEST END/' /tmp/klippy.log)

# Get ADC range
echo "ADC VALUE RANGE:"
echo "----------------"
echo "$TEST_DATA" | grep "Angle sensor ADC callback" | \
  awk -F'value=' '{print $2}' | \
  sort -n | \
  awk 'NR==1{min=$1} {max=$1} END{
    if (NR > 0) {
      printf "  Min: %.6f\n", min
      printf "  Max: %.6f\n", max  
      printf "  Span: %.6f\n", max-min
      printf "  Samples: %d\n", NR
    } else {
      print "  No ADC data found!"
    }
  }'

echo ""
echo "HALL PULSE COUNT:"
echo "-----------------"
HALL_COUNT=$(echo "$TEST_DATA" | grep "Hardware Hall Counter:" | tail -1 | grep -oP 'Count: \K[0-9]+' || echo "0")
echo "  Total pulses: $HALL_COUNT"

echo ""
echo "ANGLE SENSOR TURN COUNT:"
echo "------------------------"
ANGLE_COUNT=$(echo "$TEST_DATA" | grep "AngleSensor: Turn complete" | wc -l)
echo "  Total turns: $ANGLE_COUNT"

echo ""
echo "SYNC ACCURACY:"
echo "--------------"
if [ "$HALL_COUNT" -gt 0 ] && [ "$ANGLE_COUNT" -gt 0 ]; then
    DIFF=$((HALL_COUNT / 2 - ANGLE_COUNT))  # Hall counts edges, divide by 2 for revolutions
    echo "  Hall revolutions: $((HALL_COUNT / 2))"
    echo "  Angle turns: $ANGLE_COUNT"
    echo "  Difference: $DIFF turns"
    
    if [ ${DIFF#-} -lt 3 ]; then
        echo "  ✓ GOOD: Sensors are synchronized!"
    else
        echo "  ✗ BAD: Sensors out of sync by $DIFF turns"
    fi
else
    echo "  No data to compare"
fi

echo ""
echo "======================================================================"
echo "DETAILED LOG ANALYSIS"
echo "======================================================================"
echo ""
echo "To manually analyze ADC value at hall pulse times:"
echo "  1. Look in /tmp/klippy.log between SYNC TEST START/END markers"
echo "  2. Find 'Hardware Hall Counter:' lines"
echo "  3. Find nearest 'Angle sensor ADC callback' timestamp"
echo "  4. Record the ADC value"
echo ""
echo "Example:"
echo "  grep -A 2 -B 2 'Hardware Hall Counter:' /tmp/klippy.log | tail -50"
echo ""

