# Manta M4P Stepper Header Pins for BLDC Motor PWM

## Your Setup:
- TMC2209 driver boards plug into headers
- Custom retrofit board fits into header
- 1kΩ resistors from STEP/DIR/ENA pins → BLDC controller (A2, A1, B2, B1)
- Need PWM-capable pin for BLDC motor speed control

## PWM-Capable Pins from Stepper Headers:

### X-axis Header (Motor 1):
- **STEP: PC6** - TIM3_CH1 ✅ **PWM-CAPABLE**
- **DIR: PA14** - BOOT0 pin (limited PWM, not recommended)
- **ENA: PC7** - TIM3_CH2 ✅ **PWM-CAPABLE**

### Y-axis Header (Motor 2 - Traverse):
- **STEP: PB10** - TIM2_CH3 ✅ **PWM-CAPABLE**
- **DIR: PB2** - TIM3_CH4 ✅ **PWM-CAPABLE**
- **ENA: PB11** - TIM2_CH2 ✅ **PWM-CAPABLE**

### Z-axis Header (Motor 3):
- **STEP: PB0** - TIM3_CH3 ✅ **PWM-CAPABLE**
- **DIR: PC5** - TIM3_CH2 ✅ **PWM-CAPABLE**
- **ENA: PB1** - TIM3_CH4 or TIM14_CH1 ✅ **PWM-CAPABLE**

### E0 Header (Motor 4/Extruder):
- **STEP: PB3** - TIM2_CH2 ✅ **PWM-CAPABLE**
- **DIR: PB4** - TIM3_CH1 ✅ **PWM-CAPABLE**
- **ENA: PD5** - TIM2_CH1 ✅ **PWM-CAPABLE**

## 🎯 RECOMMENDATIONS:

### Best Choices (if not using that axis for stepper):
1. **PB10 (Y-axis STEP)** - TIM2_CH3 ✅ **BEST** - High frequency timer
2. **PB0 (Z-axis STEP)** - TIM3_CH3 ✅ **GOOD** - High frequency timer
3. **PB3 (E0 STEP)** - TIM2_CH2 ✅ **GOOD** - High frequency timer
4. **PC6 (X-axis STEP)** - TIM3_CH1 ✅ **GOOD**

### DIR Pins (if not using that axis):
1. **PB2 (Y-axis DIR)** - TIM3_CH4 ✅ **GOOD**
2. **PC5 (Z-axis DIR)** - TIM3_CH2 ✅ **GOOD**
3. **PB4 (E0 DIR)** - TIM3_CH1 ✅ **GOOD**

### ENA Pins (if not using that axis):
1. **PB11 (Y-axis ENA)** - TIM2_CH2 ✅ **GOOD**
2. **PB1 (Z-axis ENA)** - TIM3_CH4 ✅ **GOOD**
3. **PD5 (E0 ENA)** - TIM2_CH1 ✅ **GOOD**
4. **PC7 (X-axis ENA)** - TIM3_CH2 ✅ **GOOD**

## ⚠️ IMPORTANT:

**If you're using Y-axis for traverse stepper**, you CANNOT use PB10/PB2/PB11 for BLDC PWM (they're needed for traverse).

**If Y-axis is NOT used for stepper**, then **PB10 (Y-axis STEP)** is the BEST choice for BLDC PWM!

## Which axis are you NOT using for steppers?

If you're only using Y-axis for traverse, then you could use:
- **X-axis:** PC6 (STEP) or PC7 (ENA) for BLDC PWM
- **Z-axis:** PB0 (STEP), PC5 (DIR), or PB1 (ENA) for BLDC PWM
- **E0:** PB3 (STEP), PB4 (DIR), or PD5 (ENA) for BLDC PWM

## Firmware Modification Needed:

To use any of these pins for PWM, you'll need to modify Klipper firmware (like the PD4 mod you did before) to enable PWM on that pin instead of stepper control.

**Which axis are you using for the traverse stepper?** That will determine which pins are available for BLDC PWM.

