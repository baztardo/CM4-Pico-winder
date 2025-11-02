# CNC PICKUP WINDER - SIMPLIFIED STATE FLOW

┌─────────────────┐
│   POWER ON      │
└─────────┬───────┘
          │
          ▼
┌─────────────────┐     ┌─────────────────┐
│   BOOTING       │────▶│   INIT DONE     │
│ • RP2350 reset  │     │ • Pins config   │
│ • CM4 Linux     │     │ • Motors ready  │
│ • Services up   │     │ • USB connected │
└─────────────────┘     └─────────┬───────┘
                                  │
                                  ▼
                         ┌─────────────────┐
                         │  SYSTEM READY   │ ◄─────────────────┐
                         │ • Motors idle   │                   │
                         │ • Homed = NO    │                   │
                         │ • Safe state    │                   │
                         └─────────┬───────┘                   │
                                   │                           │
                                   ▼                           │
                         ┌─────────────────┐                   │
                         │ HOMING SEQUENCE │                   │
                         │ • Find endstops │                   │
                         │ • Zero positions│                   │
                         │ • Set limits    │                   │
                         └─────────┬───────┘                   │
                                   │                           │
                                   ▼                           │
                         ┌─────────────────┐                   │
                         │ HOMING COMPLETE │                   │
                         │ • Positions known│                  │
                         │ • Limits active │                  │
                         │ • Ready to wind │                  │
                         └─────────┬───────┘                   │
                                   │                           │
                                   ▼                           │
                         ┌─────────────────┐                   │
                         │ WINDING SETUP   │                   │
                         │ • Check params  │                   │
                         │ • Validate ready│                   │
                         │ • Calc targets  │                   │
                         └─────────┬───────┘                   │
                                   │                           │
                                   ▼                           │
                         ┌─────────────────┐                   │
                         │ WINDING ACTIVE  │ ◄─────────────────┘
                         │ ┌─────────────┐ │
                         │ │ REAL-TIME   │ │
                         │ │ • BLDC RPM  │ │
                         │ │ • Traverse   │ │
                         │ │ • Turn count │ │
                         │ │ • Safety     │ │
                         │ └─────────────┘ │
                         └─────────┬───────┘
                                   │
                                   ▼
                         ┌─────────────────┐
                         │WINDING COMPLETE │
                         │ • Target reached│
                         │ • Motors stopped│
                         │ • Stats logged  │
                         └─────────┬───────┘
                                   │
                                   ▼
                         ┌─────────────────┐
                         │   SHUTDOWN      │
                         │ • Motors off   │
                         │ • Data saved   │
                         │ • Clean exit   │
                         └─────────────────┘

EMERGENCY STOP can trigger from ANY state → SAFE SHUTDOWN

Key Transitions:
• Power → Boot → Ready
• Ready → Home → Homed → Setup → Active → Complete → Ready
• Any state → Emergency → Safe Shutdown

Real-time loops:
• Hall sensor polling (100µs)
• Stepper control (1000µs) 
• Status updates (100ms)
• Safety monitoring (continuous)

Communication:
CM4 (Host) ↔ Pico (MCU) via USB serial
Commands: config, home, start_winding, status, emergency
Responses: confirmations, real-time data, error reports

