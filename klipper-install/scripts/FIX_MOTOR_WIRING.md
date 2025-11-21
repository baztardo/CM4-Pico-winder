# Fix Motor Wiring - Buzzing But Not Moving

## Problem
Motor buzzes but doesn't rotate = **Coil pairs are swapped**

## Motor Has 4 Wires (2 Coils)
- **Coil A**: A+ and A- (one pair)
- **Coil B**: B+ and B- (other pair)

## Solution: Swap Coil Pairs

### Step 1: Identify Current Wiring
Motor wires are probably:
- Wire 1 (e.g., Red) → Driver A+
- Wire 2 (e.g., Blue) → Driver A-
- Wire 3 (e.g., Green) → Driver B+
- Wire 4 (e.g., Black) → Driver B-

### Step 2: Swap Coil Pairs
**Swap entire coil A with coil B:**
- Move Wire 1/2 (Coil A) to B+/B- positions
- Move Wire 3/4 (Coil B) to A+/A- positions

**OR swap just one coil:**
- Swap Wire 1 with Wire 2 (reverse Coil A)
- OR swap Wire 3 with Wire 4 (reverse Coil B)

### Step 3: Test After Each Swap
```bash
python3 ~/klipper/scripts/klipper_interface.py -g "SET_STEPPER_ENABLE STEPPER=stepper_y ENABLE=1"
python3 ~/klipper/scripts/klipper_interface.py -g "G91"
python3 ~/klipper/scripts/klipper_interface.py -g "G1 Y1 F100"
```

### Step 4: If Still Buzzing
Try swapping the other coil pair, or swap both pairs.

## Alternative: Check TMC2209
If swapping wires doesn't work:
1. Check TMC2209 UART (PF13) connection
2. Check motor power supply
3. Try different TMC2209 driver

