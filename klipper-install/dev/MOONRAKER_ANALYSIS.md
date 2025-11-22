# Moonraker Architecture Analysis

## Overview

[Moonraker](https://github.com/Arksine/moonraker) is the official API web server for Klipper. It provides HTTP REST APIs and WebSocket support, bridging web clients to Klipper's Unix Domain Socket API.

## Current Implementation vs Moonraker

### Our Current `klipper_interface.py`

**What We Have:**
- ✅ Direct Unix socket communication (`/tmp/klippy_uds`)
- ✅ JSON-RPC protocol implementation
- ✅ Basic request/response handling
- ✅ G-code command sending
- ✅ Object querying
- ✅ Interactive CLI mode

**What We're Missing:**
- ❌ HTTP REST API (only direct socket)
- ❌ WebSocket support (real-time updates)
- ❌ Request queuing/retry logic
- ❌ Better error handling
- ❌ Status subscription system
- ❌ File management
- ❌ Database for state persistence

---

## Moonraker Architecture

### Communication Layers

```
┌─────────────────┐
│  Web Client     │  (Browser, Mobile App, etc.)
│  (HTTP/WS)      │
└────────┬────────┘
         │ HTTP REST / WebSocket
         │
┌────────▼────────┐
│   Moonraker     │  (Python Tornado Server)
│   (Port 7125)   │
└────────┬────────┘
         │ Unix Domain Socket
         │ JSON-RPC Protocol
         │
┌────────▼────────┐
│    Klipper      │  (klippy.py)
│  (/tmp/klippy_uds)│
└─────────────────┘
```

### Key Components

1. **HTTP Server** (Tornado)
   - REST API endpoints (`/api/printer/...`)
   - WebSocket server (`/websocket`)
   - Static file serving
   - Authentication middleware

2. **Klipper Connection Manager**
   - Unix socket connection pooling
   - Request queuing
   - Response parsing
   - Error handling/retry

3. **Subscription System**
   - WebSocket subscriptions for real-time updates
   - Object status polling
   - Event broadcasting

4. **File Manager**
   - G-code file upload/download
   - Virtual SD card management
   - File system operations

5. **Database**
   - SQLite for state persistence
   - Job history
   - Settings storage

---

## Moonraker API Patterns

### 1. REST API Endpoints

Moonraker provides REST endpoints that map to Klipper commands:

```python
# GET /api/printer/objects/query?toolhead&heater_bed
# Maps to: {"method": "objects/query", "params": {"objects": {"toolhead": None, "heater_bed": None}}}

# POST /api/printer/gcode/script
# Body: {"script": "G28 Y"}
# Maps to: {"method": "gcode/script", "params": {"script": "G28 Y"}}

# GET /api/printer/info
# Maps to: {"method": "info"}
```

### 2. WebSocket Subscriptions

Real-time updates via WebSocket:

```javascript
// Subscribe to toolhead status
ws.send(JSON.stringify({
    "jsonrpc": "2.0",
    "method": "printer.objects.subscribe",
    "params": {
        "objects": {
            "toolhead": ["position", "status"],
            "bldc_motor": None  // All fields
        }
    },
    "id": 5434
}));

// Receive updates
{
    "jsonrpc": "2.0",
    "method": "notify_status_update",
    "params": [{
        "toolhead": {
            "position": [0, 50, 0, 0],
            "status": {...}
        },
        "bldc_motor": {
            "current_rpm": 1000.0,
            "is_running": true
        }
    }, 1234567890.123]
}
```

### 3. Request Queuing

Moonraker queues requests and handles retries:

```python
class KlipperConnection:
    def __init__(self):
        self.request_queue = []
        self.pending_requests = {}
        self.socket = None
    
    def send_request(self, method, params):
        request_id = self.get_next_id()
        request = {
            "id": request_id,
            "method": method,
            "params": params
        }
        self.request_queue.append(request)
        self._process_queue()
    
    def _process_queue(self):
        while self.request_queue and self.socket:
            request = self.request_queue.pop(0)
            self._send_raw(request)
```

---

## Recommendations for Winder Interface

### Option 1: Use Moonraker Directly (Recommended)

**Pros:**
- ✅ Battle-tested, production-ready
- ✅ Full HTTP REST API
- ✅ WebSocket support
- ✅ File management
- ✅ Authentication
- ✅ Active development/maintenance

**Cons:**
- ❌ Additional dependency
- ❌ More complex setup
- ❌ May have features we don't need

**Implementation:**
```bash
# Install Moonraker
cd ~
git clone https://github.com/Arksine/moonraker.git
cd moonraker
./scripts/install-moonraker.sh

# Configure Moonraker
# Edit ~/moonraker_data/moonraker.conf
```

**Usage:**
```python
import requests

# REST API
response = requests.get("http://localhost:7125/api/printer/objects/query",
                       params={"toolhead": None, "bldc_motor": None})
status = response.json()["result"]["status"]

# Send G-code
response = requests.post("http://localhost:7125/api/printer/gcode/script",
                        json={"script": "WINDER_START RPM=1000"})
```

---

### Option 2: Enhance Our Interface (Lightweight)

Add Moonraker-like features to our existing `klipper_interface.py`:

#### 2a. Add HTTP REST API (Flask/FastAPI)

```python
from flask import Flask, jsonify, request
from klipper_interface import KlipperInterface

app = Flask(__name__)
klipper = KlipperInterface()

@app.route('/api/printer/info', methods=['GET'])
def get_printer_info():
    info = klipper.get_printer_info()
    return jsonify({"result": info})

@app.route('/api/printer/gcode/script', methods=['POST'])
def send_gcode():
    script = request.json.get('script')
    success = klipper.send_gcode(script)
    return jsonify({"result": {"success": success}})

@app.route('/api/printer/objects/query', methods=['GET'])
def query_objects():
    objects = request.args.get('objects', '').split(',')
    objects_dict = {obj: None for obj in objects if obj}
    status = klipper.query_objects(objects_dict)
    return jsonify({"result": {"status": status}})

if __name__ == '__main__':
    klipper.connect()
    app.run(host='0.0.0.0', port=7125)
```

#### 2b. Add WebSocket Support (Tornado)

```python
import tornado.websocket
import tornado.web
import json

class StatusWebSocket(tornado.websocket.WebSocketHandler):
    clients = set()
    subscriptions = {}  # {client_id: {objects: {...}}}
    
    def open(self):
        self.clients.add(self)
        self.subscriptions[id(self)] = {"objects": {}}
    
    def on_message(self, message):
        data = json.loads(message)
        if data.get("method") == "printer.objects.subscribe":
            self.subscriptions[id(self)]["objects"] = data["params"]["objects"]
            # Start polling and sending updates
    
    def on_close(self):
        self.clients.remove(self)
        del self.subscriptions[id(self)]
    
    @classmethod
    def broadcast_status(cls, status):
        for client in cls.clients:
            client.write_message(json.dumps({
                "jsonrpc": "2.0",
                "method": "notify_status_update",
                "params": [status, time.time()]
            }))
```

#### 2c. Add Request Queuing

```python
import queue
import threading

class QueuedKlipperInterface(KlipperInterface):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.request_queue = queue.Queue()
        self.response_map = {}
        self.worker_thread = None
        self.running = False
    
    def start_worker(self):
        self.running = True
        self.worker_thread = threading.Thread(target=self._worker_loop)
        self.worker_thread.start()
    
    def _worker_loop(self):
        while self.running:
            try:
                request_id, method, params, callback = self.request_queue.get(timeout=1.0)
                response = self.send_webhook(method, params)
                if callback:
                    callback(response)
            except queue.Empty:
                continue
    
    def send_async(self, method, params, callback=None):
        request_id = self.request_id
        self.request_queue.put((request_id, method, params, callback))
        return request_id
```

---

### Option 3: Hybrid Approach

Use Moonraker for web interface, keep our direct interface for scripts:

**Architecture:**
```
┌─────────────────┐
│  Web GUI        │  → Moonraker (HTTP/WS)
│  (Future)       │
└─────────────────┘

┌─────────────────┐
│  Python Scripts │  → Direct Socket (klipper_interface.py)
│  (Current)      │
└─────────────────┘
         │
         └───→ Klipper (/tmp/klippy_uds)
```

**Benefits:**
- ✅ Moonraker for web interface (when we build one)
- ✅ Direct interface for scripts (faster, no HTTP overhead)
- ✅ Best of both worlds

---

## Moonraker API Endpoints for Winder

### Printer Control

```http
# Get printer status
GET /api/printer/info

# Query objects (toolhead, bldc_motor, angle_sensor, etc.)
GET /api/printer/objects/query?toolhead&bldc_motor&angle_sensor&spindle_hall&traverse

# Send G-code
POST /api/printer/gcode/script
Content-Type: application/json
{"script": "WINDER_START RPM=1000 LAYERS=5"}

# Emergency stop
POST /api/printer/emergency_stop

# Restart
POST /api/printer/restart
```

### WebSocket Subscriptions

```javascript
// Subscribe to winder status
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

// Receive real-time updates
{
    "jsonrpc": "2.0",
    "method": "notify_status_update",
    "params": [{
        "bldc_motor": {
            "current_rpm": 1000.0,
            "target_rpm": 1000.0,
            "is_running": true
        },
        "angle_sensor": {
            "current_angle_deg": 45.2,
            "measured_rpm": 1000.0,
            "revolutions": 1250
        },
        "winder_control": {
            "is_winding": true,
            "current_layer": 3,
            "spindle_rpm_target": 1000.0
        }
    }, 1234567890.123]
}
```

---

## KlipperScreen Integration

[KlipperScreen](https://github.com/KlipperScreen/KlipperScreen) is a touchscreen GUI that connects via Moonraker. Key patterns:

### 1. Moonraker Client Pattern

```python
import requests
import websocket
import json

class MoonrakerClient:
    def __init__(self, host="localhost", port=7125):
        self.base_url = f"http://{host}:{port}"
        self.ws_url = f"ws://{host}:{port}/websocket"
    
    def get_status(self):
        response = requests.get(f"{self.base_url}/api/printer/objects/query",
                               params={"toolhead": None, "bldc_motor": None})
        return response.json()["result"]["status"]
    
    def send_gcode(self, script):
        response = requests.post(f"{self.base_url}/api/printer/gcode/script",
                                json={"script": script})
        return response.json()
    
    def subscribe(self, objects, callback):
        ws = websocket.WebSocketApp(self.ws_url,
                                   on_message=callback)
        ws.send(json.dumps({
            "jsonrpc": "2.0",
            "method": "printer.objects.subscribe",
            "params": {"objects": objects},
            "id": 5434
        }))
        ws.run_forever()
```

### 2. Status Polling Pattern

```python
import time
import threading

class StatusPoller:
    def __init__(self, client, interval=0.25):
        self.client = client
        self.interval = interval
        self.running = False
        self.callback = None
    
    def start(self, callback):
        self.callback = callback
        self.running = True
        thread = threading.Thread(target=self._poll_loop)
        thread.daemon = True
        thread.start()
    
    def _poll_loop(self):
        while self.running:
            try:
                status = self.client.get_status()
                if self.callback:
                    self.callback(status)
            except Exception as e:
                print(f"Poll error: {e}")
            time.sleep(self.interval)
```

---

## Recommendations

### For Current Development (Scripts)

**Keep using direct socket interface** (`klipper_interface.py`):
- ✅ Faster (no HTTP overhead)
- ✅ Simpler (no web server needed)
- ✅ Perfect for scripts and automation
- ✅ Already working

### For Future Web GUI

**Use Moonraker**:
- ✅ Standard API for web interfaces
- ✅ WebSocket for real-time updates
- ✅ Well-documented
- ✅ Compatible with KlipperScreen, Mainsail, Fluidd

### Implementation Plan

1. **Phase 1** (Current): Keep `klipper_interface.py` for scripts
2. **Phase 2** (Next): Install Moonraker for web API
3. **Phase 3** (Future): Build custom GUI (web or KlipperScreen-based)

---

## Moonraker Installation

```bash
# On CM4
cd ~
git clone https://github.com/Arksine/moonraker.git
cd moonraker
./scripts/install-moonraker.sh

# Configure
nano ~/moonraker_data/moonraker.conf

# Start Moonraker
sudo systemctl start moonraker
sudo systemctl enable moonraker

# Check status
sudo systemctl status moonraker
```

---

## References

- [Moonraker GitHub](https://github.com/Arksine/moonraker)
- [Moonraker Documentation](https://moonraker.readthedocs.io/)
- [KlipperScreen GitHub](https://github.com/KlipperScreen/KlipperScreen)
- [Klipper API Server Docs](https://www.klipper3d.org/API_Server.html)

