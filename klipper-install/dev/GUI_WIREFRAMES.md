# Winder GUI Wireframes

## Screen 1: Main Control (Default)

```
┌─────────────────────────────────────────────────────────┐
│  CNC Guitar Pickup Winder                    [⚙ Settings]│
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌────────────────────┐    ┌────────────────────┐      │
│  │   Spindle RPM      │    │   Angle Position   │      │
│  │                    │    │                    │      │
│  │      1000         │    │      45.2°         │      │
│  │      RPM           │    │                    │      │
│  │                    │    │    [████░░░░]      │      │
│  │   [████████░░]     │    │                    │      │
│  │                    │    │   Target: 1000     │      │
│  └────────────────────┘    └────────────────────┘      │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Winding Progress                                │   │
│  │                                                  │   │
│  │  Layer:  3 / 5                                   │   │
│  │  Turns:  2,450 / 5,000                          │   │
│  │  Wire:   125.3 m                                │   │
│  │  Time:   00:02:15                               │   │
│  │                                                  │   │
│  │  [████████████████░░░░░░░░]  49%                │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Traverse Position                               │   │
│  │  45.2 mm / 93.0 mm                              │   │
│  │  [████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░]  │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │              │  │              │  │              │ │
│  │    START     │  │    PAUSE     │  │     STOP     │ │
│  │              │  │              │  │              │ │
│  │   [████]     │  │   [░░░░]     │  │   [░░░░]     │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
│                                                          │
│  [Setup] [History] [Diagnostics] [Help]                 │
└─────────────────────────────────────────────────────────┘
```

## Screen 2: Setup & Configuration

```
┌─────────────────────────────────────────────────────────┐
│  Setup & Configuration                        [← Back]   │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Winding Parameters                             │   │
│  │                                                  │   │
│  │  Target RPM:     [1000]  RPM                    │   │
│  │  Layers:         [  5  ]                        │   │
│  │  Target Turns:   [5000]                         │   │
│  │                                                  │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Bobbin Configuration                            │   │
│  │                                                  │   │
│  │  Width:         [12.0] mm                        │   │
│  │  Wire Gauge:    [43 AWG] ▼                      │   │
│  │  Wire Diameter: [0.056] mm                      │   │
│  │                                                  │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Motor Settings                                  │   │
│  │                                                  │   │
│  │  Max RPM:       [3000]                          │   │
│  │  Min RPM:       [  10]                          │   │
│  │  Gear Ratio:    [0.667] (40:60)                 │   │
│  │                                                  │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │   Home       │  │    Save      │  │    Load      │ │
│  │  Traverse    │  │   Profile    │  │   Profile    │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────┘
```

## Screen 3: Job History

```
┌─────────────────────────────────────────────────────────┐
│  Job History                                  [← Back]   │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Recent Jobs                                     │   │
│  │                                                  │   │
│  │  ┌──────────────────────────────────────────┐  │   │
│  │  │ Job #1 - Humbucker                        │  │   │
│  │  │ 5,000 turns | 125.3 m | 00:05:23          │  │   │
│  │  │ [Load] [Delete]                            │  │   │
│  │  └──────────────────────────────────────────┘  │   │
│  │                                                  │   │
│  │  ┌──────────────────────────────────────────┐  │   │
│  │  │ Job #2 - Single Coil                      │  │   │
│  │  │ 2,500 turns | 62.1 m | 00:02:45          │  │   │
│  │  │ [Load] [Delete]                            │  │   │
│  │  └──────────────────────────────────────────┘  │   │
│  │                                                  │   │
│  │  ┌──────────────────────────────────────────┐  │   │
│  │  │ Job #3 - P90                              │  │   │
│  │  │ 8,000 turns | 200.5 m | 00:08:12         │  │   │
│  │  │ [Load] [Delete]                            │  │   │
│  │  └──────────────────────────────────────────┘  │   │
│  │                                                  │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐                   │
│  │   New Job    │  │   Statistics │                   │
│  └──────────────┘  └──────────────┘                   │
└─────────────────────────────────────────────────────────┘
```

## Screen 4: Diagnostics

```
┌─────────────────────────────────────────────────────────┐
│  Diagnostics                                   [← Back]  │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │  System Status                                   │   │
│  │                                                  │   │
│  │  MCU:        [●] Connected                       │   │
│  │  Klipper:    [●] Ready                           │   │
│  │  Moonraker:  [●] Running                         │   │
│  │                                                  │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Sensor Status                                    │   │
│  │                                                  │   │
│  │  BLDC Motor:      [●] Running                    │   │
│  │  Angle Sensor:    [●] Active                      │   │
│  │  Hall Sensor:     [●] Active                      │   │
│  │  Traverse:        [●] Homed                      │   │
│  │                                                  │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │   Motor      │  │   Sensor     │  │   Traverse   │ │
│  │   Test       │  │   Test       │  │   Test       │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐                   │
│  │   Calibrate  │  │   Logs       │                   │
│  │   Sensors    │  │              │                   │
│  └──────────────┘  └──────────────┘                   │
└─────────────────────────────────────────────────────────┘
```

## Screen 5: Settings

```
┌─────────────────────────────────────────────────────────┐
│  Settings                                      [← Back]  │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Motor Configuration                             │   │
│  │                                                  │   │
│  │  Max RPM:        [3000]                          │   │
│  │  Min RPM:        [  10]                          │   │
│  │  PWM Frequency:  [1000] Hz                       │   │
│  │  Min Duty Cycle: [0.05] (5%)                     │   │
│  │                                                  │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Sensor Configuration                            │   │
│  │                                                  │   │
│  │  Angle Sensor:   [PA1]                            │   │
│  │  Hall Sensor:    [PC15]                          │   │
│  │  Auto Calibrate: [✓] Enabled                     │   │
│  │                                                  │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Traverse Configuration                          │   │
│  │                                                  │   │
│  │  Max Position:   [93.0] mm                        │   │
│  │  Home Offset:    [ 2.0] mm                        │   │
│  │  Max Velocity:   [120] mm/s                       │   │
│  │                                                  │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐                   │
│  │    Save      │  │    Reset     │                   │
│  │  Settings    │  │  to Defaults │                   │
│  └──────────────┘  └──────────────┘                   │
└─────────────────────────────────────────────────────────┘
```

## Component Specifications

### RPM Gauge Widget
- **Type:** Circular gauge or linear bar
- **Range:** 0 - Max RPM (configurable)
- **Update Rate:** Real-time (via WebSocket)
- **Colors:** Green (normal), Yellow (warning), Red (max)

### Progress Bar Widget
- **Type:** Horizontal bar with percentage
- **Display:** Layer progress, Turn progress, Overall progress
- **Update Rate:** Real-time
- **Colors:** Blue (progress), Gray (remaining)

### Status Indicator Widget
- **Type:** LED-style indicator
- **States:** 
  - Green: Running/Normal
  - Yellow: Warning/Paused
  - Red: Error/Stopped
  - Gray: Inactive

### Control Button Widget
- **Size:** Large (minimum 80x80px for touch)
- **States:** Normal, Pressed, Disabled
- **Colors:** 
  - Start: Green
  - Pause: Yellow
  - Stop: Red

### Numeric Input Widget
- **Type:** Virtual keypad or increment/decrement buttons
- **Validation:** Min/max range checking
- **Format:** Decimal support for RPM, integer for layers/turns

## Navigation Flow

```
Main Screen (Default)
    │
    ├─→ Setup Screen
    │   ├─→ Enter Parameters
    │   ├─→ Home Traverse
    │   └─→ Save/Load Profile
    │
    ├─→ History Screen
    │   ├─→ View Past Jobs
    │   ├─→ Load Profile
    │   └─→ View Statistics
    │
    ├─→ Diagnostics Screen
    │   ├─→ Motor Test
    │   ├─→ Sensor Test
    │   ├─→ Traverse Test
    │   └─→ View Logs
    │
    └─→ Settings Screen
        ├─→ Motor Config
        ├─→ Sensor Config
        ├─→ Traverse Config
        └─→ System Settings
```

## Touch Target Guidelines

- **Minimum Size:** 48x48px (for reliable touch)
- **Recommended:** 60x60px or larger
- **Spacing:** Minimum 8px between targets
- **Primary Actions:** Larger (80x80px or more)
- **Emergency Stop:** Extra large, prominent, always visible

## Responsive Considerations

- **Portrait Mode:** Stack widgets vertically
- **Landscape Mode:** Side-by-side layout
- **Small Screens:** Prioritize essential controls
- **Large Screens:** Show more detail, add graphs

