# Quick Start - Automated Setup

The setup script now supports automation and MCU auto-detection!

## Usage Examples

### 1. Auto-detect MCU (Recommended)
```bash
cd ~/klipper-install
./SETUP_CM4_COMPLETE.sh --mcu=AUTO
```
- Automatically detects MCU from USB devices
- Still prompts for menuconfig to verify

### 2. Specify MCU (No Detection)
```bash
# For Manta MP8 (STM32G0B1)
./SETUP_CM4_COMPLETE.sh --mcu=STM32G0B1

# For SKR Pico (RP2040)
./SETUP_CM4_COMPLETE.sh --mcu=RP2040
```

### 3. Fully Automated (No Prompts)
```bash
# Auto-detect MCU, skip all prompts
./SETUP_CM4_COMPLETE.sh --mcu=AUTO --non-interactive

# Skip system upgrade prompt too
./SETUP_CM4_COMPLETE.sh --mcu=STM32G0B1 --non-interactive --skip-upgrade
```

## What Gets Automated

✅ **MCU Detection**: Scans USB devices for STM32/RP2040  
✅ **Config Presets**: Applies minimal config for your MCU  
✅ **Smaller Firmware**: Minimal features enabled (LCD, neopixel disabled)  
✅ **Service Setup**: Creates systemd service automatically  
✅ **Python Environment**: Sets up venv and chelper  

## MCU Presets

### STM32G0B1 (Manta MP8)
- Uses `.config.winder-minimal` preset
- Minimal features disabled
- All winder features enabled

### RP2040 (SKR Pico)
- Auto-generated minimal config
- Same minimal features as STM32
- RP2040-specific settings

## Manual Override

If you need to change MCU settings after setup:
```bash
cd ~/klipper
make menuconfig
make
```

## Help

```bash
./SETUP_CM4_COMPLETE.sh --help
```

