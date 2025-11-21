#!/usr/bin/env python3
"""
Complete CM4 Setup Script (Python Version)
Handles: Dependencies, Klipper clone, Python venv, chelper compilation, custom files
Usage: python3 setup_cm4.py [--mcu=STM32G0B1|RP2040|AUTO] [--non-interactive]

Note: Requires Python 3.6+ (pre-installed on Raspberry Pi OS)
"""

import os
import sys
import subprocess
import shutil
import argparse
import re
from pathlib import Path
from typing import Optional, Tuple, List

# Check Python version
if sys.version_info < (3, 6):
    print("Error: Python 3.6 or higher is required")
    print(f"Current version: {sys.version}")
    print("\nInstall Python3:")
    print("  sudo apt update")
    print("  sudo apt install python3")
    sys.exit(1)

# Colors for terminal output
class Colors:
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    RED = '\033[0;31m'
    NC = '\033[0m'  # No Color

def print_colored(message: str, color: str = Colors.NC):
    """Print colored message"""
    print(f"{color}{message}{Colors.NC}")

def run_command(cmd: List[str], check: bool = True, capture_output: bool = False, 
                cwd: Optional[Path] = None, shell: bool = False) -> subprocess.CompletedProcess:
    """Run shell command with error handling"""
    try:
        if shell:
            cmd_str = ' '.join(cmd) if isinstance(cmd, list) else cmd
            result = subprocess.run(
                cmd_str,
                check=check,
                capture_output=capture_output,
                text=True,
                shell=True,
                cwd=str(cwd) if cwd else None
            )
        else:
            result = subprocess.run(
                cmd,
                check=check,
                capture_output=capture_output,
                text=True,
                cwd=str(cwd) if cwd else None
            )
        return result
    except subprocess.CalledProcessError as e:
        print_colored(f"Error running command: {' '.join(cmd) if isinstance(cmd, list) else cmd}", Colors.RED)
        print_colored(f"Error: {e}", Colors.RED)
        if not check:
            return e
        raise

def detect_mcu_from_usb() -> Optional[str]:
    """Auto-detect MCU from USB devices"""
    print_colored("Auto-detecting MCU from USB devices...", Colors.BLUE)
    
    try:
        # Check for STM32 (Klipper USB ID)
        result = run_command(["lsusb"], capture_output=True)
        if "1d50:614e" in result.stdout:
            print_colored("  ✓ Found STM32 device (Klipper USB ID)", Colors.GREEN)
            
            # Check serial ports for STM32G0
            serial_path = Path("/dev/serial/by-id")
            if serial_path.exists():
                for port in serial_path.iterdir():
                    if "stm32g0" in port.name.lower():
                        print_colored("  → Detected: STM32G0B1 (likely Manta MP8 or similar)", Colors.GREEN)
                        return "STM32G0B1"
            
            print_colored("  → Detected: STM32 (generic, defaulting to G0B1)", Colors.GREEN)
            return "STM32G0B1"
        
        # Check for RP2040
        if "2e8a" in result.stdout:
            print_colored("  ✓ Found RP2040 device (Raspberry Pi USB ID)", Colors.GREEN)
            return "RP2040"
        
        # Check serial ports for hints
        serial_path = Path("/dev/serial/by-id")
        if serial_path.exists():
            for port in serial_path.iterdir():
                if "rp2040" in port.name.lower() or "pico" in port.name.lower():
                    print_colored(f"  → Detected: RP2040 (from serial port: {port.name})", Colors.GREEN)
                    return "RP2040"
                if "Klipper" in port.name:
                    print_colored("  → Found Klipper device (defaulting to STM32G0B1)", Colors.GREEN)
                    return "STM32G0B1"
        
        print_colored("  ⚠ Could not auto-detect MCU from USB devices", Colors.YELLOW)
        print_colored("  → Defaulting to STM32G0B1 (you can change in menuconfig)", Colors.YELLOW)
        return "STM32G0B1"
        
    except Exception as e:
        print_colored(f"  ⚠ Detection error: {e}", Colors.YELLOW)
        return "STM32G0B1"  # Safe default

def apply_mcu_preset(mcu_type: str, klipper_dir: Path, install_dir: Path) -> bool:
    """Apply MCU preset configuration"""
    print_colored(f"Applying MCU preset: {mcu_type}", Colors.GREEN)
    
    config_file = klipper_dir / ".config"
    
    if mcu_type == "STM32G0B1":
        preset_file = install_dir / ".config.winder-minimal"
        if preset_file.exists():
            shutil.copy(preset_file, config_file)
            print_colored("  ✓ Applied STM32G0B1 minimal config", Colors.GREEN)
            print_colored(f"  → Config file: {preset_file}", Colors.BLUE)
            return True
        else:
            print_colored(f"  ⚠ Minimal config not found at: {preset_file}", Colors.YELLOW)
            # Try alternative locations
            alt_locations = [
                klipper_dir / ".config.winder-minimal",
                Path.home() / "klipper-install" / ".config.winder-minimal"
            ]
            for alt in alt_locations:
                if alt.exists():
                    shutil.copy(alt, config_file)
                    print_colored(f"  ✓ Found and applied config from: {alt}", Colors.GREEN)
                    return True
            print_colored("  ✗ Config file not found in any location", Colors.RED)
            return False
    
    elif mcu_type == "RP2040":
        # Create RP2040 minimal config
        rp2040_config = """# RP2040 Minimal Config for Winder
CONFIG_MACH_RPXXXX=y
CONFIG_MACH_RP2040=y
CONFIG_MACH_RP2040_E5=y
CONFIG_BOARD_DIRECTORY="rp2040"
CONFIG_MCU="rp2040"
CONFIG_CLOCK_FREQ=12000000
CONFIG_USB_SERIAL_NUMBER_CHIPID=y
CONFIG_WANT_STEPPER=y
CONFIG_WANT_ADC=y
CONFIG_WANT_SPI=y
CONFIG_WANT_SOFTWARE_SPI=y
CONFIG_WANT_I2C=y
CONFIG_WANT_SOFTWARE_I2C=y
CONFIG_WANT_HARD_PWM=y
CONFIG_WANT_BUTTONS=y
CONFIG_WANT_TMCUART=y
CONFIG_WANT_PULSE_COUNTER=y
# CONFIG_WANT_NEOPIXEL is not set
# CONFIG_WANT_THERMOCOUPLE is not set
# CONFIG_WANT_ST7920 is not set
# CONFIG_WANT_HD44780 is not set
# CONFIG_WANT_ADXL345 is not set
# CONFIG_WANT_LIS2DW is not set
# CONFIG_WANT_MPU9250 is not set
# CONFIG_WANT_ICM20948 is not set
# CONFIG_WANT_HX71X is not set
# CONFIG_WANT_ADS1220 is not set
# CONFIG_WANT_LDC1612 is not set
# CONFIG_WANT_LOAD_CELL_PROBE is not set
"""
        config_file.write_text(rp2040_config)
        print_colored("  ✓ Applied RP2040 minimal config", Colors.GREEN)
        return True
    
    return False

def update_serial_port(config_file: Path) -> bool:
    """Auto-detect and update serial port in config file"""
    if not config_file.exists():
        print_colored(f"  ⚠ Config file not found: {config_file}", Colors.YELLOW)
        return False
    
    print_colored("Detecting serial port...", Colors.GREEN)
    
    # Find Klipper device
    serial_port = None
    serial_path = Path("/dev/serial/by-id")
    
    if serial_path.exists():
        ports = list(serial_path.iterdir())
        # Look for Klipper device first
        for port in ports:
            if any(keyword in port.name for keyword in ["Klipper", "stm32", "rp2040", "pico"]):
                serial_port = str(port)
                print_colored(f"  ✓ Found device: {serial_port}", Colors.GREEN)
                break
        
        # Fallback to first available
        if not serial_port and ports:
            serial_port = str(ports[0])
            print_colored(f"  ⚠ Using first available device: {serial_port}", Colors.YELLOW)
    
    if not serial_port:
        print_colored("  ⚠ No serial device found", Colors.YELLOW)
        print_colored("  → You'll need to update the config manually after connecting the MCU", Colors.YELLOW)
        return False
    
    # Update config file
    try:
        config_content = config_file.read_text()
        
        # Check if [mcu] section exists
        if "[mcu" not in config_content:
            print_colored("  ⚠ No [mcu] section found in config", Colors.YELLOW)
            print_colored(f"  → Add [mcu] section with: serial: {serial_port}", Colors.YELLOW)
            return False
        
        # Update or add serial line
        lines = config_content.split('\n')
        updated = False
        
        for i, line in enumerate(lines):
            if line.strip().startswith("serial:"):
                old_line = line
                lines[i] = f"serial: {serial_port}"
                print_colored("  ✓ Updated serial port in config", Colors.GREEN)
                print_colored(f"     Old: {old_line.strip()}", Colors.BLUE)
                print_colored(f"     New: serial: {serial_port}", Colors.BLUE)
                updated = True
                break
        
        if not updated:
            # Add serial line after [mcu] section
            for i, line in enumerate(lines):
                if line.strip().startswith("[mcu"):
                    # Insert serial line after [mcu] section
                    lines.insert(i + 1, f"serial: {serial_port}")
                    print_colored(f"  ✓ Added serial port to config: {serial_port}", Colors.GREEN)
                    updated = True
                    break
        
        if updated:
            config_file.write_text('\n'.join(lines))
            return True
        
    except Exception as e:
        print_colored(f"  ⚠ Error updating config: {e}", Colors.YELLOW)
        print_colored(f"  → Manual update needed: serial: {serial_port}", Colors.YELLOW)
        return False
    
    return False

def copy_config_file(install_dir: Path, selected_config: Optional[str] = None) -> bool:
    """Copy config file to home directory"""
    home = Path.home()
    printer_cfg = home / "printer.cfg"
    
    print_colored("Step 8.5: Setting up printer config...", Colors.GREEN)
    
    # Determine which config to use
    config_source = None
    
    if selected_config:
        config_source = install_dir / "config" / selected_config
        if config_source.exists():
            print_colored(f"  → Using selected config: {selected_config}", Colors.BLUE)
        else:
            config_source = None
    
    if not config_source:
        # Try default config
        default_config = install_dir / "config" / "generic-bigtreetech-manta-m8p-V1_1.cfg"
        if default_config.exists():
            config_source = default_config
            print_colored("  → Using default config: generic-bigtreetech-manta-m8p-V1_1.cfg", Colors.BLUE)
    
    if not config_source or not config_source.exists():
        print_colored("  ⚠ No config file found", Colors.YELLOW)
        print_colored(f"  → Available configs in: {install_dir / 'config'}", Colors.YELLOW)
        return False
    
    # Copy config file
    try:
        shutil.copy(config_source, printer_cfg)
        print_colored(f"  ✓ Copied config → {printer_cfg}", Colors.GREEN)
        
        # Update serial port
        if update_serial_port(printer_cfg):
            print_colored(f"  ✓ Config file ready: {printer_cfg}", Colors.GREEN)
            # Show serial port
            content = printer_cfg.read_text()
            for line in content.split('\n'):
                if line.strip().startswith("serial:"):
                    print_colored(f"     Serial port: {line.strip().split(':', 1)[1].strip()}", Colors.BLUE)
                    break
        return True
        
    except Exception as e:
        print_colored(f"  ✗ Error copying config: {e}", Colors.RED)
        return False

def build_firmware(klipper_dir: Path, mcu_type: str) -> Optional[Path]:
    """Build firmware"""
    print_colored("\nStep 9: Building firmware...", Colors.GREEN)
    
    config_file = klipper_dir / ".config"
    if not config_file.exists():
        print_colored("  ✗ No .config file found!", Colors.RED)
        print_colored("  → Run: cd ~/klipper && make menuconfig", Colors.YELLOW)
        return None
    
    print_colored(f"  → Building firmware for {mcu_type}...", Colors.BLUE)
    
    try:
        # Get CPU count for parallel build
        import multiprocessing
        jobs = multiprocessing.cpu_count()
        
        # Build with output visible (not captured) so user can see errors
        print_colored("  → Running make...", Colors.BLUE)
        result = run_command(
            ["make", f"-j{jobs}"],
            cwd=klipper_dir,
            capture_output=False,  # Show output so user can see errors
            check=False
        )
        
        firmware_file = klipper_dir / "out" / "klipper.bin"
        
        if result.returncode == 0:
            if firmware_file.exists():
                size_bytes = firmware_file.stat().st_size
                if size_bytes == 0:
                    print_colored("  ✗ Firmware file is empty (0 bytes)!", Colors.RED)
                    print_colored("  → Build may have failed silently", Colors.YELLOW)
                    print_colored("  → Check build output above for errors", Colors.YELLOW)
                    return None
                
                # Show size in KB if < 1MB, otherwise MB
                if size_bytes < 1024 * 1024:
                    size_kb = size_bytes / 1024
                    print_colored("  ✓ Firmware built successfully!", Colors.GREEN)
                    print_colored(f"  → Firmware: {firmware_file} ({size_kb:.1f} KB)", Colors.BLUE)
                else:
                    size_mb = size_bytes / (1024 * 1024)
                    print_colored("  ✓ Firmware built successfully!", Colors.GREEN)
                    print_colored(f"  → Firmware: {firmware_file} ({size_mb:.1f} MB)", Colors.BLUE)
                return firmware_file
            else:
                print_colored("  ✗ Firmware file not found at expected location", Colors.RED)
                print_colored(f"  → Expected: {firmware_file}", Colors.YELLOW)
                print_colored("  → Build may have failed - check output above", Colors.YELLOW)
                return None
        else:
            print_colored("  ✗ Firmware build failed!", Colors.RED)
            print_colored(f"  → Return code: {result.returncode}", Colors.YELLOW)
            print_colored("  → Check build output above for errors", Colors.YELLOW)
            return None
            
    except Exception as e:
        print_colored(f"  ✗ Build error: {e}", Colors.RED)
        import traceback
        print_colored(f"  → Traceback: {traceback.format_exc()}", Colors.YELLOW)
        return None

def flash_firmware_interactive(firmware_file: Path, mcu_type: str, klipper_dir: Path, non_interactive: bool):
    """Interactive firmware flashing"""
    if not firmware_file.exists():
        print_colored(f"  ✗ Firmware file not found: {firmware_file}", Colors.RED)
        return
    
    print_colored("\nStep 10: Flashing firmware...", Colors.GREEN)
    print(f"\nFirmware ready: {firmware_file}")
    print(f"MCU Type: {mcu_type}\n")
    
    if non_interactive:
        print_colored("  → Skipping flash (non-interactive mode)", Colors.YELLOW)
        print_colored(f"  → Firmware saved at: {firmware_file}", Colors.BLUE)
        return
    
    print("Flashing methods:")
    print("  1) SD Card (Recommended for STM32 - most reliable)")
    print("  2) USB/DFU (STM32 bootloader mode)")
    print("  3) ST-Link (Hardware programmer)")
    print("  4) USB Serial (RP2040 - hold BOOTSEL button)")
    print("  5) Skip flashing (do it manually later)")
    print()
    
    try:
        choice = input("Select flashing method [1-5]: ").strip()
        
        if choice == "1":
            flash_via_sd_card(firmware_file, mcu_type)
        elif choice == "2":
            flash_via_dfu(firmware_file, mcu_type, klipper_dir)
        elif choice == "3":
            flash_via_stlink(firmware_file, mcu_type)
        elif choice == "4":
            flash_via_usb_serial(firmware_file, mcu_type, klipper_dir)
        elif choice == "5":
            print_colored("  → Skipping flash", Colors.YELLOW)
            show_flash_instructions(firmware_file, mcu_type)
        else:
            print_colored("  ⚠ Invalid selection, skipping flash", Colors.YELLOW)
            show_flash_instructions(firmware_file, mcu_type)
    except KeyboardInterrupt:
        print_colored("\n  → Flash cancelled", Colors.YELLOW)
        show_flash_instructions(firmware_file, mcu_type)

def detect_sd_card() -> Optional[Path]:
    """Detect mounted SD card"""
    try:
        result = run_command(["lsblk", "-o", "NAME,TYPE,MOUNTPOINT"], capture_output=True)
        lines = result.stdout.split('\n')
        
        for line in lines[1:]:  # Skip header
            if not line.strip():
                continue
            parts = line.split()
            if len(parts) >= 3:
                name = parts[0]
                dev_type = parts[1]
                mount = parts[2] if len(parts) > 2 else ""
                
                # Look for mmcblk (SD card) that's mounted
                if "mmcblk" in name and dev_type == "disk":
                    # Find mounted partition
                    for part_line in lines:
                        if name in part_line and "part" in part_line:
                            part_parts = part_line.split()
                            if len(part_parts) >= 3 and part_parts[2] != "":
                                mount_point = Path(part_parts[2])
                                if mount_point.exists() and mount_point.is_dir():
                                    return mount_point
    except:
        pass
    
    # Also check common mount points
    common_mounts = [Path("/media"), Path("/mnt"), Path("/run/media")]
    for base in common_mounts:
        if base.exists():
            for item in base.iterdir():
                if item.is_dir() and item.is_mount():
                    return item
    
    return None

def copy_firmware_to_downloads(firmware_file: Path) -> Optional[Path]:
    """Copy firmware to Downloads folder for manual transfer"""
    downloads = Path.home() / "Downloads"
    downloads.mkdir(exist_ok=True)
    
    # Create a descriptive filename
    firmware_name = f"klipper-firmware-{firmware_file.stat().st_mtime:.0f}.bin"
    dest_file = downloads / firmware_name
    
    try:
        shutil.copy(firmware_file, dest_file)
        print_colored(f"  ✓ Copied firmware to: {dest_file}", Colors.GREEN)
        return dest_file
    except Exception as e:
        print_colored(f"  ✗ Error copying firmware: {e}", Colors.RED)
        return None

def flash_via_sd_card(firmware_file: Path, mcu_type: str):
    """Flash via SD card"""
    print_colored("\nSD Card Flashing (STM32)", Colors.BLUE)
    print("\nSteps:")
    print("  1. Copy firmware.bin to SD card root")
    print("  2. Rename to: FIRMWARE.bin (uppercase)")
    print("  3. Insert SD card into board")
    print("  4. Power cycle board\n")
    
    # Detect SD card
    sd_mount = detect_sd_card()
    
    if sd_mount:
        print_colored(f"  ✓ Detected SD card mounted at: {sd_mount}", Colors.GREEN)
        response = input("Copy firmware to SD card now? [Y/n]: ")
        if response.lower() != 'n':
            try:
                dest_file = sd_mount / "FIRMWARE.bin"
                shutil.copy(firmware_file, dest_file)
                print_colored(f"  ✓ Copied firmware to SD card: {dest_file}", Colors.GREEN)
                print_colored("\nNext steps:", Colors.BLUE)
                print("  1. Safely eject SD card")
                print("  2. Insert SD card into board")
                print("  3. Power cycle board")
                print("  4. Wait for firmware to flash (LED will blink)")
                return
            except Exception as e:
                print_colored(f"  ✗ Error copying to SD card: {e}", Colors.RED)
                print_colored("  → Try copying manually", Colors.YELLOW)
    else:
        print_colored("  ⚠ SD card not detected or not mounted", Colors.YELLOW)
    
    # Offer to copy to Downloads folder
    print_colored("\nOptions:", Colors.BLUE)
    print("  1) Copy firmware to Downloads folder (for manual SD card copy)")
    print("  2) Skip (copy manually later)")
    response = input("Select option [1-2]: ")
    
    if response == "1":
        downloads_file = copy_firmware_to_downloads(firmware_file)
        if downloads_file:
            print_colored(f"\n  → Copy {downloads_file.name} to SD card manually", Colors.BLUE)
            print_colored("  → Rename to FIRMWARE.bin (uppercase) on SD card", Colors.BLUE)
    else:
        print_colored(f"\nManual SD card flash:", Colors.BLUE)
        print_colored(f"  cp {firmware_file} /path/to/sd/FIRMWARE.bin", Colors.BLUE)

def flash_via_dfu(firmware_file: Path, mcu_type: str, klipper_dir: Path):
    """Flash via DFU - detects DFU mode or uses make flash"""
    print_colored("\nDFU Flashing (STM32 Bootloader)", Colors.BLUE)
    
    # Check if board is already in DFU mode
    result = run_command(["lsusb"], capture_output=True, check=False)
    in_dfu_mode = "0483:df11" in result.stdout or "STM Device in DFU Mode" in result.stdout
    
    if in_dfu_mode:
        print_colored("  ✓ Board detected in DFU mode!", Colors.GREEN)
        print_colored("  → Using dfu-util directly\n", Colors.BLUE)
        
        input("Press Enter to start flashing (or Ctrl+C to cancel)...")
        
        try:
            # Use dfu-util directly (board already in DFU mode)
            print_colored("  → Flashing firmware via dfu-util...", Colors.BLUE)
            print()  # Blank line before output
            result = run_command(
                ["dfu-util", "-a", "0", "-D", str(firmware_file), "--dfuse-address", "0x08002000"],
                capture_output=False,  # Show output so user can see progress
                check=False
            )
            print()  # Blank line after output
            
            # Check return code and common success patterns
            # Note: dfu-util may return non-zero even on success due to leave request error
            if result.returncode == 0:
                print_colored("  ✓ Firmware flashed successfully!", Colors.GREEN)
            else:
                # Check if it's just the leave request error (firmware still flashed)
                # We can't check output here since capture_output=False, but we know
                # from experience that non-zero often means success with leave error
                print_colored("  ⚠ dfu-util returned error code, but firmware may still be flashed", Colors.YELLOW)
                print_colored("  → Check output above for 'File downloaded successfully'", Colors.BLUE)
                print_colored("  → If you see 'Download done' or 'File downloaded successfully', flash was successful!", Colors.GREEN)
                print_colored("  → 'Error during download get_status' during leave is normal and harmless", Colors.BLUE)
            
            # Always remind user to power cycle
            print()
            print_colored("  ⚠ IMPORTANT: Power cycle the board to exit DFU mode!", Colors.YELLOW)
            print_colored("  → Unplug USB/power, wait 2-3 seconds, then plug back in", Colors.BLUE)
            print_colored("  → Board will boot into Klipper firmware after power cycle", Colors.BLUE)
        except Exception as e:
            print_colored(f"  ✗ Flash error: {e}", Colors.RED)
            print_colored("  → Try SD card method instead", Colors.YELLOW)
    else:
        # Board not in DFU mode - use make flash to enter bootloader
        print("\nThis uses 'make flash' which automatically enters bootloader mode")
        print("  - No need to manually enter bootloader!")
        print("  - Klipper will send bootloader command via serial\n")
        
        serial_path = Path("/dev/serial/by-id")
        serial_port = None
        if serial_path.exists():
            for port in serial_path.iterdir():
                if "Klipper" in port.name or "stm32" in port.name.lower():
                    serial_port = str(port)
                    break
        
        if serial_port:
            print_colored(f"Found serial port: {serial_port}", Colors.GREEN)
            print_colored("  → Using: make flash FLASH_DEVICE=...", Colors.BLUE)
            print_colored("  → This will automatically enter bootloader mode\n", Colors.BLUE)
            
            input("Press Enter to start flashing (or Ctrl+C to cancel)...")
            
            try:
                print_colored("  → Entering bootloader mode...", Colors.BLUE)
                # Use make flash which handles bootloader entry automatically
                result = run_command(
                    ["make", "flash", f"FLASH_DEVICE={serial_port}"],
                    cwd=klipper_dir,
                    capture_output=True,
                    check=False
                )
                
                # Check output for success indicators
                output = result.stdout + result.stderr
                if "File downloaded successfully" in output or "Download done" in output:
                    print_colored("  ✓ Firmware flashed successfully!", Colors.GREEN)
                    print_colored("  → Firmware downloaded and written to MCU", Colors.BLUE)
                    if "Error during download get_status" in output:
                        print_colored("  → (Minor status check error - firmware was still flashed)", Colors.YELLOW)
                elif result.returncode == 0:
                    print_colored("  ✓ Firmware flash completed!", Colors.GREEN)
                else:
                    print_colored("  ⚠ Flash may have failed - check output above", Colors.YELLOW)
                    print_colored("  → If firmware was downloaded, it should still work", Colors.BLUE)
                    print_colored("  → Try SD card method if unsure", Colors.YELLOW)
                
                # Remind user to power cycle if flash was successful
                if "File downloaded successfully" in output or "Download done" in output or result.returncode == 0:
                    print()
                    print_colored("  ⚠ IMPORTANT: Power cycle the board to exit bootloader mode!", Colors.YELLOW)
                    print_colored("  → Unplug USB/power, wait 2-3 seconds, then plug back in", Colors.BLUE)
                    print_colored("  → Board will boot into Klipper firmware after power cycle", Colors.BLUE)
            except Exception as e:
                print_colored(f"  ✗ Flash error: {e}", Colors.RED)
                print_colored("  → Try SD card method instead", Colors.YELLOW)
        else:
            print_colored("  ⚠ Serial port not found", Colors.YELLOW)
            print_colored("  → Connect board and try again", Colors.YELLOW)
            print_colored("  → Or use SD card method", Colors.YELLOW)

def flash_via_stlink(firmware_file: Path, mcu_type: str):
    """Flash via ST-Link"""
    print_colored("\nST-Link Flashing", Colors.BLUE)
    print("\nST-Link hardware programmer required\n")
    
    if shutil.which("st-flash"):
        print_colored("  → st-flash found", Colors.GREEN)
        print_colored("  → Flashing to address 0x8002000 (8KiB bootloader)...", Colors.BLUE)
        run_command(["sudo", "st-flash", "--reset", "write", str(firmware_file), "0x8002000"])
        print_colored("  ✓ Firmware flashed successfully!", Colors.GREEN)
    else:
        print_colored("  ⚠ st-flash not installed", Colors.YELLOW)
        print_colored("  → Install: sudo apt install stlink-tools", Colors.YELLOW)
        print_colored("  → Or use SD card method", Colors.YELLOW)

def flash_via_usb_serial(firmware_file: Path, mcu_type: str, klipper_dir: Path):
    """Flash via USB Serial (RP2040)"""
    print_colored("\nUSB Serial Flashing (RP2040)", Colors.BLUE)
    print("\nRP2040 bootloader mode:")
    print("  1. Hold BOOTSEL button")
    print("  2. Connect USB cable")
    print("  3. Release BOOTSEL button\n")
    
    input("Enter bootloader mode now, then press Enter...")
    
    result = run_command(["lsusb"], capture_output=True)
    if "2e8a:0003" in result.stdout:
        print_colored("  ✓ RP2040 bootloader detected", Colors.GREEN)
        flash_script = klipper_dir / "lib" / "rp2040_flash" / "flash_usb.py"
        if flash_script.exists():
            run_command(["python3", str(flash_script), str(firmware_file)], cwd=klipper_dir)
            print_colored("  ✓ Firmware flashed successfully!", Colors.GREEN)
        else:
            print_colored("  ✗ Flash script not found", Colors.RED)
    else:
        print_colored("  ⚠ RP2040 bootloader not detected", Colors.YELLOW)
        print_colored("  → Make sure board is in bootloader mode", Colors.YELLOW)

def show_flash_instructions(firmware_file: Path, mcu_type: str):
    """Show manual flash instructions"""
    print_colored("\nManual Flash Instructions:", Colors.BLUE)
    print(f"\nFirmware location: {firmware_file}\n")
    
    if "STM32" in mcu_type:
        print("STM32 Flashing:")
        print(f"  SD Card: cp {firmware_file} /path/to/sd/FIRMWARE.bin")
        print("  DFU: make flash FLASH_DEVICE=/dev/serial/by-id/...")
        print(f"  ST-Link: sudo st-flash write {firmware_file} 0x8002000")
        print()
        print_colored("  ⚠ IMPORTANT: After flashing, power cycle the board!", Colors.YELLOW)
        print_colored("  → Unplug USB/power, wait 2-3 seconds, then plug back in", Colors.BLUE)
        print_colored("  → Board will boot into Klipper firmware after power cycle", Colors.BLUE)
    elif "RP2040" in mcu_type or "RP2350" in mcu_type:
        print("RP2040/RP2350 Flashing:")
        print(f"  USB: python3 ~/klipper/lib/rp2040_flash/flash_usb.py {firmware_file}")
        print("  (Hold BOOTSEL button while connecting USB)")
        print()
        print_colored("  ⚠ IMPORTANT: After flashing, power cycle the board!", Colors.YELLOW)
        print_colored("  → Unplug USB/power, wait 2-3 seconds, then plug back in", Colors.BLUE)
    print()

def flash_only_mode(klipper_dir: Path):
    """Flash-only mode: find firmware and flash it"""
    print_colored("=" * 40, Colors.BLUE)
    print_colored("Firmware Flash Only Mode", Colors.BLUE)
    print_colored("=" * 40, Colors.BLUE)
    
    # Find firmware file
    firmware_file = klipper_dir / "out" / "klipper.bin"
    
    if not firmware_file.exists():
        # Check Downloads folder
        downloads = Path.home() / "Downloads"
        firmware_files = list(downloads.glob("klipper-firmware-*.bin"))
        if firmware_files:
            firmware_file = max(firmware_files, key=lambda p: p.stat().st_mtime)
            print_colored(f"Found firmware in Downloads: {firmware_file.name}", Colors.GREEN)
        else:
            print_colored("  ✗ Firmware file not found!", Colors.RED)
            print_colored(f"  → Expected: {klipper_dir / 'out' / 'klipper.bin'}", Colors.YELLOW)
            print_colored("  → Or in Downloads folder", Colors.YELLOW)
            sys.exit(1)
    
    # Detect MCU type
    mcu_type = detect_mcu_from_usb()
    if not mcu_type:
        mcu_type = "STM32G0B1"  # Default
    
    print_colored(f"\nFirmware: {firmware_file}", Colors.GREEN)
    print_colored(f"MCU Type: {mcu_type}\n", Colors.BLUE)
    
    flash_firmware_interactive(firmware_file, mcu_type, klipper_dir, False)

def main():
    parser = argparse.ArgumentParser(description="Complete CM4 Setup Script (Python)")
    parser.add_argument("--mcu", default="AUTO", help="MCU type: STM32G0B1, RP2040, AUTO (default: AUTO)")
    parser.add_argument("--non-interactive", action="store_true", help="Skip all prompts")
    parser.add_argument("--skip-upgrade", action="store_true", help="Skip system package upgrade")
    parser.add_argument("--flash", action="store_true", help="Flash-only mode: find and flash existing firmware")
    args = parser.parse_args()
    
    # Flash-only mode
    if args.flash:
        klipper_dir = Path.home() / "klipper"
        flash_only_mode(klipper_dir)
        return
    
    # Setup paths
    klipper_dir = Path.home() / "klipper"
    install_dir = Path(__file__).parent.resolve()
    log_file = Path.home() / "klipper-install-setup.log"
    
    print_colored("=" * 40, Colors.BLUE)
    print_colored("Complete CM4 Setup (Python)", Colors.BLUE)
    print_colored("=" * 40, Colors.BLUE)
    print(f"\nInstall log: {log_file}\n")
    
    if not args.non_interactive:
        response = input("Continue? [y/N]: ")
        if response.lower() != 'y':
            print("Cancelled.")
            sys.exit(0)
    
    # Step 7: Configure build
    print_colored("\nStep 7: Configuring build...", Colors.GREEN)
    
    # Determine MCU type
    mcu_type = args.mcu.upper() if args.mcu.upper() != "AUTO" else None
    
    if not mcu_type:
        mcu_type = detect_mcu_from_usb()
    
    print_colored(f"MCU Type: {mcu_type}", Colors.BLUE)
    
    # Apply preset
    if apply_mcu_preset(mcu_type, klipper_dir, install_dir):
        print_colored(f"  ✓ MCU preset applied: {mcu_type}", Colors.GREEN)
        if not args.non_interactive:
            input("\nPress Enter to open menuconfig (or Ctrl+C to skip)...")
            run_command(["make", "menuconfig"], cwd=klipper_dir)
    else:
        print_colored("  ⚠ Preset not available, opening menuconfig...", Colors.YELLOW)
        if not args.non_interactive:
            run_command(["make", "menuconfig"], cwd=klipper_dir)
        else:
            print_colored("  ✗ Cannot proceed without menuconfig in non-interactive mode", Colors.RED)
            sys.exit(1)
    
    print_colored("  ✓ Configuration saved", Colors.GREEN)
    
    # Copy config file
    copy_config_file(install_dir)
    
    # Build firmware
    firmware_file = None
    if not args.non_interactive:
        response = input("\nBuild firmware now? [Y/n]: ")
        if response.lower() != 'n':
            firmware_file = build_firmware(klipper_dir, mcu_type)
            
            if firmware_file:
                response = input("\nFlash firmware now? [y/N]: ")
                if response.lower() == 'y':
                    flash_firmware_interactive(firmware_file, mcu_type, klipper_dir, args.non_interactive)
                else:
                    show_flash_instructions(firmware_file, mcu_type)
        else:
            print_colored("\nSkipping firmware build", Colors.YELLOW)
            print_colored("Build later: cd ~/klipper && make", Colors.BLUE)
    else:
        print_colored("\nSkipping firmware build (non-interactive mode)", Colors.BLUE)
        print_colored("Build later: cd ~/klipper && make", Colors.BLUE)
    
    print_colored("\n" + "=" * 40, Colors.BLUE)
    print_colored("Setup Complete!", Colors.GREEN)
    print_colored("=" * 40, Colors.BLUE)
    print(f"\nMCU Configuration: {mcu_type}\n")
    print("Next steps:")
    if firmware_file:
        print(f"  1. ✓ Firmware built: {firmware_file}")
        print("  2. Flash firmware to MCU (if not done)")
    else:
        print("  1. Build firmware: cd ~/klipper && make")
        print("  2. Flash firmware to MCU")
    printer_cfg = Path.home() / "printer.cfg"
    if printer_cfg.exists():
        print(f"  3. ✓ Config file ready: {printer_cfg}")
    else:
        print("  3. Copy config: cp ~/klipper-install/config/generic-bigtreetech-manta-m8p-V1_1.cfg ~/printer.cfg")
    print("  4. Start service: sudo systemctl start klipper\n")

if __name__ == "__main__":
    main()
