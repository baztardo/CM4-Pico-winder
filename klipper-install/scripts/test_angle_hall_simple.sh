#!/bin/bash
# Simple Angle/Hall Sync Test
# Just analyzes the log after you manually run the motor

echo "======================================================================"
echo "ANGLE SENSOR & HALL PULSE ANALYSIS"
echo "======================================================================"
echo ""
echo "INSTRUCTIONS:"
echo "1. Run this command in your klipper interface:"
echo "   gcode BLDC_START RPM=300"
echo "2. Wait 15-20 seconds"
echo "3. Run: gcode BLDC_STOP"
echo "4. Then run this script to analyze the results"
echo ""
echo "Press ENTER when you've completed the test run..."
read

echo ""
echo "Analyzing last 500 lines of log..."
echo ""

# Get recent log data
LOG_DATA=$(tail -500 /tmp/klippy.log)

echo "ADC VALUE RANGE:"
echo "----------------"
echo "$LOG_DATA" | grep "Angle sensor ADC callback" | \
  awk -F'value=' '{print $2}' | \
  sort -n | \
  awk 'NR==1{min=$1} {max=$1} END{
    if (NR > 0) {
      printf "  Min: %.6f\n", min
      printf "  Max: %.6f\n", max  
      printf "  Span: %.6f (%.1f%% of full range)\n", max-min, (max-min)*100
      printf "  Samples: %d\n", NR
    } else {
      print "  No ADC data found!"
    }
  }'

echo ""
echo "HALL SENSOR:"
echo "------------"
HALL_LINES=$(echo "$LOG_DATA" | grep "Hardware Hall Counter:" | tail -5)
if [ -n "$HALL_LINES" ]; then
    echo "$HALL_LINES" | tail -1 | grep -oP 'Count: \K[0-9]+' | \
      awk '{printf "  Total edges: %d\n", $1; printf "  Revolutions: %d (edges/2)\n", $1/2}'
else
    echo "  No hall data found"
fi

echo ""
echo "ANGLE SENSOR TURNS:"
echo "-------------------"
ANGLE_TURNS=$(echo "$LOG_DATA" | grep "AngleSensor: Turn complete" | wc -l)
echo "  Turn count: $ANGLE_TURNS"

echo ""
echo "RECENT ANGLE SENSOR TURNS:"
echo "--------------------------"
echo "$LOG_DATA" | grep "AngleSensor: Turn complete" | tail -10

echo ""
echo "======================================================================"
echo ""
echo "To see detailed correlation, run:"
echo "  tail -500 /tmp/klippy.log | grep -E 'ADC callback|Turn complete' | tail -50"
echo ""

