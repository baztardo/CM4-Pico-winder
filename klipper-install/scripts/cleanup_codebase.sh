#!/bin/bash
# Cleanup duplicate and temporary files from AI debugging session
#
# This script:
# 1. Removes the monolithic extras/winder.py (replaced by modular files)
# 2. Archives temporary debugging/test scripts
# 3. Keeps only essential production scripts

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTRAS_DIR="$SCRIPT_DIR/../extras"
SCRIPTS_DIR="$SCRIPT_DIR"
ARCHIVE_DIR="$SCRIPTS_DIR/archive_$(date +%Y%m%d_%H%M%S)"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Codebase Cleanup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Verify modular files exist before proceeding
echo -e "${BLUE}Step 1: Verify modular files exist...${NC}"
REQUIRED_FILES=(
    "$EXTRAS_DIR/winder_control.py"
    "$EXTRAS_DIR/angle_sensor.py"
    "$EXTRAS_DIR/bldc_motor.py"
    "$EXTRAS_DIR/spindle_hall.py"
    "$EXTRAS_DIR/traverse.py"
    "$SCRIPT_DIR/../kinematics/winder.py"
)

MISSING=0
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo -e "${RED}✗ Missing: $file${NC}"
        MISSING=1
    else
        echo -e "${GREEN}✓ Found: $(basename $file)${NC}"
    fi
done

if [ $MISSING -eq 1 ]; then
    echo -e "${RED}ERROR: Required modular files are missing!${NC}"
    echo "Please ensure all modular files exist before running cleanup."
    exit 1
fi

echo ""
echo -e "${BLUE}Step 2: Check for duplicate monolithic file...${NC}"
if [ -f "$EXTRAS_DIR/winder.py" ]; then
    WINDER_SIZE=$(wc -l < "$EXTRAS_DIR/winder.py")
    echo -e "${YELLOW}Found extras/winder.py ($WINDER_SIZE lines)${NC}"
    echo -e "${YELLOW}This is the monolithic file that should be removed.${NC}"
    read -p "Delete extras/winder.py? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm "$EXTRAS_DIR/winder.py"
        echo -e "${GREEN}✓ Deleted extras/winder.py${NC}"
    else
        echo -e "${YELLOW}Skipped - keeping extras/winder.py${NC}"
    fi
else
    echo -e "${GREEN}✓ extras/winder.py already removed${NC}"
fi

echo ""
echo -e "${BLUE}Step 3: Check for duplicate script file...${NC}"
if [ -f "$SCRIPTS_DIR/winder_control.py" ]; then
    echo -e "${YELLOW}Found scripts/winder_control.py (duplicate)${NC}"
    read -p "Delete scripts/winder_control.py? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm "$SCRIPTS_DIR/winder_control.py"
        echo -e "${GREEN}✓ Deleted scripts/winder_control.py${NC}"
    else
        echo -e "${YELLOW}Skipped - keeping scripts/winder_control.py${NC}"
    fi
else
    echo -e "${GREEN}✓ scripts/winder_control.py already removed${NC}"
fi

echo ""
echo -e "${BLUE}Step 4: Archive temporary debugging scripts...${NC}"

# Essential scripts to KEEP
KEEP_SCRIPTS=(
    "klipper_interface.py"
    "winding_sequence.py"
    "sync_to_cm4.sh"
    "sync_winder_to_cm4.sh"
    "diagnose_homing.sh"
    "cleanup_codebase.sh"
)

# Patterns for temporary scripts to archive
ARCHIVE_PATTERNS=(
    "test_*.sh"
    "test_*.py"
    "fix_*.sh"
    "fix_*.py"
    "check_*.sh"
    "check_*.py"
    "diagnose_*.sh"  # Except diagnose_homing.sh
    "diagnose_*.py"
    "measure_*.sh"
    "apply_*.sh"
    "patch_*.sh"
    "add_*.sh"
    "analyze_*.sh"
    "basic_*.sh"
    "calibrate_*.sh"
    "cleanup_*.sh"  # Except cleanup_codebase.sh
    "copy_*.sh"
    "create_*.sh"
    "direct_*.sh"
    "direct_*.py"
    "download_*.sh"
    "explain_*.sh"
    "force_*.sh"
    "get_*.py"
    "install_*.sh"
    "list_*.sh"
    "remote_*.sh"
    "restore_*.sh"
    "select_*.sh"
    "setup_*.sh"
    "simple_*.sh"
    "simple_*.py"
    "systematic_*.sh"
    "verify_*.sh"
)

# Count files to archive
COUNT=0
for pattern in "${ARCHIVE_PATTERNS[@]}"; do
    for file in $SCRIPTS_DIR/$pattern; do
        if [ -f "$file" ]; then
            basename_file=$(basename "$file")
            # Skip if in KEEP list
            SKIP=0
            for keep in "${KEEP_SCRIPTS[@]}"; do
                if [ "$basename_file" = "$keep" ]; then
                    SKIP=1
                    break
                fi
            done
            if [ $SKIP -eq 0 ]; then
                COUNT=$((COUNT + 1))
            fi
        fi
    done
done

echo "Found $COUNT temporary scripts to archive."
echo ""

if [ $COUNT -gt 0 ]; then
    read -p "Archive these $COUNT scripts to $ARCHIVE_DIR? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mkdir -p "$ARCHIVE_DIR"
        
        ARCHIVED=0
        for pattern in "${ARCHIVE_PATTERNS[@]}"; do
            for file in $SCRIPTS_DIR/$pattern; do
                if [ -f "$file" ]; then
                    basename_file=$(basename "$file")
                    # Skip if in KEEP list
                    SKIP=0
                    for keep in "${KEEP_SCRIPTS[@]}"; do
                        if [ "$basename_file" = "$keep" ]; then
                            SKIP=1
                            break
                        fi
                    done
                    if [ $SKIP -eq 0 ]; then
                        mv "$file" "$ARCHIVE_DIR/"
                        ARCHIVED=$((ARCHIVED + 1))
                    fi
                fi
            done
        done
        
        echo -e "${GREEN}✓ Archived $ARCHIVED scripts to $ARCHIVE_DIR${NC}"
    else
        echo -e "${YELLOW}Skipped - keeping temporary scripts${NC}"
    fi
fi

echo ""
echo -e "${BLUE}Step 5: Summary${NC}"
echo "Essential files kept in scripts/:"
for script in "${KEEP_SCRIPTS[@]}"; do
    if [ -f "$SCRIPTS_DIR/$script" ]; then
        echo -e "  ${GREEN}✓${NC} $script"
    else
        echo -e "  ${YELLOW}?${NC} $script (not found)"
    fi
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Cleanup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Next steps:"
echo "1. Verify modular files work: Test on CM4"
echo "2. Update config to use [winder_control] instead of [winder]"
echo "3. Sync files to CM4: ./scripts/sync_to_cm4.sh"
echo ""



