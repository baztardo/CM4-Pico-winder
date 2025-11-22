# Winder GUI Planning Document

## Overview

This document outlines the planning for a custom GUI for the CNC Guitar Pickup Winder. The GUI will provide an intuitive interface for controlling the winder, monitoring status, and managing winding jobs.

## Requirements Analysis

### Core Functionality

1. **Winding Control**
   - Start/stop winding operations
   - Set target RPM
   - Set number of layers
   - Pause/resume winding

2. **Status Monitoring**
   - Real-time spindle RPM (from Hall sensor + angle sensor)
   - Current angle/position
   - Traverse position
   - Turn count
   - Layer progress
   - Wire length

3. **Setup & Configuration**
   - Bobbin selection/configuration
   - Wire gauge selection
   - Target turns input
   - Traverse homing
   - Calibration tools

4. **Job Management**
   - Save/load winding profiles
   - Job history
   - Statistics (turns, wire length, time)

### User Personas

**Primary User: Guitar Builder**
- Needs simple, intuitive interface
- Wants to focus on winding, not troubleshooting
- Needs clear visual feedback
- Wants to save/recall common settings

**Secondary User: Technician**
- Needs diagnostic tools
- Wants detailed status information
- Needs calibration capabilities
- Wants to troubleshoot issues

---

## Technology Options

### Option 1: KlipperScreen Custom Theme (Recommended)

**Pros:**
- ✅ Built on proven KlipperScreen framework
- ✅ Touchscreen optimized
- ✅ Already integrates with Moonraker
- ✅ Python-based (easy to customize)
- ✅ Active community support
- ✅ Can reuse existing components

**Cons:**
- ❌ Limited to KlipperScreen's UI framework
- ❌ Less flexible than custom web app
- ❌ Requires understanding KlipperScreen architecture

**Best For:**
- Touchscreen interface (5" display mentioned in project scope)
- Quick development
- Standard Klipper ecosystem integration

**Architecture:**
```
┌─────────────────┐
│  KlipperScreen  │  (Custom Winder Theme)
│  (Python/Kivy)  │
└────────┬────────┘
         │ HTTP/WebSocket
         │
┌────────▼────────┐
│   Moonraker     │  (API Server)
└────────┬────────┘
         │ Unix Socket
         │
┌────────▼────────┐
│    Klipper      │  (Winder Modules)
└─────────────────┘
```

### Option 2: Web Application (React/Vue)

**Pros:**
- ✅ Full control over UI/UX
- ✅ Modern, responsive design
- ✅ Works on any device (tablet, phone, desktop)
- ✅ Easy to update/deploy
- ✅ Rich ecosystem of UI libraries

**Cons:**
- ❌ More development time
- ❌ Requires web server (Moonraker)
- ❌ More complex deployment

**Best For:**
- Multi-device access
- Custom branding/styling
- Future mobile app

**Architecture:**
```
┌─────────────────┐
│  Web Browser    │  (React/Vue App)
│  (Any Device)   │
└────────┬────────┘
         │ HTTP/WebSocket
         │
┌────────▼────────┐
│   Moonraker     │  (API Server)
└────────┬────────┘
         │ Unix Socket
         │
┌────────▼────────┐
│    Klipper      │  (Winder Modules)
└─────────────────┘
```

### Option 3: Native Python App (Kivy/PyQt)

**Pros:**
- ✅ Full system access
- ✅ Can run standalone
- ✅ Native performance
- ✅ Offline capable

**Cons:**
- ❌ More complex deployment
- ❌ Platform-specific builds
- ❌ Less flexible than web

**Best For:**
- Standalone application
- Advanced system integration
- Offline operation

---

## Recommended Approach: KlipperScreen Custom Theme

**Rationale:**
- Project scope mentions 5" touchscreen
- KlipperScreen is designed for this use case
- Faster development time
- Better integration with Klipper ecosystem
- Can add web interface later if needed

---

## UI/UX Design

### Main Screen Layout

```
┌─────────────────────────────────────────┐
│  CNC Guitar Pickup Winder               │
├─────────────────────────────────────────┤
│                                         │
│  ┌─────────────┐  ┌─────────────┐     │
│  │   Spindle   │  │  Traverse   │     │
│  │   RPM       │  │  Position   │     │
│  │   1000      │  │   45.2 mm   │     │
│  │   ─────     │  │   ─────     │     │
│  │  [████░░]   │  │  [████░░]   │     │
│  └─────────────┘  └─────────────┘     │
│                                         │
│  ┌─────────────────────────────────┐  │
│  │  Winding Progress                │  │
│  │  Layer: 3 / 5                    │  │
│  │  Turns: 2,450 / 5,000           │  │
│  │  Wire Length: 125.3 m            │  │
│  │  [████████████░░░░░░░░] 49%     │  │
│  └─────────────────────────────────┘  │
│                                         │
│  ┌──────┐  ┌──────┐  ┌──────┐        │
│  │ START│  │ PAUSE│  │ STOP │        │
│  └──────┘  └──────┘  └──────┘        │
│                                         │
│  [Setup] [History] [Settings] [Help]   │
└─────────────────────────────────────────┘
```

### Screen Hierarchy

```
Main Screen
├── Winding Control (Default)
│   ├── Status Display
│   ├── Control Buttons
│   └── Quick Settings
│
├── Setup Screen
│   ├── Bobbin Selection
│   ├── Wire Gauge
│   ├── Target Turns
│   └── Traverse Home
│
├── Job Management
│   ├── New Job
│   ├── Load Profile
│   ├── Save Profile
│   └── Job History
│
├── Settings
│   ├── Motor Settings
│   ├── Sensor Calibration
│   ├── Traverse Settings
│   └── System Settings
│
└── Diagnostics
    ├── Motor Test
    ├── Sensor Test
    ├── Traverse Test
    └── System Status
```

---

## Feature List

### Phase 1: Core Winding (MVP)

**Must Have:**
- [x] Start/Stop/Pause controls
- [x] RPM display (real-time)
- [x] Turn count display
- [x] Layer progress
- [x] Traverse position
- [x] Basic status indicators

**Screens:**
1. Main Control Screen
2. Setup Screen (RPM, Layers, Turns)

### Phase 2: Enhanced Monitoring

**Should Have:**
- [ ] Wire length calculation
- [ ] Time elapsed/remaining
- [ ] Angle sensor visualization
- [ ] Traverse visualization
- [ ] Historical graphs (RPM over time)

**Screens:**
1. Enhanced Status Display
2. Real-time Graphs

### Phase 3: Job Management

**Nice to Have:**
- [ ] Save/load profiles
- [ ] Job history
- [ ] Statistics tracking
- [ ] Preset management

**Screens:**
1. Profile Manager
2. Job History
3. Statistics View

### Phase 4: Advanced Features

**Future:**
- [ ] Calibration wizard
- [ ] Diagnostic tools
- [ ] Remote monitoring
- [ ] Multi-bobbin support

**Screens:**
1. Calibration Wizard
2. Diagnostics Panel
3. Remote Access

---

## KlipperScreen Custom Theme Architecture

### File Structure

```
winder-gui/
├── winder_theme/
│   ├── __init__.py
│   ├── panels/
│   │   ├── __init__.py
│   │   ├── main_panel.py          # Main control screen
│   │   ├── setup_panel.py         # Setup/configuration
│   │   ├── status_panel.py        # Status monitoring
│   │   ├── job_panel.py           # Job management
│   │   └── diagnostics_panel.py   # Diagnostic tools
│   │
│   ├── widgets/
│   │   ├── __init__.py
│   │   ├── rpm_display.py         # RPM gauge widget
│   │   ├── progress_bar.py        # Progress visualization
│   │   ├── status_indicator.py    # Status LEDs
│   │   └── control_buttons.py     # Control button group
│   │
│   ├── theme/
│   │   ├── winder.json            # Theme configuration
│   │   └── colors.conf            # Color scheme
│   │
│   └── utils/
│       ├── __init__.py
│       ├── moonraker_client.py   # Moonraker API client
│       └── winder_helpers.py     # Helper functions
│
├── install.sh                      # Installation script
└── README.md
```

### Panel Example: Main Control Panel

```python
# winder_theme/panels/main_panel.py
from ks_includes.screen_panel import ScreenPanel
from ks_includes.KlippyGcodes import KlippyGcodes

class MainPanel(ScreenPanel):
    def __init__(self, screen, title):
        super().__init__(screen, title)
        self.rpm_target = 1000
        self.layers = 5
        self.turns_target = 5000
        
    def initialize(self, panel_name):
        # Create UI elements
        self.rpm_display = self.add_widget("rpm_display", {
            "label": "Spindle RPM",
            "value": 0
        })
        
        self.turn_count = self.add_widget("label", {
            "text": "Turns: 0 / 0"
        })
        
        self.progress_bar = self.add_widget("progress_bar", {
            "value": 0,
            "max": 100
        })
        
        # Control buttons
        self.start_btn = self.add_widget("button", {
            "text": "START",
            "callback": self.start_winding
        })
        
        self.stop_btn = self.add_widget("button", {
            "text": "STOP",
            "callback": self.stop_winding
        })
        
        # Subscribe to status updates
        self.subscribe_status()
    
    def subscribe_status(self):
        # Subscribe to winder objects via Moonraker
        self._screen._ws.send_method(
            "printer.objects.subscribe",
            {
                "objects": {
                    "bldc_motor": None,
                    "angle_sensor": None,
                    "spindle_hall": None,
                    "winder_control": None
                }
            }
        )
    
    def process_update(self, action, data):
        if action == "notify_status_update":
            status = data[0]
            
            # Update RPM display
            if "bldc_motor" in status:
                rpm = status["bldc_motor"].get("current_rpm", 0)
                self.rpm_display.set_value(rpm)
            
            # Update turn count
            if "spindle_hall" in status:
                count = status["spindle_hall"].get("current_count", 0)
                self.turn_count.set_text(f"Turns: {count} / {self.turns_target}")
            
            # Update progress
            if "winder_control" in status:
                winder = status["winder_control"]
                if winder.get("is_winding"):
                    layer = winder.get("current_layer", 0)
                    progress = (layer / self.layers) * 100
                    self.progress_bar.set_value(progress)
    
    def start_winding(self, button):
        # Send WINDER_START command
        self._screen._ws.send_method(
            "printer.gcode.script",
            {
                "script": f"WINDER_START RPM={self.rpm_target} LAYERS={self.layers}"
            }
        )
    
    def stop_winding(self, button):
        self._screen._ws.send_method(
            "printer.gcode.script",
            {"script": "WINDER_STOP"}
        )
```

---

## Moonraker API Integration

### Status Subscription

```python
# Subscribe to winder objects
{
    "jsonrpc": "2.0",
    "method": "printer.objects.subscribe",
    "params": {
        "objects": {
            "bldc_motor": None,
            "angle_sensor": None,
            "spindle_hall": None,
            "traverse": None,
            "winder_control": None
        }
    },
    "id": 5434
}

# Receive updates
{
    "jsonrpc": "2.0",
    "method": "notify_status_update",
    "params": [{
        "bldc_motor": {
            "current_rpm": 1000.0,
            "target_rpm": 1000.0,
            "is_running": true,
            "direction_forward": true,
            "brake_engaged": false,
            "power_on": true
        },
        "angle_sensor": {
            "current_angle_deg": 45.2,
            "measured_rpm": 1000.0,
            "revolutions": 1250,
            "is_saturated": false
        },
        "spindle_hall": {
            "measured_rpm": 1000.0,
            "current_count": 1250,
            "frequency": 16.67
        },
        "traverse": {
            "is_homed": true,
            "current_position": 45.2,
            "max_position": 93.0
        },
        "winder_control": {
            "is_winding": true,
            "current_layer": 3,
            "winding_direction": "Forward",
            "spindle_rpm_target": 1000.0,
            "motor_rpm_target": 1500.0
        }
    }, 1234567890.123]
}
```

### G-code Commands

```python
# Start winding
POST /api/printer/gcode/script
{"script": "WINDER_START RPM=1000 LAYERS=5"}

# Stop winding
POST /api/printer/gcode/script
{"script": "WINDER_STOP"}

# Set RPM
POST /api/printer/gcode/script
{"script": "WINDER_SET_RPM RPM=1500"}

# Home traverse
POST /api/printer/gcode/script
{"script": "TRAVERSE_HOME"}

# Query status
GET /api/printer/objects/query?winder_control&bldc_motor&angle_sensor
```

---

## Implementation Roadmap

### Phase 1: Foundation (Weeks 1-2)

**Tasks:**
1. Set up KlipperScreen development environment
2. Create custom theme structure
3. Implement basic Moonraker client
4. Create main panel skeleton
5. Test status subscription

**Deliverables:**
- Basic theme structure
- Moonraker integration working
- Main panel displays (no controls yet)

### Phase 2: Core Controls (Weeks 3-4)

**Tasks:**
1. Implement start/stop/pause buttons
2. Add RPM display widget
3. Add turn count display
4. Add progress visualization
5. Test with real hardware

**Deliverables:**
- Functional start/stop controls
- Real-time status display
- Basic winding operation

### Phase 3: Setup & Configuration (Weeks 5-6)

**Tasks:**
1. Create setup panel
2. Add RPM input
3. Add layers input
4. Add turns input
5. Add traverse homing

**Deliverables:**
- Complete setup workflow
- Configuration persistence
- User-friendly input forms

### Phase 4: Enhanced Monitoring (Weeks 7-8)

**Tasks:**
1. Add wire length calculation
2. Add time tracking
3. Add visual indicators
4. Add error handling/display
5. Polish UI/UX

**Deliverables:**
- Enhanced status display
- Better visual feedback
- Error handling

### Phase 5: Job Management (Weeks 9-10)

**Tasks:**
1. Implement profile save/load
2. Add job history
3. Add statistics tracking
4. Create job management panel

**Deliverables:**
- Profile management
- Job history
- Statistics view

---

## Design Mockups (Text-Based)

### Main Control Screen

```
╔════════════════════════════════════════════════╗
║  CNC Guitar Pickup Winder          [Settings] ║
╠════════════════════════════════════════════════╣
║                                                ║
║  ┌────────────────────────────────────────┐  ║
║  │  Spindle Status                         │  ║
║  │  ┌──────────┐      ┌──────────┐        │  ║
║  │  │ RPM      │      │ Angle    │        │  ║
║  │  │ 1000     │      │ 45.2°    │        │  ║
║  │  │ [████░░] │      │ [████░░] │        │  ║
║  │  └──────────┘      └──────────┘        │  ║
║  └────────────────────────────────────────┘  ║
║                                                ║
║  ┌────────────────────────────────────────┐  ║
║  │  Winding Progress                       │  ║
║  │  Layer: 3 / 5                          │  ║
║  │  Turns: 2,450 / 5,000                  │  ║
║  │  Wire: 125.3 m                         │  ║
║  │  [████████████░░░░░░░░] 49%            │  ║
║  └────────────────────────────────────────┘  ║
║                                                ║
║  ┌──────────┐  ┌──────────┐  ┌──────────┐   ║
║  │  START   │  │  PAUSE   │  │   STOP   │   ║
║  │  [████]  │  │  [░░░░]  │  │  [░░░░]  │   ║
║  └──────────┘  └──────────┘  └──────────┘   ║
║                                                ║
║  [Setup] [History] [Diagnostics] [Help]      ║
╚════════════════════════════════════════════════╝
```

### Setup Screen

```
╔════════════════════════════════════════════════╗
║  Setup & Configuration            [← Back]     ║
╠════════════════════════════════════════════════╣
║                                                ║
║  ┌────────────────────────────────────────┐  ║
║  │  Winding Parameters                     │  ║
║  │                                          │  ║
║  │  Target RPM:     [1000]  RPM            │  ║
║  │  Layers:         [  5  ]                │  ║
║  │  Target Turns:   [5000]                 │  ║
║  │                                          │  ║
║  └────────────────────────────────────────┘  ║
║                                                ║
║  ┌────────────────────────────────────────┐  ║
║  │  Bobbin Configuration                   │  ║
║  │                                          │  ║
║  │  Width:         [12.0] mm               │  ║
║  │  Wire Gauge:    [43 AWG] ▼             │  ║
║  │                                          │  ║
║  └────────────────────────────────────────┘  ║
║                                                ║
║  ┌──────────┐  ┌──────────┐                 ║
║  │  Home    │  │  Save    │                 ║
║  │ Traverse │  │ Profile  │                 ║
║  └──────────┘  └──────────┘                 ║
╚════════════════════════════════════════════════╝
```

---

## Technical Requirements

### Hardware

- **Display:** 5" Touchscreen (as per project scope)
- **Resolution:** Minimum 800x480 (typical for KlipperScreen)
- **Input:** Touch + optional physical buttons

### Software Dependencies

- **KlipperScreen:** Latest version
- **Moonraker:** Latest version
- **Python:** 3.7+
- **Kivy:** (bundled with KlipperScreen)

### Klipper Modules Required

- `bldc_motor` - Motor control
- `angle_sensor` - Angle measurement
- `spindle_hall` - RPM measurement
- `traverse` - Traverse control
- `winder_control` - Main coordinator

---

## Next Steps

1. **Review & Approve Plan**
   - Review this document
   - Adjust priorities/features
   - Confirm technology choice

2. **Set Up Development Environment**
   - Install KlipperScreen on dev machine
   - Set up Moonraker connection
   - Create theme structure

3. **Create Proof of Concept**
   - Basic panel with status display
   - Test Moonraker integration
   - Verify real-time updates

4. **Iterate**
   - Build one panel at a time
   - Test with hardware
   - Gather user feedback

---

## References

- [KlipperScreen GitHub](https://github.com/KlipperScreen/KlipperScreen)
- [KlipperScreen Documentation](https://klipperscreen.readthedocs.io/)
- [Moonraker API Documentation](https://moonraker.readthedocs.io/)
- [Kivy Documentation](https://kivy.org/doc/stable/)

