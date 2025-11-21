#!/bin/bash
# Verify all files in klipper-install are correct
# Run this before archiving

set -e

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$INSTALL_DIR"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ERRORS=0

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Verifying klipper-install Package${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check critical files
echo -e "${GREEN}Checking critical files...${NC}"

check_file() {
    local file="$1"
    if [ -f "$file" ]; then
        echo -e "  ${GREEN}✓${NC} $file"
        return 0
    else
        echo -e "  ${RED}✗${NC} $file - MISSING!"
        ((ERRORS++))
        return 1
    fi
}

check_file "extras/winder.py"
check_file "kinematics/winder.py"
check_file ".config.winder-minimal"
check_file "install.sh"
check_file "SETUP_CM4_COMPLETE.sh"
check_file "config/generic-bigtreetech-manta-m8p-V1_1.cfg"

echo ""

# Check Python syntax
echo -e "${GREEN}Checking Python syntax...${NC}"
if python3 -m py_compile extras/winder.py 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} extras/winder.py syntax OK"
else
    echo -e "  ${RED}✗${NC} extras/winder.py syntax ERROR"
    ((ERRORS++))
fi

if python3 -m py_compile kinematics/winder.py 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} kinematics/winder.py syntax OK"
else
    echo -e "  ${RED}✗${NC} kinematics/winder.py syntax ERROR"
    ((ERRORS++))
fi

echo ""

# Check script syntax
echo -e "${GREEN}Checking script syntax...${NC}"
for script in install.sh SETUP_CM4_COMPLETE.sh CLEAN_CM4.sh; do
    if [ -f "$script" ]; then
        if bash -n "$script" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} $script syntax OK"
        else
            echo -e "  ${RED}✗${NC} $script syntax ERROR"
            ((ERRORS++))
        fi
    fi
done

echo ""

# Check file sizes (should not be empty)
echo -e "${GREEN}Checking file sizes...${NC}"
for file in extras/winder.py kinematics/winder.py .config.winder-minimal; do
    if [ -f "$file" ]; then
        size=$(wc -c < "$file")
        if [ "$size" -gt 100 ]; then
            size_kb=$((size / 1024))
            echo -e "  ${GREEN}✓${NC} $file (${size_kb}KB)"
        else
            echo -e "  ${RED}✗${NC} $file - TOO SMALL ($size bytes)"
            ((ERRORS++))
        fi
    fi
done

echo ""

# Summary
echo -e "${BLUE}========================================${NC}"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ All files verified!${NC}"
    echo ""
    echo "Ready to archive!"
    exit 0
else
    echo -e "${RED}❌ $ERRORS errors found!${NC}"
    echo ""
    echo "Please fix errors before archiving."
    exit 1
fi

