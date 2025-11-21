#!/bin/bash
# Add a missing file from temp clone to ~/klipper
# Usage: ./scripts/add_missing_file.sh <relative_path>
# Example: ./scripts/add_missing_file.sh config/example.cfg

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMP_KLIPPER="$INSTALL_DIR/tmp-klipper"
KLIPPER_DIR="$HOME/klipper"

if [ -z "$1" ]; then
    echo "Usage: $0 <relative_path>"
    echo "Example: $0 config/example.cfg"
    echo "Example: $0 docs/Code_Overview.md"
    exit 1
fi

RELATIVE_PATH="$1"
SOURCE="$TEMP_KLIPPER/$RELATIVE_PATH"
DEST_DIR="$KLIPPER_DIR/$(dirname "$RELATIVE_PATH")"
DEST="$KLIPPER_DIR/$RELATIVE_PATH"

if [ ! -d "$TEMP_KLIPPER" ]; then
    echo "Error: Temp clone not found at: $TEMP_KLIPPER"
    echo "Run install.sh first to create temp clone"
    exit 1
fi

if [ ! -e "$SOURCE" ]; then
    echo "Error: File not found in temp clone: $SOURCE"
    exit 1
fi

# Create destination directory if needed
if [ -d "$SOURCE" ]; then
    echo "Copying directory: $RELATIVE_PATH"
    mkdir -p "$DEST_DIR"
    cp -r "$SOURCE" "$DEST"
    echo "✓ Copied directory to: $DEST"
elif [ -f "$SOURCE" ]; then
    echo "Copying file: $RELATIVE_PATH"
    mkdir -p "$DEST_DIR"
    cp "$SOURCE" "$DEST"
    echo "✓ Copied file to: $DEST"
else
    echo "Error: Source is neither file nor directory: $SOURCE"
    exit 1
fi

