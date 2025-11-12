#!/bin/bash
# Sync Klipper interface scripts to CM4
# Usage: ./sync_interface_to_cm4.sh [user@host]

HOST="${1:-winder@winder.local}"
SCRIPT_DIR="scripts"
REMOTE_DIR="~/klipper/scripts"

echo "Syncing interface scripts to ${HOST}..."
echo ""

# Files to sync
FILES=(
    "scripts/klipper_interface.py"
    "scripts/winder_control.py"
    "scripts/README_INTERFACE.md"
)

# Sync files
for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "Copying $file..."
        scp "$file" "${HOST}:${REMOTE_DIR}/$(basename $file)"
    else
        echo "WARNING: $file not found!"
    fi
done

# Make scripts executable
echo ""
echo "Making scripts executable..."
ssh "${HOST}" "chmod +x ${REMOTE_DIR}/klipper_interface.py ${REMOTE_DIR}/winder_control.py"

echo ""
echo "Done! Testing connection..."
ssh "${HOST}" "python3 ${REMOTE_DIR}/klipper_interface.py --info" || echo "WARNING: Connection test failed. Make sure Klipper is running."

