#!/bin/bash
# Clean up temporary Klipper clone
# Usage: ./scripts/cleanup_temp_clone.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMP_KLIPPER="$INSTALL_DIR/tmp-klipper"

if [ -d "$TEMP_KLIPPER" ]; then
    echo "Removing temp clone: $TEMP_KLIPPER"
    rm -rf "$TEMP_KLIPPER"
    echo "✓ Cleaned up"
else
    echo "No temp clone found at: $TEMP_KLIPPER"
fi

