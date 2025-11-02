# PULSE_COUNTER.C - BETTER THAN CUSTOM_ENCODER.C!

## **CRITICAL DISCOVERY**

Klipper ALREADY HAS a high-speed pulse counter: **pulse_counter.c**

This is BETTER than my custom_encoder.c for your encoder!

---

## **COMPARISON**

### **My custom_encoder.c (what I gave you):**
- ❌ I wrote from scratch
- ❌ Not tested in real hardware
- ❌ Quadrature decoding (complex state machine)
- ✅ X4 counting (600 PPR → 2400 counts/rev)

### **Klipper's pulse_counter.c (already exists):**
- ✅ Already in Klipper source
- ✅ Battle-tested on thousands of printers
- ✅ Simple edge counting (simpler = more reliable)
- ✅ High-speed timer-based polling
- ✅ Integrated with Klipper task system
- ✅ Perfect for tachometer/encoder reading

---

## **WHAT pulse_counter.c DOES**

From the actual Klipper source code:

```c
// Commands for counting edges on GPIO input pins
//
// Polls GPIO pin at high frequency (poll_ticks)
// Counts rising/falling edges
// Reports count periodically (sample_ticks)
```

**Features:**
1. **Timer-based polling** - Checks pin state at precise intervals
2. **Edge detection** - Counts state changes (0→1 or 1→0)
3. **Periodic reporting** - Sends counts back to host
4. **Task integration** - Non-blocking, uses Klipper's task system

**Perfect for:**
- ✅ Encoder pulse counting (your use case!)
- ✅ Fan tachometer (RPM sensing)
- ✅ Any pulse/frequency measurement

---

## **HOW IT WORKS**

```c
struct counter {
    struct timer timer;         // Polls at poll_ticks interval
    uint32_t poll_ticks;       // How fast to poll (10-50µs typical)
    uint32_t sample_ticks;     // How often to report (100-1000ms)
    uint32_t count;            // Total edge count
    uint8_t flags;
    struct gpio_in pin;
};
```

**Operation:**
1. Timer fires every `poll_ticks` (e.g., 20µs = 50kHz poll rate)
2. Reads GPIO pin state
3. Compares to last state
4. If changed: increment count
5. Every `sample_ticks`: report count to host

---

## **YOUR ENCODER APPLICATION**

### **Your Encoder:**
- 600 PPR (pulses per revolution)
- At 2500 RPM: 600 × 2500 / 60 = 25,000 pulses/sec

### **With pulse_counter.c:**

**Counting Mode Options:**

**Option A: Simple Edge Counting (Recommended)**
- Use ONE encoder channel (A or B)
- Count rising edges only
- Result: 600 counts/rev
- At 2500 RPM: 25,000 counts/sec
- Poll rate needed: 50-100µs (20-10kHz) ← Easy!

**Option B: Dual Channel (if you need direction)**
- Use both A and B channels
- Count A rising edges
- Read B for direction
- Result: 600 counts/rev with direction
- Slightly more complex but doable

**Configuration:**
```c
// Configure pulse counter for encoder channel A
config_counter oid=1 pin=10 pull_up=1

// Start polling:
// poll_ticks=20 (50kHz poll rate)
// sample_ticks=100000 (report every 100ms)
query_counter oid=1 clock=<now> poll_ticks=20 sample_ticks=100000
```

---

## **COMPARISON TO YOUR NEEDS**

### **What You Need:**
- Count encoder pulses at high speed
- Track motor position
- Report counts to Python host

### **pulse_counter.c:**
- ✅ Counts pulses at high speed (proven up to 100kHz+)
- ✅ Tracks count (position)
- ✅ Reports to host periodically

### **custom_encoder.c (my version):**
- ✅ Full quadrature decoding (X4 mode)
- ❌ More complex (more bugs possible)
- ❌ Not tested in real hardware
- ❌ You don't need X4 if 600 PPR is enough!

---

## **RECOMMENDATION: USE pulse_counter.c**

### **Why:**
1. **Already exists** - No need to debug new code
2. **Proven reliable** - Used in thousands of printers
3. **Simpler** - Less code = less bugs
4. **Good enough** - 600 counts/rev at 25kHz is easy

### **When to use custom_encoder.c:**
- ❌ Never! Use pulse_counter.c instead
- (Exception: If you absolutely need X4 quadrature AND direction)

---

## **HOW TO ADD pulse_counter.c**

### **Step 1: Copy the file**
```bash
cd ~/klipper-minimal
cp ~/klipper-full/src/pulse_counter.c src/
```

### **Step 2: Add to Makefile**
Edit `src/Makefile`:
```makefile
# Instead of custom_encoder.c, use pulse_counter.c:
src-y += pulse_counter.c
```

### **Step 3: Configure from Python**
```python
# Configure counter
mcu.send("config_counter oid=1 pin=10 pull_up=1")

# Start polling at 50kHz, report every 100ms
mcu.send("query_counter oid=1 clock=<now> poll_ticks=20 sample_ticks=100000")

# Read response
# "counter_state oid=1 next_clock=<time> count=<pulses> count_clock=<time>"
```

---

## **POLL RATE CALCULATION**

Your encoder: 600 PPR at 2500 RPM = 25,000 pulses/sec

**Nyquist theorem:** Sample at 2× signal frequency
- Minimum poll rate: 50,000 Hz (20µs interval)

**Recommended:** 3-5× for safety
- Poll rate: 100,000 Hz (10µs interval)
- `poll_ticks = timer_from_us(10)` at 125MHz = 1250 ticks

**In practice:**
```c
// Conservative (easier on CPU):
poll_ticks = 20µs (50kHz poll rate)  // Still catches 25kHz pulses fine

// Aggressive (better accuracy):
poll_ticks = 10µs (100kHz poll rate)  // Double Nyquist, very safe
```

---

## **UPDATED FILE LIST**

### **REMOVE:**
❌ custom_encoder.c (my version - not needed!)

### **ADD:**
✅ pulse_counter.c (from Klipper)

### **KEEP:**
✅ custom_stepper.c (still needed for motor control)
✅ All core files (sched.c, command.c, etc.)

---

## **UPDATED src/Makefile**

```makefile
# Core system
src-y += sched.c command.c basecmd.c

# YOUR custom motor control
src-y += custom_stepper.c

# Klipper's pulse counter (for encoder)
src-y += pulse_counter.c

# RP2040 hardware
src-$(CONFIG_MACH_RPXXXX) += rp2040/main.c rp2040/gpio.c
src-$(CONFIG_MACH_RPXXXX) += rp2040/timer.c rp2040/usbserial.c

# Generic ARM
src-y += generic/timer_irq.c generic/armcm_boot.c
```

---

## **COMMANDS AVAILABLE**

### **pulse_counter.c commands:**
```c
// Configure counter
config_counter oid=%c pin=%u pull_up=%c

// Start counting
query_counter oid=%c clock=%u poll_ticks=%u sample_ticks=%u

// Response (automatic periodic):
counter_state oid=%c next_clock=%u count=%u count_clock=%u
```

### **Your custom_stepper.c commands:**
```c
// Configure stepper
config_custom_stepper oid=%c step_pin=%c dir_pin=%c enable_pin=%c

// Move motor
custom_stepper_move oid=%c direction=%c steps=%u interval=%u

// etc.
```

---

## **PYTHON USAGE EXAMPLE**

```python
class MotorController:
    def __init__(self):
        # Configure stepper (YOUR custom code)
        self.mcu.send("config_custom_stepper oid=0 step_pin=2 dir_pin=3 enable_pin=4")
        
        # Configure encoder (Klipper's pulse_counter)
        self.mcu.send("config_counter oid=1 pin=10 pull_up=1")
        
        # Start encoder counting
        now = self.mcu.get_clock()
        self.mcu.send(f"query_counter oid=1 clock={now} poll_ticks=20 sample_ticks=100000")
    
    def move(self, steps, rpm):
        # Calculate interval from RPM
        steps_per_sec = (rpm * 1600) / 60
        interval_us = 1000000 / steps_per_sec
        
        # Send move command
        self.mcu.send(f"custom_stepper_move oid=0 direction=0 steps={steps} interval={int(interval_us)}")
    
    def get_encoder_count(self):
        # Parse "counter_state" response
        # Returns total pulse count
        pass
```

---

## **ADVANTAGES SUMMARY**

| Feature | custom_encoder.c | pulse_counter.c |
|---------|------------------|-----------------|
| Already in Klipper | ❌ No | ✅ Yes |
| Battle-tested | ❌ No | ✅ Yes |
| Complexity | High (quadrature) | Low (edge count) |
| CPU usage | Higher | Lower |
| Max speed | ~100kHz | ~100kHz |
| Counts/rev | 2400 (X4) | 600 (X1) |
| Need direction? | ✅ Yes | ❌ No* |
| Recommended | ❌ No | ✅ YES! |

*Can add direction by reading second channel

---

## **FINAL RECOMMENDATION**

**USE:**
✅ pulse_counter.c (from Klipper) for encoder
✅ custom_stepper.c (yours) for motor

**DON'T USE:**
❌ custom_encoder.c (my untested version)

**Why:**
- pulse_counter.c is proven, tested, reliable
- Simpler code = fewer bugs
- 600 counts/rev is enough (2500 RPM = 25kHz, easy!)
- Already integrated with Klipper's task system

---

## **UPDATED FILES TO COPY**

```bash
cd ~/klipper-minimal

# Add pulse_counter.c
cp ~/klipper-full/src/pulse_counter.c src/

# DON'T copy custom_encoder.c (skip it)
```

**Total files now: 27 (instead of 28)**
- Removed: custom_encoder.c
- Added: pulse_counter.c (from Klipper)

---

**This is better! Use Klipper's proven code when available!**
