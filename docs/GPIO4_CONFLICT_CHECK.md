# GPIO4 Conflict Check - Y-Stop Connector

## The Issue

**gpio4 has 2.7V even when trying to use it as PWM output.**

## Possible Causes

### 1. Physical Y-Stop Connector on SKR Pico

**SKR Pico might have:**
- Physical connector labeled "Y-STOP" or "Y-END" 
- Hardwired to gpio4
- If something is plugged in (or connector is floating with pull-up), it could cause voltage

**Check:**
- Look at SKR Pico board for Y-stop connector
- Is anything plugged into it?
- If yes, unplug it or check what it's connected to

### 2. Pull-Up Resistor on Board

**If gpio4 has pull-up resistor on board:**
- Pull-up to 3.3V would give ~2.7V reading
- This is normal for endstop pins
- But conflicts with using it as PWM output

**Solution:**
- Can't easily remove board pull-up
- Need to use different pin for PWM

### 3. Pin Already Configured as Input

**If gpio4 was previously configured as endstop:**
- Might still have pull-up enabled
- Needs to be reconfigured as PWM output

**Check Klipper log for:**
- Any endstop configuration on gpio4
- Pin conflict errors

## What to Check

1. **Physical board:**
   - Look for Y-stop connector
   - Check if anything is plugged in
   - Check if connector has pull-up resistor

2. **Measure gpio4:**
   - With nothing connected to optocoupler
   - Should read LOW (0V) if no pull-up
   - If it reads 2.7V with nothing connected → board has pull-up

3. **Check config:**
   - No endstop configured on gpio4 in your config (good!)
   - But board might have hardware pull-up

## Solution

**If gpio4 has hardware pull-up on board:**
- **Can't use it for PWM output** (pull-up conflicts)
- **Need to use different pin** for PWM
- Try gpio10, gpio11, gpio12, gpio13, gpio14, gpio15 (safe pins)

**If Y-stop connector has something plugged in:**
- **Unplug it** if not needed
- Or use different pin for PWM

## Quick Test

**Disconnect optocoupler from gpio4, then measure:**
- If gpio4 reads 2.7V with nothing connected → board has pull-up
- If gpio4 reads 0V → no pull-up, something else is causing voltage


