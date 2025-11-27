# Backup and Sync Strategy

Complete backup and synchronization plan for the winder system.

## File Locations

### On CM4 (Production System)

```
/home/winder/
├── klipper/                    # Klipper installation
│   ├── klippy/extras/         # Python modules
│   │   ├── hw_counter.py
│   │   ├── angle_sensor.py
│   │   ├── winder_control.py
│   │   ├── bldc_motor.py
│   │   └── traverse.py
│   └── src/                   # C firmware
│       └── hw_counter.c
│
├── printer.cfg                 # Main Klipper config
│
├── gcode_runner.py             # G-code file runner
├── verify_calibration.sh       # Calibration verification
│
├── examples/                   # G-code examples
│   ├── test_sequence.gcode
│   └── production_humbucker.gcode
│
├── calibration_reports/        # Calibration history
│   ├── calibration_*.txt
│   └── calibration_history.csv
│
└── klipper-install/            # Installation scripts
    └── scripts/
        ├── build_and_flash_hw_counter.sh
        └── query_sensors.py
```

### On Local Mac (Development/Backup)

```
~/Documents/GitHub/CM4-Pico-winder/
├── klipper-install/
│   ├── extras/                 # Python modules (source)
│   ├── kinematics/
│   ├── config/                 # Config files
│   │   └── printer-manta-m4p-modular.cfg
│   ├── scripts/                # Scripts
│   └── klipperscreen/          # GUI panels
│
├── src/                        # C firmware (source)
│   └── hw_counter.c
│
├── config/                     # Config files (source)
│   └── printer-manta-m4p-modular.cfg
│
└── docs/                       # Documentation
    ├── ANGLE_SENSOR_CALIBRATION.md
    ├── GUI_SETUP.md
    └── BACKUP_AND_SYNC.md
```

## Critical Files to Sync

### 1. Firmware (C Code)
- **Source:** `src/hw_counter.c`
- **Deployed:** `/home/winder/klipper/src/hw_counter.c`
- **Compiled:** `/home/winder/klipper/out/klipper.bin`

### 2. Python Modules
- **Source:** `klipper-install/extras/*.py`
- **Deployed:** `/home/winder/klipper/klippy/extras/*.py`

### 3. Configuration
- **Source:** `config/printer-manta-m4p-modular.cfg`
- **Deployed:** `/home/winder/printer.cfg`

### 4. Scripts
- **Source:** `klipper-install/scripts/*.py`, `*.sh`
- **Deployed:** `/home/winder/*.py`, `*.sh`

### 5. Calibration Data
- **Production:** `/home/winder/calibration_reports/`
- **Backup:** Should be pulled to local periodically

## Sync Scripts

### Pull from CM4 (Backup Production)

```bash
#!/bin/bash
# pull_from_cm4.sh - Backup production files to local

REMOTE="winder@winder.local"
LOCAL_BASE="$HOME/Documents/GitHub/CM4-Pico-winder"

echo "Pulling files from CM4..."

# Python modules
rsync -av --progress \
    $REMOTE:~/klipper/klippy/extras/hw_counter.py \
    $REMOTE:~/klipper/klippy/extras/angle_sensor.py \
    $REMOTE:~/klipper/klippy/extras/winder_control.py \
    $REMOTE:~/klipper/klippy/extras/bldc_motor.py \
    $REMOTE:~/klipper/klippy/extras/traverse.py \
    "$LOCAL_BASE/klipper-install/extras/"

# C firmware
rsync -av --progress \
    $REMOTE:~/klipper/src/hw_counter.c \
    "$LOCAL_BASE/src/"

# Configuration
rsync -av --progress \
    $REMOTE:~/printer.cfg \
    "$LOCAL_BASE/config/printer-manta-m4p-modular.cfg"

# Scripts
rsync -av --progress \
    $REMOTE:~/gcode_runner.py \
    $REMOTE:~/verify_calibration.sh \
    "$LOCAL_BASE/klipper-install/scripts/"

# Calibration data
mkdir -p "$LOCAL_BASE/backups/calibration_reports"
rsync -av --progress \
    $REMOTE:~/calibration_reports/ \
    "$LOCAL_BASE/backups/calibration_reports/"

echo "Pull complete!"
```

### Push to CM4 (Deploy Development)

```bash
#!/bin/bash
# push_to_cm4.sh - Deploy local changes to CM4

REMOTE="winder@winder.local"
LOCAL_BASE="$HOME/Documents/GitHub/CM4-Pico-winder"

echo "Pushing files to CM4..."

# Python modules
rsync -av --progress \
    "$LOCAL_BASE/klipper-install/extras/hw_counter.py" \
    "$LOCAL_BASE/klipper-install/extras/angle_sensor.py" \
    "$LOCAL_BASE/klipper-install/extras/winder_control.py" \
    "$LOCAL_BASE/klipper-install/extras/bldc_motor.py" \
    "$LOCAL_BASE/klipper-install/extras/traverse.py" \
    $REMOTE:~/klipper/klippy/extras/

# C firmware
rsync -av --progress \
    "$LOCAL_BASE/src/hw_counter.c" \
    $REMOTE:~/klipper/src/

# Configuration
rsync -av --progress \
    "$LOCAL_BASE/config/printer-manta-m4p-modular.cfg" \
    $REMOTE:~/printer.cfg

# Scripts
rsync -av --progress \
    "$LOCAL_BASE/klipper-install/scripts/gcode_runner.py" \
    "$LOCAL_BASE/klipper-install/scripts/verify_calibration.sh" \
    $REMOTE:~/

# Examples
ssh $REMOTE "mkdir -p ~/examples"
rsync -av --progress \
    "$LOCAL_BASE/klipper-install/scripts/examples/" \
    $REMOTE:~/examples/

echo ""
echo "Push complete!"
echo ""
echo "Next steps:"
echo "  1. If C code changed: Recompile and flash firmware"
echo "  2. If Python changed: Restart Klipper"
echo "  3. If config changed: Restart Klipper"
```

### Full Backup

```bash
#!/bin/bash
# full_backup_cm4.sh - Complete system backup

REMOTE="winder@winder.local"
BACKUP_DIR="$HOME/Documents/GitHub/CM4-Pico-winder/backups/$(date +%Y%m%d_%H%M%S)"

echo "Creating full backup to: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# Klipper installation
rsync -av --progress \
    $REMOTE:~/klipper/ \
    "$BACKUP_DIR/klipper/" \
    --exclude 'klippy-env' \
    --exclude '.git' \
    --exclude 'out'

# Printer config
rsync -av --progress \
    $REMOTE:~/printer.cfg \
    "$BACKUP_DIR/"

# Scripts
rsync -av --progress \
    $REMOTE:~/*.py \
    $REMOTE:~/*.sh \
    "$BACKUP_DIR/scripts/"

# Examples
rsync -av --progress \
    $REMOTE:~/examples/ \
    "$BACKUP_DIR/examples/"

# Calibration data
rsync -av --progress \
    $REMOTE:~/calibration_reports/ \
    "$BACKUP_DIR/calibration_reports/"

# Logs
rsync -av --progress \
    $REMOTE:/tmp/klippy.log \
    "$BACKUP_DIR/logs/"

# Compiled firmware
rsync -av --progress \
    $REMOTE:~/klipper/out/klipper.bin \
    "$BACKUP_DIR/"

echo ""
echo "Backup complete: $BACKUP_DIR"
echo ""
echo "Backup includes:"
echo "  - Klipper source and modules"
echo "  - Configuration files"
echo "  - Scripts and examples"
echo "  - Calibration history"
echo "  - Current firmware binary"
echo "  - System logs"
```

## Verification Script

```bash
#!/bin/bash
# verify_sync.sh - Verify local and CM4 are in sync

REMOTE="winder@winder.local"
LOCAL_BASE="$HOME/Documents/GitHub/CM4-Pico-winder"

echo "Verifying sync status..."
echo ""

# Function to compare files
compare_file() {
    local local_file=$1
    local remote_file=$2
    local name=$3
    
    if [ ! -f "$local_file" ]; then
        echo "❌ $name: Local file missing"
        return 1
    fi
    
    local_md5=$(md5 -q "$local_file" 2>/dev/null || md5sum "$local_file" | awk '{print $1}')
    remote_md5=$(ssh $REMOTE "md5sum $remote_file 2>/dev/null | awk '{print \$1}'")
    
    if [ "$local_md5" == "$remote_md5" ]; then
        echo "✅ $name: In sync"
        return 0
    else
        echo "⚠️  $name: OUT OF SYNC"
        return 1
    fi
}

# Check critical files
compare_file \
    "$LOCAL_BASE/src/hw_counter.c" \
    "~/klipper/src/hw_counter.c" \
    "hw_counter.c (firmware)"

compare_file \
    "$LOCAL_BASE/klipper-install/extras/hw_counter.py" \
    "~/klipper/klippy/extras/hw_counter.py" \
    "hw_counter.py"

compare_file \
    "$LOCAL_BASE/klipper-install/extras/angle_sensor.py" \
    "~/klipper/klippy/extras/angle_sensor.py" \
    "angle_sensor.py"

compare_file \
    "$LOCAL_BASE/klipper-install/extras/winder_control.py" \
    "~/klipper/klippy/extras/winder_control.py" \
    "winder_control.py"

compare_file \
    "$LOCAL_BASE/config/printer-manta-m4p-modular.cfg" \
    "~/printer.cfg" \
    "printer.cfg"

compare_file \
    "$LOCAL_BASE/klipper-install/scripts/gcode_runner.py" \
    "~/gcode_runner.py" \
    "gcode_runner.py"

echo ""
echo "Verification complete"
```

## Usage

### Initial Setup (First Time)

```bash
cd ~/Documents/GitHub/CM4-Pico-winder

# Make scripts executable
chmod +x pull_from_cm4.sh push_to_cm4.sh full_backup_cm4.sh verify_sync.sh

# Do initial pull to capture current state
./pull_from_cm4.sh

# Verify everything is in sync
./verify_sync.sh
```

### Daily Workflow

**Before making changes:**
```bash
# Pull latest from CM4
./pull_from_cm4.sh

# Verify sync
./verify_sync.sh
```

**After making changes locally:**
```bash
# Push to CM4
./push_to_cm4.sh

# If firmware changed:
ssh winder@winder.local "cd ~/klipper && make && make flash"

# If Python/config changed:
ssh winder@winder.local "sudo service klipper restart"

# Verify deployment
./verify_sync.sh
```

**Weekly backup:**
```bash
# Full system backup
./full_backup_cm4.sh
```

## Git Integration

### Initialize Git Repository

```bash
cd ~/Documents/GitHub/CM4-Pico-winder

# Initialize if not already done
git init

# Add .gitignore
cat > .gitignore << 'EOF'
# Backups
backups/

# Compiled files
*.pyc
__pycache__/
out/

# Logs
*.log

# OS files
.DS_Store
Thumbs.db
EOF

# Initial commit
git add .
git commit -m "Initial commit - working winder system"

# Tag stable version
git tag -a v1.0 -m "Stable calibrated system"
```

### Commit Workflow

```bash
# After making changes
git status
git add <changed_files>
git commit -m "Description of changes"

# Tag important milestones
git tag -a v1.1 -m "Added GUI support"
```

## Disaster Recovery

### Restore from Backup

```bash
# List available backups
ls -la ~/Documents/GitHub/CM4-Pico-winder/backups/

# Choose backup to restore
BACKUP_DATE="20241125_180000"
BACKUP_DIR="$HOME/Documents/GitHub/CM4-Pico-winder/backups/$BACKUP_DATE"

# Restore to CM4
rsync -av --progress \
    "$BACKUP_DIR/klipper/" \
    winder@winder.local:~/klipper/

rsync -av --progress \
    "$BACKUP_DIR/printer.cfg" \
    winder@winder.local:~/

rsync -av --progress \
    "$BACKUP_DIR/scripts/" \
    winder@winder.local:~/

# Restart services
ssh winder@winder.local "sudo service klipper restart"
```

### Fresh Install from Source

```bash
# Start with clean local repository
cd ~/Documents/GitHub/CM4-Pico-winder

# Deploy everything to fresh CM4
./push_to_cm4.sh

# Compile and flash firmware
ssh winder@winder.local "cd ~/klipper && make menuconfig && make && make flash"

# Restart Klipper
ssh winder@winder.local "sudo service klipper restart"

# Run calibration
ssh winder@winder.local "python3 ~/klipper_interface.py -g 'HOME_TRAVERSE'"
```

## Checklist

### Before Installing New Software (Like Moonraker)

- [ ] Run `./verify_sync.sh` - ensure everything in sync
- [ ] Run `./full_backup_cm4.sh` - create backup
- [ ] Commit to git with tag
- [ ] Document current working state
- [ ] Test basic winding operation
- [ ] Save calibration report

### After Making Changes

- [ ] Test changes locally if possible
- [ ] Push to CM4 with `./push_to_cm4.sh`
- [ ] Restart affected services
- [ ] Test functionality
- [ ] Pull back any generated data
- [ ] Commit to git
- [ ] Update documentation

## Summary

**You now have:**
- ✅ Automated backup scripts
- ✅ Sync verification
- ✅ Push/pull workflows
- ✅ Disaster recovery plan
- ✅ Git version control
- ✅ Clean baseline before GUI installation

**Next step:** Run the scripts to establish your clean baseline!

