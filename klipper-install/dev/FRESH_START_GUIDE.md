# Fresh Start Guide

Complete guide for starting fresh with a clean Klipper installation and this custom package.

## Prerequisites

- Clean slate (no existing Klipper installation)
- This `klipper-install` folder
- CM4 with Pi OS Desktop installed
- STM32G0B1 MCU (Manta MP8)

## Step-by-Step Fresh Installation

### Part 1: On Your Mac

#### 1. Archive This Folder

```bash
# Move to safe location
mv klipper-install ~/Documents/Archive/klipper-install-$(date +%Y%m%d)
```

#### 2. Clean Up (Optional)

```bash
# Delete old repo if exists
rm -rf ~/Documents/GitHub/CM4-Pico-winder
```

### Part 2: On CM4

#### 1. Clean Up Existing Installation

```bash
# Stop Klipper service
sudo systemctl stop klipper
sudo systemctl disable klipper

# Remove old Klipper
rm -rf ~/klipper

# Remove old config
rm -f ~/printer.cfg

# Clean up logs
rm -f /tmp/klippy.log
```

#### 2. Install Dependencies

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install build tools
sudo apt install -y build-essential git python3 python3-pip

# Install Klipper dependencies
sudo apt install -y libncurses-dev libusb-1.0-0-dev

# Install ARM cross-compiler (REQUIRED for STM32)
sudo apt install -y gcc-arm-none-eabi binutils-arm-none-eabi

# Install Python serial library
sudo apt install -y python3-serial

# Install flashing tools
sudo apt install -y dfu-util
```

#### 3. Clone Fresh Klipper

```bash
cd ~
git clone https://github.com/Klipper3d/klipper.git
cd ~/klipper
```

#### 4. Copy klipper-install Folder

**From your Mac:**
```bash
# Copy entire folder
scp -r ~/Documents/Archive/klipper-install-* winder@winder.local:~/klipper-install

# Or if you have it locally:
scp -r klipper-install winder@winder.local:~/klipper-install
```

**Or manually copy files:**
```bash
# On CM4, create directory
mkdir -p ~/klipper-install

# Then copy files from Mac using scp or USB drive
```

#### 5. Install Custom Files

```bash
cd ~/klipper-install
chmod +x install.sh
./install.sh ~/klipper
```

This will copy:
- `extras/winder.py` → `~/klipper/klippy/extras/winder.py`
- `kinematics/winder.py` → `~/klipper/klippy/kinematics/winder.py`
- `.config.winder-minimal` → `~/klipper/.config.winder-minimal`
- All scripts → `~/klipper/scripts/`

#### 6. Configure Build

```bash
cd ~/klipper

# Use minimal config
cp .config.winder-minimal .config

# Or configure manually
make menuconfig
# Select:
#   - Micro-controller Architecture: STM32
#   - Processor model: STM32G0B1
#   - Bootloader offset: 8KiB bootloader
#   - Clock Reference: 8 MHz crystal
#   - Communication interface: USB (on PA11/PA12)
```

#### 7. Build Firmware

```bash
cd ~/klipper
make clean
make
```

#### 8. Flash Firmware to MCU

**Option A: SD Card Method (Recommended)**
```bash
# Copy firmware to SD card
sudo cp ~/klipper/out/klipper.bin /mnt/sd/firmware.bin
# Insert SD card into MP8, power cycle
```

**Option B: USB/DFU Method**
```bash
# Enter bootloader mode on MP8
# Then flash:
make flash FLASH_DEVICE=/dev/serial/by-id/usb-Klipper_stm32g0b1xx_*-if00
```

#### 9. Configure Klipper

```bash
# Copy config file
cp ~/klipper-install/config/generic-bigtreetech-manta-m8p-V1_1.cfg ~/printer.cfg

# Find MCU serial port
ls -la /dev/serial/by-id/

# Edit config
nano ~/printer.cfg

# Update serial port in [mcu] section:
# serial: /dev/serial/by-id/usb-Klipper_stm32g0b1xx_XXXXXXXX-if00
```

#### 10. Install Klipper Service

```bash
cd ~/klipper/scripts
sudo ./install-octopi.sh
```

**Or manually:**
```bash
sudo nano /etc/systemd/system/klipper.service
```

Add:
```ini
[Unit]
Description=Klipper 3D Printer Firmware
After=network.target

[Service]
Type=simple
User=winder
RemainAfterExit=yes
ExecStart=/usr/bin/python3 /home/winder/klipper/klippy/klippy.py /home/winder/printer.cfg -l /tmp/klippy.log --api-server /tmp/klippy_uds
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Then:
```bash
sudo systemctl daemon-reload
sudo systemctl enable klipper
sudo systemctl start klipper
```

#### 11. Verify Installation

```bash
# Check service status
sudo systemctl status klipper

# Check logs
tail -f /tmp/klippy.log

# Test connection
python3 ~/klipper/scripts/klipper_interface.py --query printer

# Test winder module
python3 ~/klipper/scripts/simple_stepper_test.py
```

## Verification Checklist

- [ ] Klipper service is running
- [ ] MCU connects successfully
- [ ] Winder module loads without errors
- [ ] Stepper can be enabled
- [ ] Basic movement works
- [ ] Hall sensor detects rotation
- [ ] Angle sensor reads values
- [ ] BLDC motor can be controlled

## Troubleshooting

### MCU Won't Connect
- Check serial port: `ls -la /dev/serial/by-id/`
- Verify firmware flashed: Check MCU version in logs
- Try `FIRMWARE_RESTART` command

### Winder Module Not Found
- Verify files copied: `ls -la ~/klipper/klippy/extras/winder.py`
- Check Python syntax: `python3 -m py_compile ~/klipper/klippy/extras/winder.py`
- Check logs for import errors

### Build Errors
- Verify `.config` exists: `ls -la ~/klipper/.config`
- Check MCU selection matches board
- Try `make clean` then `make`

### Service Won't Start
- Check logs: `journalctl -u klipper -n 50`
- Verify config file exists: `ls -la ~/printer.cfg`
- Check file permissions: `ls -la ~/klipper/klippy/klippy.py`

## Next Steps

After successful installation:

1. **Test basic stepper movement**
2. **Test traverse homing**
3. **Test BLDC motor control**
4. **Calibrate sensors**
5. **Test winding sequence**

## Files Reference

| File | Location | Purpose |
|------|----------|---------|
| `extras/winder.py` | `~/klipper/klippy/extras/` | Winder controller |
| `kinematics/winder.py` | `~/klipper/klippy/kinematics/` | Winder kinematics |
| `.config.winder-minimal` | `~/klipper/.config` | Build config |
| `config/*.cfg` | `~/printer.cfg` | Printer config |

## Support

If something doesn't work:

1. Check logs: `tail -f /tmp/klippy.log`
2. Run diagnostic: `python3 ~/klipper/scripts/diagnose_everything.py`
3. Verify files: `./scripts/list_custom_files.sh`
4. Check this guide for common issues

