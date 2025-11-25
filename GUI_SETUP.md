# Winder GUI Setup Guide

Complete guide for setting up Moonraker + KlipperScreen GUI for the coil winder.

## Overview

**Moonraker** - Web API server for Klipper (enables web interfaces like Mainsail/Fluidd)
**KlipperScreen** - Touchscreen GUI (if you have a display connected to CM4)

## Prerequisites

- CM4 with Klipper installed and working
- (Optional) Touchscreen display for KlipperScreen
- Network access for web interface

## Installation

### 1. Copy Installation Scripts

```bash
# Copy scripts to CM4
scp ~/Documents/GitHub/CM4-Pico-winder/klipper-install/scripts/install_moonraker.sh winder@winder.local:~/
scp ~/Documents/GitHub/CM4-Pico-winder/klipper-install/scripts/install_klipperscreen.sh winder@winder.local:~/

# Make executable
ssh winder@winder.local "chmod +x ~/install_moonraker.sh ~/install_klipperscreen.sh"
```

### 2. Install Moonraker (Required)

```bash
ssh winder@winder.local
~/install_moonraker.sh
```

This will:
- Clone Moonraker repository
- Install dependencies
- Create configuration
- Set up systemd service

**Start Moonraker:**
```bash
sudo systemctl start moonraker
sudo systemctl enable moonraker  # Enable on boot
```

**Verify:**
```bash
# Check status
sudo systemctl status moonraker

# Test API
curl http://localhost:7125/server/info
```

### 3. Install KlipperScreen (Optional - if you have a display)

```bash
ssh winder@winder.local
~/install_klipperscreen.sh
```

**Start KlipperScreen:**
```bash
sudo systemctl start KlipperScreen
sudo systemctl enable KlipperScreen  # Enable on boot
```

### 4. Install Custom Winder Panels

```bash
# Copy custom panels
scp -r ~/Documents/GitHub/CM4-Pico-winder/klipper-install/klipperscreen/panels/* winder@winder.local:~/KlipperScreen/panels/

# Restart KlipperScreen
ssh winder@winder.local "sudo systemctl restart KlipperScreen"
```

## Web Interface Options

### Option A: Mainsail (Recommended)

Modern, clean interface with good mobile support.

```bash
ssh winder@winder.local
cd ~
wget -q -O mainsail.zip https://github.com/mainsail-crew/mainsail/releases/latest/download/mainsail.zip
mkdir -p ~/mainsail
unzip mainsail.zip -d ~/mainsail
rm mainsail.zip
```

**Access:** `http://winder.local:7125` or `http://<CM4_IP>:7125`

### Option B: Fluidd

Alternative web interface, similar features to Mainsail.

```bash
ssh winder@winder.local
cd ~
wget -q -O fluidd.zip https://github.com/fluidd-core/fluidd/releases/latest/download/fluidd.zip
mkdir -p ~/fluidd
unzip fluidd.zip -d ~/fluidd
rm fluidd.zip
```

**Access:** `http://winder.local` or `http://<CM4_IP>`

## Custom Winder Panels

### Winding Panel

Main control interface for winding operations:
- **RPM Control** - Adjust spindle speed (10-3300 RPM)
- **Layer Control** - Set number of layers to wind
- **Quick Presets** - Test, Low, Medium, High speed presets
- **Home & Calibrate** - Run homing and calibration sequence
- **Start/Stop** - Control winding operation

**Features:**
- Large, touch-friendly buttons
- Real-time status display
- Safety interlocks (can't start while winding)

### Sensors Panel

Real-time sensor monitoring:
- **Angle Sensor**
  - Current angle (0-360°)
  - Turn count
  - ADC calibration range
- **Hall Sensor**
  - Pulse count
  - Spindle RPM
- **Auto-refresh** - Updates every 2 seconds

### Calibration Panel

(To be implemented)
- Run angle sensor calibration
- View calibration history
- Adjust calibration parameters

## Configuration

### Moonraker Config

Located at: `~/printer_data/config/moonraker.conf`

**Key settings:**
```ini
[server]
host: 0.0.0.0
port: 7125
klippy_uds_address: /tmp/klippy_uds

[authorization]
# Add your network to trusted_clients if needed
trusted_clients:
    192.168.1.0/24
```

### KlipperScreen Config

Located at: `~/printer_data/config/KlipperScreen.conf`

**Key settings:**
```ini
[main]
moonraker_host: 127.0.0.1
moonraker_port: 7125
theme: winder_dark
screen_blanking: 300

# Custom winder panels
[menu __main winding]
name: Winding
panel: winding_panel

[menu __main sensors]
name: Sensors
panel: sensors_panel
```

## Usage

### Web Interface

1. Open browser to `http://winder.local:7125` or `http://<CM4_IP>:7125`
2. You'll see the Mainsail/Fluidd interface
3. Navigate to "Console" to send G-code commands
4. Use "Macros" for quick access to winding commands

**Example workflow:**
1. Click "HOME_TRAVERSE" macro
2. Enter console: `WINDER_START RPM=300 LAYERS=10`
3. Monitor progress in console output
4. Click "WINDER_STOP" if needed

### Touchscreen Interface (KlipperScreen)

1. Touch screen wakes up
2. Main menu shows custom panels:
   - **Winding** - Main control
   - **Sensors** - Status monitoring
   - **Calibration** - Sensor setup
3. Navigate with touch gestures
4. Large buttons for easy operation

**Example workflow:**
1. Tap "Winding" panel
2. Adjust RPM and Layers with +/- buttons
3. Or tap a preset (Test, Low, Medium, High)
4. Tap "Home & Calibrate"
5. Tap "Start Winding"
6. Monitor in "Sensors" panel
7. Tap "Stop Winding" when done

## Customization

### Adding Custom Macros

Edit `~/printer.cfg`:

```cfg
[gcode_macro QUICK_TEST]
description: Quick 1-layer test wind
gcode:
    HOME_TRAVERSE
    WINDER_START RPM=100 LAYERS=1
    M117 Test complete

[gcode_macro PRODUCTION_5K]
description: Standard 5000-turn humbucker
gcode:
    HOME_TRAVERSE
    M117 Winding 5000 turns...
    WINDER_START RPM=300 LAYERS=57
    M117 Production complete
```

These will appear as buttons in the web interface!

### Custom KlipperScreen Theme

Create `~/printer_data/config/winder_theme.conf`:

```ini
[style]
# Winder-specific color scheme
color1: #1976D2  # Blue (decrease/back)
color2: #4CAF50  # Green (increase/start)
color3: #FF9800  # Orange (presets)
color4: #F44336  # Red (stop/emergency)
```

## Troubleshooting

### Moonraker won't start

```bash
# Check logs
journalctl -u moonraker -f

# Common issues:
# 1. Port 7125 already in use
sudo netstat -tulpn | grep 7125

# 2. Klipper not running
sudo systemctl status klipper

# 3. Permission issues
sudo chown -R winder:winder ~/printer_data
```

### KlipperScreen shows blank screen

```bash
# Check logs
journalctl -u KlipperScreen -f

# Common issues:
# 1. Display not detected
DISPLAY=:0 xrandr

# 2. Moonraker not reachable
curl http://localhost:7125/server/info

# 3. Python dependencies
cd ~/KlipperScreen
~/KlipperScreen-env/bin/python -c "import gi; gi.require_version('Gtk', '3.0')"
```

### Custom panels not showing

```bash
# Verify panel files exist
ls -la ~/KlipperScreen/panels/winding_panel.py
ls -la ~/KlipperScreen/panels/sensors_panel.py

# Check KlipperScreen config
cat ~/printer_data/config/KlipperScreen.conf | grep -A 3 "menu __main"

# Restart KlipperScreen
sudo systemctl restart KlipperScreen
```

### Web interface can't connect

```bash
# Check Moonraker is running
sudo systemctl status moonraker

# Check firewall
sudo ufw status
sudo ufw allow 7125/tcp

# Check network
ip addr show
ping winder.local
```

## Remote Access

### Access from Phone/Tablet

1. Connect to same network as CM4
2. Open browser to `http://winder.local:7125`
3. Add to home screen for app-like experience

### Access from Outside Network

**Option 1: VPN (Recommended)**
- Set up WireGuard or OpenVPN on CM4
- Connect via VPN to access locally

**Option 2: Port Forwarding (Less Secure)**
- Forward port 7125 on router to CM4
- Access via `http://<public_ip>:7125`
- **WARNING:** Secure with strong password!

## Next Steps

1. ✅ Install Moonraker
2. ✅ Install web interface (Mainsail/Fluidd)
3. ✅ Test web access
4. ✅ (Optional) Install KlipperScreen if you have display
5. ✅ Copy custom winder panels
6. ✅ Create production macros
7. ✅ Set up remote access if needed

## Advanced Features

### Webcam Integration

Add webcam to monitor winding:

```bash
# Install mjpg-streamer
sudo apt install cmake libjpeg-dev

# Add to moonraker.conf:
[webcam winder_cam]
location: coil
service: mjpeg
target_fps: 15
stream_url: http://127.0.0.1:8080/?action=stream
```

### Notifications

Get alerts when winding completes:

```bash
# Add to moonraker.conf:
[notifier telegram]
url: tgram://{bottoken}/{ChatID}
events: complete
body: Winding complete! {event_args[1].filename}
```

### Data Logging

Log winding operations to database:

```bash
# Add to moonraker.conf:
[data_store]
temperature_store_size: 1200
gcode_store_size: 1000
```

## Support

- **Moonraker Docs:** https://moonraker.readthedocs.io/
- **KlipperScreen Docs:** https://klipperscreen.readthedocs.io/
- **Klipper Docs:** https://www.klipper3d.org/

## Summary

You now have:
- ✅ Web interface for remote control
- ✅ Touchscreen GUI (if display connected)
- ✅ Custom winder panels
- ✅ Production-ready workflow
- ✅ Mobile access capability

**Your winder is now fully modernized with a professional GUI!**

