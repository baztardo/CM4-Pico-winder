# CM4-Pico-winder
CNC Pickup Coil Winder

A professional-grade CNC pickup coil winding system using Raspberry Pi CM4 and RP2350 Pico microcontroller.

## 🎯 Features

- **Precision CNC Control**: Sub-millimeter accuracy for pickup coil winding
- **Real-time Monitoring**: RPM, position, and turn counting feedback
- **Touchscreen Interface**: Modern web-based control panel
- **Safety Systems**: Emergency stop, position limits, and fault detection
- **Professional Operation**: 2500-10000 turn coils with consistent quality

## 🏗️ Architecture

This project implements a **custom firmware architecture** inspired by proven 3D printer control systems:

### Firmware (RP2350 Pico)
- **Event-driven core** with microsecond precision timing
- **PWM spindle control** for BLDC motors
- **Multi-axis stepper synchronization**
- **Real-time safety monitoring**

### Host Software (Raspberry Pi CM4)
- **Python control application** for job management
- **Web interface** for touchscreen operation
- **Configuration system** for hardware parameters

## 📚 Documentation

- **[Quick Start Guide](docs/QUICKSTART.txt)** - Get up and running fast
- **[Build Guide](docs/BUILD_GUIDE.md)** - Compile and flash firmware
- **[Operational Guide](docs/OPERATIONAL_GUIDE.md)** - Complete usage instructions
- **[Technical Specifications](docs/TECHNICAL_SPECIFICATIONS.md)** - Hardware details
- **[System Flowchart](docs/SYSTEM_FLOWCHART.md)** - Complete system diagram

## 🚀 Quick Start

```bash
# 1. Build firmware
./build.sh

# 2. Flash to Pico
cp out/klipper.uf2 /media/YOUR_USER/RPI-RP2/

# 3. Setup CM4 interface
./setup_cnc_winder.sh

# 4. Access web interface at http://YOUR_CM4_IP
```

## ⚙️ Hardware Requirements

- **Raspberry Pi CM4** (with touchscreen)
- **RP2350 Pico** microcontroller
- **BLDC spindle motor** (ZS-X11H compatible)
- **Stepper motors** (traverse + pickup)
- **Hall sensors** and limit switches

## 📝 Credits & Attribution

This project is **not affiliated with or endorsed by** the original projects, but builds upon proven concepts:

### Core Architecture
- **Inspired by Klipper firmware** - Event-driven real-time control
- **Thanks to Kevin O'Connor** and the Klipper community for the excellent firmware foundation
- **PWM implementation** based on Klipper's hardware PWM drivers

### Web Interface
- **Interface design** inspired by modern 3D printer web interfaces
- **Special thanks** to the Mainsail team for excellent web interface concepts
- **Touchscreen optimization** adapted for CNC control

### Support the Original Projects
If you find this project useful, please consider supporting the original projects:
- **Klipper**: [github.com/KevinOConnor/klipper](https://github.com/KevinOConnor/klipper)
- **Mainsail**: [github.com/mainsail-crew/mainsail](https://github.com/mainsail-crew/mainsail)

## 📄 License

This project is released under the **GNU General Public License v3.0**.

The CNC winder firmware and control system are original implementations, though they incorporate concepts and inspiration from the 3D printing community.
