# Motor Buzzing But Not Moving - Wiring Check

Motor buzzing but not moving = **Motor coils wired incorrectly**

## Quick Fix: Swap Motor Coil Pairs

The motor has 4 wires forming 2 coils:
- Coil A: A+ and A-
- Coil B: B+ and B-

**Try swapping:**
1. Swap A+ with B+ (and A- with B-)
2. OR swap just one coil: A+ with A-

## Check TMC2209 UART

If swapping coils doesn't work, TMC2209 UART may not be working:

```bash
# Check logs for TMC errors
tail -100 /tmp/klippy.log | grep -i "tmc\|uart\|error"

# Check if step pulses are being sent
# (Motor should move even if coils are wrong - just wrong direction)
```

## Test: Bypass TMC2209

If motor still doesn't move after swapping coils, test without TMC2209:

1. Remove TMC2209 from driver header
2. Connect motor directly to PF12 (STEP), PF11 (DIR), PB3 (EN)
3. Use lower voltage/current
4. Test if motor moves

If motor moves without TMC2209 → TMC2209 UART issue (PF13)
If motor still doesn't move → Motor wiring or power issue

