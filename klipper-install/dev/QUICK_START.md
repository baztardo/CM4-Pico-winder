# Quick Start Guide

Fastest way to get a complete Klipper installation with winder support.

## Method 1: Clone and Install (Recommended)

**On CM4:**

```bash
# Copy klipper-install folder to CM4
# From Mac: scp -r ~/Desktop/klipper-install winder@winder.local:~/

# Run clone and install script
cd ~/klipper-install
chmod +x CLONE_AND_INSTALL.sh
./CLONE_AND_INSTALL.sh ~/klipper
```

This single command:
- ✅ Clones fresh Klipper
- ✅ Installs custom files
- ✅ Sets up Python virtual environment
- ✅ Compiles chelper files
- ✅ Configures build

## Method 2: Complete Setup (Includes Dependencies)

**On CM4:**

```bash
cd ~/klipper-install
chmod +x SETUP_CM4_COMPLETE.sh
./SETUP_CM4_COMPLETE.sh
```

This handles everything including system dependencies.

## Method 3: Manual Steps

```bash
# 1. Clone Klipper
git clone https://github.com/Klipper3d/klipper.git ~/klipper

# 2. Install custom files
cd ~/klipper-install
./install.sh ~/klipper

# 3. Set up Python environment
cd ~/klipper
python3 -m venv klippy-env
source klippy-env/bin/activate
pip install --upgrade pip
pip install -r scripts/klippy-requirements.txt

# 4. Compile chelper
cd klippy/chelper
python3 setup.py build_ext --inplace
cd ../..

# 5. Configure build
cp .config.winder-minimal .config

# 6. Build firmware
make
```

## Comparison

| Method | Dependencies | Clone | Python Env | chelper | Custom Files | Total Steps |
|--------|-------------|-------|------------|---------|--------------|-------------|
| **CLONE_AND_INSTALL.sh** | ❌ | ✅ | ✅ | ✅ | ✅ | 1 command |
| **SETUP_CM4_COMPLETE.sh** | ✅ | ✅ | ✅ | ✅ | ✅ | 1 command |
| **Manual** | ❌ | Manual | Manual | Manual | Manual | 6+ steps |

## Which Method to Use?

- **CLONE_AND_INSTALL.sh** - If dependencies already installed
- **SETUP_CM4_COMPLETE.sh** - If starting from scratch (recommended)
- **Manual** - If you want full control

## After Installation

1. **Build firmware:**
   ```bash
   cd ~/klipper
   make
   ```

2. **Flash firmware to MCU**

3. **Configure:**
   ```bash
   cp ~/klipper-install/config/generic-bigtreetech-manta-m8p-V1_1.cfg ~/printer.cfg
   nano ~/printer.cfg  # Update serial port
   ```

4. **Install service:**
   ```bash
   cd ~/klipper/scripts
   sudo ./install-octopi.sh
   ```

5. **Start Klipper:**
   ```bash
   sudo systemctl start klipper
   tail -f /tmp/klippy.log
   ```

## Troubleshooting

**Clone fails:**
- Check internet connection
- Verify git is installed: `which git`

**Python venv fails:**
- Install python3-venv: `sudo apt install python3-venv`

**chelper fails:**
- Install python3-dev: `sudo apt install python3-dev`

**Custom files not found:**
- Verify klipper-install folder is in current directory
- Check file paths in install.sh

