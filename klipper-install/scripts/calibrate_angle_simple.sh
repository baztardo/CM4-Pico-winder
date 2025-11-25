#!/bin/bash
# Simple angle sensor calibration using log file monitoring
# 
# Usage: ./calibrate_angle_simple.sh [RPM] [DURATION_SECONDS]
#
# Example: ./calibrate_angle_simple.sh 300 20

RPM=${1:-300}
DURATION=${2:-20}

echo "======================================================================"
echo "ANGLE SENSOR CALIBRATION (Log-based)"
echo "======================================================================"
echo "RPM: $RPM"
echo "Duration: ${DURATION}s"
echo ""
echo "INSTRUCTIONS:"
echo "1. This script will start the motor at ${RPM} RPM"
echo "2. Let it run for ${DURATION} seconds"
echo "3. Script will analyze the log to find angle at each hall pulse"
echo ""
echo "Press ENTER to start motor, or Ctrl+C to cancel..."
read

# Clear log markers
echo "Starting motor..."
echo "CALIBRATION_START" >> /tmp/klippy.log

# Start motor via console
echo "BLDC_START RPM=${RPM}" > /tmp/printer

# Wait for duration
echo "Recording for ${DURATION} seconds..."
sleep $DURATION

# Stop motor
echo "BLDC_STOP" > /tmp/printer
echo "CALIBRATION_END" >> /tmp/klippy.log

sleep 2

echo ""
echo "======================================================================"
echo "Analyzing log data..."
echo "======================================================================"
echo ""

# Extract hall counter and angle sensor data from log
# Look for lines like:
#   "Hardware Hall Counter: ... Count: XXX ... RPM: YYY"
#   "Angle sensor 'angle_sensor' ... angle=ZZZ"

# Simple grep-based analysis
echo "Hall pulse angles:"
echo "Count | Angle (deg)"
echo "------+-----------"

grep -A 5 "Hardware Hall Counter" /tmp/klippy.log | tail -100 | \
  grep -E "Count:|angle=" | \
  paste - - | \
  awk '{print $2, $4}' | \
  column -t

echo ""
echo "To get better data, manually run:"
echo "  QUERY_HW_COUNTER"
echo "  QUERY_ANGLE_SENSOR"
echo ""
echo "And check /tmp/klippy.log for the output"
echo "======================================================================"

