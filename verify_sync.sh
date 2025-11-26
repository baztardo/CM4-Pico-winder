#!/bin/bash
# verify_sync.sh - Verify local and CM4 files are in sync

REMOTE="winder@winder.local"
LOCAL_BASE="$HOME/Documents/GitHub/CM4-Pico-winder"

echo "=========================================="
echo "Verifying sync status..."
echo "=========================================="
echo ""

SYNC_OK=true

# Function to compare files
compare_file() {
    local local_file=$1
    local remote_file=$2
    local name=$3
    
    if [ ! -f "$local_file" ]; then
        echo "❌ $name: Local file missing"
        SYNC_OK=false
        return 1
    fi
    
    # Get MD5 hashes
    if command -v md5 &> /dev/null; then
        local_md5=$(md5 -q "$local_file")
    else
        local_md5=$(md5sum "$local_file" | awk '{print $1}')
    fi
    
    remote_md5=$(ssh $REMOTE "md5sum $remote_file 2>/dev/null | awk '{print \$1}'")
    
    if [ -z "$remote_md5" ]; then
        echo "❌ $name: Remote file missing"
        SYNC_OK=false
        return 1
    fi
    
    if [ "$local_md5" == "$remote_md5" ]; then
        echo "✅ $name"
        return 0
    else
        echo "⚠️  $name: OUT OF SYNC"
        echo "   Local:  $local_md5"
        echo "   Remote: $remote_md5"
        SYNC_OK=false
        return 1
    fi
}

echo "🔍 Checking critical files..."
echo ""

# Firmware
echo "Firmware:"
compare_file \
    "$LOCAL_BASE/src/hw_counter.c" \
    "~/klipper/src/hw_counter.c" \
    "  hw_counter.c"

echo ""

# Python modules
echo "Python Modules:"
compare_file \
    "$LOCAL_BASE/klipper-install/extras/hw_counter.py" \
    "~/klipper/klippy/extras/hw_counter.py" \
    "  hw_counter.py"

compare_file \
    "$LOCAL_BASE/klipper-install/extras/angle_sensor.py" \
    "~/klipper/klippy/extras/angle_sensor.py" \
    "  angle_sensor.py"

compare_file \
    "$LOCAL_BASE/klipper-install/extras/winder_control.py" \
    "~/klipper/klippy/extras/winder_control.py" \
    "  winder_control.py"

compare_file \
    "$LOCAL_BASE/klipper-install/extras/bldc_motor.py" \
    "~/klipper/klippy/extras/bldc_motor.py" \
    "  bldc_motor.py"

compare_file \
    "$LOCAL_BASE/klipper-install/extras/traverse.py" \
    "~/klipper/klippy/extras/traverse.py" \
    "  traverse.py"

echo ""

# Configuration
echo "Configuration:"
compare_file \
    "$LOCAL_BASE/config/printer-manta-m4p-modular.cfg" \
    "~/printer.cfg" \
    "  printer.cfg"

echo ""

# Scripts
echo "Scripts:"
compare_file \
    "$LOCAL_BASE/klipper-install/scripts/gcode_runner.py" \
    "~/gcode_runner.py" \
    "  gcode_runner.py"

compare_file \
    "$LOCAL_BASE/klipper-install/scripts/verify_calibration.sh" \
    "~/verify_calibration.sh" \
    "  verify_calibration.sh"

compare_file \
    "$LOCAL_BASE/klipper-install/scripts/klipper_interface.py" \
    "~/klipper_interface.py" \
    "  klipper_interface.py"

echo ""
echo "=========================================="
if [ "$SYNC_OK" = true ]; then
    echo "✅ ALL FILES IN SYNC"
else
    echo "⚠️  SOME FILES OUT OF SYNC"
    echo ""
    echo "To sync:"
    echo "  Pull from CM4: ./pull_from_cm4.sh"
    echo "  Push to CM4:   ./push_to_cm4.sh"
fi
echo "=========================================="

