#!/bin/bash
# Setup Klipper Development Environment for CNC Guitar Winder
# Creates a LEAN ~/klipper installation, keeps FULL clone in klipper-install for reference

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
KLIPPER_DIR="$HOME/klipper"
DEV_KLIPPER="$INSTALL_DIR/klipper-dev"  # Full clone for reference/dev
DEV_BRANCH="winder-dev"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Klipper Development Environment Setup${NC}"
echo -e "${BLUE}CNC Guitar Winder Project${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Strategy:${NC}"
echo "  • Full clone → $DEV_KLIPPER (for reference/git workflow)"
echo "  • Lean install → $KLIPPER_DIR (production-ready, minimal files)"
echo ""

# Check if lean install exists
if [ -d "$KLIPPER_DIR" ]; then
    echo -e "${YELLOW}Lean Klipper directory exists: $KLIPPER_DIR${NC}"
    read -p "Remove and start fresh? [Y/n]: " answer
    if [ -z "$answer" ] || [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
        echo "Removing existing lean install..."
        rm -rf "$KLIPPER_DIR"
    else
        echo "Keeping existing installation"
        exit 0
    fi
fi

# Clone full Klipper repo to klipper-install for reference/dev
echo -e "${GREEN}Step 1: Cloning FULL Klipper repository (for reference)...${NC}"
if [ -d "$DEV_KLIPPER" ]; then
    echo -e "${YELLOW}  Dev clone exists, updating...${NC}"
    cd "$DEV_KLIPPER"
    git fetch origin
    git pull origin master || git pull origin main
else
    cd "$INSTALL_DIR"
    git clone https://github.com/Klipper3d/klipper.git "$DEV_KLIPPER"
    cd "$DEV_KLIPPER"
fi

# Create development branch in dev clone
echo -e "${GREEN}Step 2: Setting up git workflow in dev clone...${NC}"
git checkout -b "$DEV_BRANCH" 2>/dev/null || git checkout "$DEV_BRANCH" 2>/dev/null || true
echo "  ✓ Branch: $DEV_BRANCH"

# Add upstream remote (for updates)
if ! git remote | grep -q upstream; then
    git remote add upstream https://github.com/Klipper3d/klipper.git
    echo "  ✓ Added upstream remote"
fi

# Create LEAN installation - copy only essential files
echo -e "${GREEN}Step 3: Creating LEAN installation (essential files only)...${NC}"
mkdir -p "$KLIPPER_DIR"

# Essential directories/files for Klipper to work
ESSENTIAL_DIRS=(
    "klippy"           # Python runtime (required)
    "lib"              # Libraries (chelper, rp2040_flash, etc.)
    "scripts"          # Build/flash scripts
    "src"              # Firmware source (needed for build)
    ".github"          # GitHub config (for version info)
)

ESSENTIAL_FILES=(
    "Makefile"
    ".gitignore"
    "COPYING"
    "README.md"
)

# Copy essential directories from dev clone
for dir in "${ESSENTIAL_DIRS[@]}"; do
    if [ -d "$DEV_KLIPPER/$dir" ]; then
        cp -r "$DEV_KLIPPER/$dir" "$KLIPPER_DIR/"
        echo "  ✓ Copied: $dir/"
    fi
done

# Copy essential files
for file in "${ESSENTIAL_FILES[@]}"; do
    if [ -f "$DEV_KLIPPER/$file" ]; then
        cp "$DEV_KLIPPER/$file" "$KLIPPER_DIR/"
        echo "  ✓ Copied: $file"
    fi
done

# Copy klippy-requirements.txt if it exists
if [ -f "$DEV_KLIPPER/scripts/klippy-requirements.txt" ]; then
    mkdir -p "$KLIPPER_DIR/scripts"
    cp "$DEV_KLIPPER/scripts/klippy-requirements.txt" "$KLIPPER_DIR/scripts/"
    echo "  ✓ Copied: scripts/klippy-requirements.txt"
fi

# Clean up unused source files based on config
if [ -f "$KLIPPER_DIR/.config.winder-minimal" ] || [ -f "$KLIPPER_DIR/.config" ]; then
    echo -e "${GREEN}Step 3.5: Cleaning up unused source files...${NC}"
    CONFIG_FILE="$KLIPPER_DIR/.config.winder-minimal"
    [ ! -f "$CONFIG_FILE" ] && CONFIG_FILE="$KLIPPER_DIR/.config"
    "$INSTALL_DIR/scripts/cleanup_unused_src_files.sh" "$KLIPPER_DIR" "$CONFIG_FILE"
    
    # Patch Kconfig and Makefile to handle missing files/directories
    echo -e "${GREEN}Step 3.6: Patching Kconfig and Makefile for conditional sourcing...${NC}"
    "$INSTALL_DIR/scripts/patch_kconfig_conditional.sh" "$KLIPPER_DIR"
    "$INSTALL_DIR/scripts/patch_makefile_conditional.sh" "$KLIPPER_DIR"
fi

# Install custom winder files
echo -e "${GREEN}Step 4: Installing custom winder files...${NC}"
cd "$INSTALL_DIR"

# Create directories
mkdir -p "$KLIPPER_DIR/klippy/extras"
mkdir -p "$KLIPPER_DIR/klippy/kinematics"
mkdir -p "$KLIPPER_DIR/scripts"

# Copy required modules
if [ -f "extras/winder.py" ]; then
    cp extras/winder.py "$KLIPPER_DIR/klippy/extras/"
    echo "  ✓ winder.py → klippy/extras/"
fi

if [ -f "kinematics/winder.py" ]; then
    cp kinematics/winder.py "$KLIPPER_DIR/klippy/kinematics/"
    echo "  ✓ winder.py → klippy/kinematics/"
fi

# Copy build config
if [ -f ".config.winder-minimal" ]; then
    cp .config.winder-minimal "$KLIPPER_DIR/.config.winder-minimal"
    echo "  ✓ .config.winder-minimal"
fi

# Copy helper scripts
if [ -d "scripts" ]; then
    for script in scripts/*.py scripts/*.sh; do
        if [ -f "$script" ] && [[ "$script" != *"setup_dev_environment.sh" ]]; then
            cp "$script" "$KLIPPER_DIR/scripts/" 2>/dev/null && \
                echo "  ✓ $(basename $script) → scripts/" || true
        fi
    done
fi

# Download official docs for reference
echo -e "${GREEN}Step 5: Downloading official Klipper documentation...${NC}"
"$INSTALL_DIR/scripts/download_klipper_docs.sh"

# Setup Python virtual environment
echo -e "${GREEN}Step 6: Setting up Python environment...${NC}"
cd "$KLIPPER_DIR"
[ ! -d "klippy-env" ] && python3 -m venv klippy-env
source klippy-env/bin/activate
pip install --upgrade pip

if [ -f "scripts/klippy-requirements.txt" ]; then
    pip install -r scripts/klippy-requirements.txt
else
    pip install cffi pyserial
fi
echo "  ✓ Python environment ready"

# Compile chelper
echo -e "${GREEN}Step 7: Compiling chelper...${NC}"
cd "$KLIPPER_DIR/klippy/chelper"
if [ -f "setup.py" ]; then
    python3 setup.py build_ext --inplace
    echo "  ✓ chelper compiled"
fi

# Create cleanup script in klipper directory for manual use
echo -e "${GREEN}Step 7.5: Creating cleanup helper script...${NC}"
cd "$KLIPPER_DIR"
if [ -f "$INSTALL_DIR/scripts/cleanup_unused_src_files.sh" ]; then
    cp "$INSTALL_DIR/scripts/cleanup_unused_src_files.sh" "$KLIPPER_DIR/scripts/cleanup_unused_src_files.sh"
    chmod +x "$KLIPPER_DIR/scripts/cleanup_unused_src_files.sh"
    echo "  ✓ Cleanup script available at: scripts/cleanup_unused_src_files.sh"
fi

# Create development helper scripts
echo -e "${GREEN}Step 8: Creating development helper scripts...${NC}"
cd "$KLIPPER_DIR"

# Build script (works on lean install)
cat > dev_build.sh <<'EOF'
#!/bin/bash
# Quick build script for development
cd "$(dirname "$0")"
source klippy-env/bin/activate
make
EOF
chmod +x dev_build.sh

# Flash script (works on lean install)
cat > dev_flash.sh <<'EOF'
#!/bin/bash
# Quick flash script for development
cd "$(dirname "$0")"
source klippy-env/bin/activate

# Auto-detect MCU
MCU=$(ls /dev/serial/by-id/*Klipper* 2>/dev/null | head -1)
if [ -z "$MCU" ]; then
    echo "Error: No Klipper MCU found"
    exit 1
fi

echo "Flashing to: $MCU"
make flash FLASH_DEVICE="$MCU"
EOF
chmod +x dev_flash.sh

# Test script (works on lean install)
cat > dev_test.sh <<'EOF'
#!/bin/bash
# Quick test script
cd "$(dirname "$0")"
source klippy-env/bin/activate

# Run winder tests if available
if [ -f "scripts/test_winder.py" ]; then
    python3 scripts/test_winder.py
else
    echo "No test script found"
fi
EOF
chmod +x dev_test.sh

# Git workflow script (uses dev clone)
cat > dev_git.sh <<EOF
#!/bin/bash
# Git workflow helper - uses dev clone for git operations
# Usage: ./dev_git.sh <command> [args]
# Example: ./dev_git.sh status
#          ./dev_git.sh commit -m "message"
#          ./dev_git.sh push

DEV_KLIPPER="$DEV_KLIPPER"

if [ ! -d "\$DEV_KLIPPER" ]; then
    echo "Error: Dev clone not found at: \$DEV_KLIPPER"
    exit 1
fi

cd "\$DEV_KLIPPER"
git "\$@"
EOF
chmod +x dev_git.sh

# Update script (uses dev clone, then syncs to lean install)
cat > dev_update.sh <<EOF
#!/bin/bash
# Update Klipper from upstream (dev clone) and sync to lean install
DEV_KLIPPER="$DEV_KLIPPER"
KLIPPER_DIR="$KLIPPER_DIR"

if [ ! -d "\$DEV_KLIPPER" ]; then
    echo "Error: Dev clone not found"
    exit 1
fi

echo "Updating dev clone from upstream..."
cd "\$DEV_KLIPPER"
git fetch upstream
git merge upstream/master || git merge upstream/main

echo "Syncing essential files to lean install..."
# Re-copy essential directories
for dir in klippy lib scripts src .github; do
    if [ -d "\$DEV_KLIPPER/\$dir" ]; then
        rm -rf "\$KLIPPER_DIR/\$dir"
        cp -r "\$DEV_KLIPPER/\$dir" "\$KLIPPER_DIR/"
    fi
done

# Re-copy essential files
for file in Makefile .gitignore COPYING README.md; do
    if [ -f "\$DEV_KLIPPER/\$file" ]; then
        cp "\$DEV_KLIPPER/\$file" "\$KLIPPER_DIR/"
    fi
done

echo "✓ Updated and synced"
EOF
chmod +x dev_update.sh

echo "  ✓ Created helper scripts:"
echo "    - dev_build.sh   - Quick build (lean install)"
echo "    - dev_flash.sh    - Quick flash (lean install)"
echo "    - dev_test.sh     - Run tests (lean install)"
echo "    - dev_git.sh      - Git workflow (uses dev clone)"
echo "    - dev_update.sh   - Update from upstream & sync"

# Create .gitignore for custom files
echo -e "${GREEN}Step 9: Setting up git ignore...${NC}"
cat >> "$KLIPPER_DIR/.gitignore" <<'EOF'

# Winder development files
.config.winder-minimal
*.bin
*.elf
out/
EOF
echo "  ✓ Updated .gitignore"

# Create development README
echo -e "${GREEN}Step 10: Creating development documentation...${NC}"
cat > "$KLIPPER_DIR/DEV_README.md" <<'EOF'
# Klipper Development Environment - CNC Guitar Winder

## Quick Start

```bash
# Build firmware
./dev_build.sh

# Flash firmware
./dev_flash.sh

# Run tests
./dev_test.sh

# Update from upstream Klipper
./dev_update.sh
```

## Custom Files

- `klippy/extras/winder.py` - Winder controller module
- `klippy/kinematics/winder.py` - Winder kinematics module
- `.config.winder-minimal` - Minimal build config

## Development Workflow

1. Make changes to custom files
2. Test locally: `./dev_test.sh`
3. Build: `./dev_build.sh`
4. Flash: `./dev_flash.sh`
5. Test on hardware

## Git Workflow

- Development branch: `winder-dev`
- Upstream: `upstream/master`
- To update: `./dev_update.sh`

## File Locations

- Klipper: `~/klipper`
- Config: `~/printer.cfg` (on CM4)
- Logs: `/tmp/klippy.log` (on CM4)
EOF
echo "  ✓ Created DEV_README.md"

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Development Environment Ready!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}Full dev clone:${NC} $DEV_KLIPPER (for git/reference)"
echo -e "${GREEN}Lean install:${NC}   $KLIPPER_DIR (production-ready)"
echo ""
echo "Next steps:"
echo "  1. cd ~/klipper"
echo "  2. Review DEV_README.md"
echo "  3. ./dev_build.sh"
echo ""
echo "Git workflow:"
echo "  cd ~/klipper"
echo "  ./dev_git.sh status    # Check git status"
echo "  ./dev_git.sh commit -m 'message'  # Commit changes"
echo ""

