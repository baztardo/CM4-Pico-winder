# Klipper Interface Recommendations

## Current State

We have `klipper_interface.py` which provides:
- ✅ Direct Unix socket communication
- ✅ JSON-RPC protocol
- ✅ G-code sending
- ✅ Object querying
- ✅ CLI interface

## Recommendation: Hybrid Approach

### Keep Direct Interface for Scripts

**Why:**
- Scripts need fast, direct communication
- No HTTP overhead
- Simpler dependencies
- Already working well

**Use Cases:**
- `test_motor_simple.py`
- `diagnose_tmc2209.py`
- `winder_control.py` scripts
- Automation scripts

### Add Moonraker for Web Interface

**Why:**
- Standard API for web clients
- WebSocket for real-time updates
- Compatible with existing tools
- Well-maintained

**Use Cases:**
- Future web GUI
- Mobile app
- Remote monitoring
- Integration with Mainsail/Fluidd/KlipperScreen

---

## Implementation Plan

### Phase 1: Enhance Direct Interface (Now)

**Improvements:**
1. Add request queuing for better reliability
2. Add retry logic
3. Add connection pooling
4. Better error messages

**File:** `klipper-install/scripts/klipper_interface.py`

### Phase 2: Install Moonraker (Next)

**Steps:**
```bash
# On CM4
cd ~
git clone https://github.com/Arksine/moonraker.git
cd moonraker
./scripts/install-moonraker.sh

# Configure for winder
nano ~/moonraker_data/moonraker.conf
```

**Benefits:**
- HTTP REST API available
- WebSocket support
- File management
- Can use existing web clients

### Phase 3: Build Custom GUI (Future)

**Options:**
1. **KlipperScreen Custom Theme**
   - Modify KlipperScreen for winder-specific UI
   - Reuse existing infrastructure

2. **Web GUI (React/Vue)**
   - Custom interface via Moonraker API
   - Full control over UI/UX

3. **Native App**
   - Python/Kivy or similar
   - Direct Moonraker API access

---

## Quick Start: Using Moonraker

### Install Moonraker

```bash
cd ~
git clone https://github.com/Arksine/moonraker.git
cd moonraker
./scripts/install-moonraker.sh
```

### Test Moonraker API

```python
import requests

# Get printer status
response = requests.get("http://localhost:7125/api/printer/objects/query",
                       params={"toolhead": None, "bldc_motor": None})
print(response.json())

# Send G-code
response = requests.post("http://localhost:7125/api/printer/gcode/script",
                        json={"script": "WINDER_START RPM=1000"})
print(response.json())
```

### WebSocket Example

```python
import websocket
import json

def on_message(ws, message):
    data = json.loads(message)
    print(f"Received: {data}")

ws = websocket.WebSocketApp("ws://localhost:7125/websocket",
                           on_message=on_message)

# Subscribe to winder objects
ws.send(json.dumps({
    "jsonrpc": "2.0",
    "method": "printer.objects.subscribe",
    "params": {
        "objects": {
            "bldc_motor": None,
            "angle_sensor": None,
            "winder_control": None
        }
    },
    "id": 5434
}))

ws.run_forever()
```

---

## Summary

| Interface | Use Case | Status |
|-----------|----------|--------|
| **Direct Socket** (`klipper_interface.py`) | Scripts, automation | ✅ Keep & enhance |
| **Moonraker** | Web GUI, remote access | ⚠️ Install next |
| **Custom GUI** | User interface | 💡 Future |

**Action Items:**
1. ✅ Keep improving `klipper_interface.py` for scripts
2. ⚠️ Install Moonraker for web API
3. 💡 Plan custom GUI (KlipperScreen theme or web app)

