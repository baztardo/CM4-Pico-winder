#!/bin/bash
# Raw ADC and Hall Pulse Angle Calibration
# Extracts actual data from Klipper log during a test run

echo "======================================================================"
echo "ANGLE SENSOR RAW CALIBRATION"
echo "======================================================================"
echo ""
echo "This script will:"
echo "1. Clear the log"
echo "2. Start motor at low RPM"
echo "3. Let it run for specified time"
echo "4. Stop motor"
echo "5. Analyze log for:"
echo "   - ADC min/max range"
echo "   - Angle when hall fires"
echo "   - Hall pulse repeatability"
echo ""

# Parameters
RPM=${1:-300}
DURATION=${2:-30}

echo "RPM: $RPM"
echo "Duration: ${DURATION}s"
echo ""
echo "Press ENTER to start, or Ctrl+C to cancel..."
read

# Mark log start
echo "=== CALIBRATION START ===" >> /tmp/klippy.log

# Start motor via klipper interface
echo "Starting motor at ${RPM} RPM..."
python3 ~/klipper_interface.py -g "BLDC_START RPM=${RPM}" > /dev/null 2>&1

# Wait
echo "Recording for ${DURATION} seconds..."
sleep $DURATION

# Stop motor
echo "Stopping motor..."
python3 ~/klipper_interface.py -g "BLDC_STOP" > /dev/null 2>&1

echo "=== CALIBRATION END ===" >> /tmp/klippy.log

sleep 2

echo ""
echo "======================================================================"
echo "ANALYZING DATA..."
echo "======================================================================"
echo ""

# Extract ADC values
echo "ADC VALUE RANGE:"
echo "----------------"
grep "Angle sensor ADC callback" /tmp/klippy.log | \
  awk -F'value=' '{print $2}' | \
  sort -n | \
  awk 'NR==1{min=$1} {max=$1} END{print "Min: " min "\nMax: " max "\nSpan: " max-min}'

echo ""
echo "ADC DISTRIBUTION (histogram):"
echo "------------------------------"
grep "Angle sensor ADC callback" /tmp/klippy.log | \
  awk -F'value=' '{print $2}' | \
  awk '{
    bucket = int($1 * 10) / 10.0
    count[bucket]++
  }
  END {
    for (b in count) {
      printf "%.1f - %.1f: ", b, b+0.1
      for (i=0; i<count[b]/10; i++) printf "#"
      printf " (%d)\n", count[b]
    }
  }' | sort -n

echo ""
echo "HALL PULSE ANALYSIS:"
echo "--------------------"
echo "Looking for ADC values near hall pulse times..."
echo ""

# This is tricky - we need to correlate hall counter changes with ADC values
# For now, just show the pattern
echo "(Manual analysis needed - check /tmp/klippy.log for correlation)"
echo ""
echo "To find hall pulse angle:"
echo "1. Look for 'Hardware Hall Counter:' lines with count changes"
echo "2. Find nearest 'Angle sensor ADC callback' timestamp"
echo "3. Record the ADC value at that time"
echo ""
echo "======================================================================"
echo ""
echo "Full log saved in /tmp/klippy.log"
echo "Search for 'CALIBRATION START' to find the test data"
echo ""

