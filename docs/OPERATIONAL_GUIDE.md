# CNC PICKUP WINDER - OPERATIONAL GUIDE
# Following the System Flowchart

## PHASE 1: SYSTEM BRING-UP
### Step 1: Hardware Assembly
- Mount Pico 2 on CNC winder
- Connect BLDC spindle motor (U,V,W phases + Hall sensors A,B,C)
- Connect stepper motors (traverse + pickup)
- Connect endstops and emergency stop button
- Connect CM4 with touchscreen
- Verify all power supplies

### Step 2: Firmware Programming
```bash
# Build and flash Pico firmware
./build.sh
cp out/klipper.uf2 /media/YOUR_USER/RPI-RP2/
```

### Step 3: Host Software Setup
```bash
# On CM4
./setup_cnc_winder.sh
# Access web interface at http://cm4-ip
```

## PHASE 2: SYSTEM INITIALIZATION
### Step 4: Power-On Sequence
1. **CM4 boots Linux** (30-60 seconds)
2. **Firmware host service starts** (connects to Pico)
3. **Web interface loads** (shows connection status)
4. **Pico firmware initializes** (GPIO, timers, interrupts)

### Step 5: Configuration
- **Web interface**: Load `cnc_winder_config.cfg`
- **Pico responds**: `cnc_winder_configured pins=...`
- **System enters**: SYSTEM_READY state

## PHASE 3: HOMING & CALIBRATION
### Step 6: Homing Sequence
1. **Press 'HOME_ALL'** in the web interface
2. **Traverse moves** to endstop (crash prevention)
3. **Pickup positions** to safe location
4. **BLDC spindle** zeros RPM counter
5. **System enters**: HOMING_COMPLETE state

### Step 7: Verification
- **Check positions**: All motors at expected locations
- **Verify limits**: Soft limits active
- **Test emergency**: Stop button functional

## PHASE 4: WINDING OPERATION
### Step 8: Setup Winding Job
1. **Enter parameters**: Turns (2500-10000), RPM (1000-2000)
2. **System validates**: Parameters within limits
3. **Calculate targets**: Layer positions, acceleration curves

### Step 9: Execute Winding
1. **Start command**: `start_winding TURNS=5000 RPM=1500`
2. **BLDC ramps up**: PID controlled acceleration
3. **Traverse begins**: Synchronized wire laying
4. **Turn counting**: Real-time progress tracking

### Step 10: Real-Time Monitoring
- **RPM display**: Target vs measured
- **Position feedback**: Traverse and pickup positions
- **Turn counter**: Progress toward target
- **Layer indicator**: Current winding layer
- **Safety status**: Emergency stop readiness

### Step 11: Completion
- **Target reached**: Automatic deceleration
- **Motors stop**: Controlled shutdown
- **Stats logged**: Turns completed, time elapsed
- **Ready for next**: Return to HOMING_COMPLETE

## PHASE 5: MAINTENANCE & DIAGNOSTICS
### Step 12: Regular Checks
- **Temperature monitoring**: Motor and driver temps
- **Position accuracy**: Encoder vs commanded positions
- **Communication health**: USB connection status
- **Emergency systems**: Button and circuitry tests

### Step 13: Error Recovery
- **Emergency stop**: Immediate shutdown, position logging
- **Homing recovery**: Recalibrate after faults
- **Parameter adjustment**: Tune PID, speeds, limits
- **Firmware updates**: Rebuild and reflash as needed

## PHASE 6: SHUTDOWN PROCEDURES
### Step 14: Controlled Shutdown
1. **Stop active operations**: Complete current actions
2. **Home motors**: Return to known positions
3. **Disable drivers**: Power down safely
4. **Save data**: Log final statistics
5. **Service shutdown**: Clean Klipper/Mainsail exit

## TROUBLESHOOTING BY STATE

### If stuck in BOOTING:
- Check Pico firmware flashed correctly
- Verify USB connection between CM4 and Pico
- Check Klipper service status: `sudo systemctl status klipper`

### If SYSTEM_READY not reached:
- Verify `config_cnc_winder` command executed
- Check pin assignments in `cnc_winder_config.h`
- Confirm all hardware connections

### If homing fails:
- Check endstop wiring and functionality
- Verify stepper motor directions
- Adjust homing speeds in configuration

### If winding unstable:
- Tune PID constants in `cnc_winder_config.h`
- Check Hall sensor connections
- Verify motor phase wiring
- Adjust acceleration profiles

### If communication lost:
- Check USB cable integrity
- Restart Klipper service
- Verify Pico firmware responsiveness

## PERFORMANCE OPTIMIZATION

### Speed Tuning:
- Increase HALL_SENSOR_POLL_US for lower latency (minimum 50µs)
- Adjust PID constants for faster response
- Optimize stepper interrupt priorities

### Accuracy Tuning:
- Calibrate steps/mm ratios
- Fine-tune encoder counts
- Adjust soft limit margins

### Safety Tuning:
- Set appropriate current limits
- Configure temperature thresholds
- Adjust emergency stop debounce

## DEVELOPMENT WORKFLOW

### Code Changes:
1. **Edit source**: `src/custom_stepper.c` or `src/cnc_winder_config.h`
2. **Build firmware**: `./build.sh`
3. **Flash Pico**: `cp out/klipper.uf2 /media/RPI-RP2/`
4. **Test changes**: Use Mainsail interface
5. **Iterate**: Based on test results

### Configuration Changes:
1. **Edit config**: `cnc_winder_config.cfg` or `cnc_winder_config.h`
2. **Restart services**: `sudo systemctl restart klipper`
3. **Test parameters**: Through Mainsail UI

This operational guide follows the complete system flowchart, ensuring you understand every state and transition in your CNC pickup winder system.

