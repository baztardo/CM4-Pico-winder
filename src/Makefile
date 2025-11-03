# Main code build rules

# MCU directories
dirs-$(CONFIG_MACH_STM32) += src/stm32

# Core system files
src-y += sched.c command.c basecmd.c

# GPIO and hardware interface
src-$(CONFIG_HAVE_GPIO) += initial_pins.c gpiocmds.c

# Optional features
src-$(CONFIG_WANT_TMCUART) += tmcuart.c
src-$(CONFIG_WANT_PULSE_COUNTER) += pulse_counter.c

# CNC winder code
src-y += stepper.c

# Simulator specific files
src-$(CONFIG_MACH_SIMULATOR) += simulator/main.c simulator/gpio.c
src-$(CONFIG_MACH_SIMULATOR) += simulator/serial.c simulator/timer.c

# RP2350 specific files (only essential ones)
src-$(CONFIG_MACH_RP2350) += rp2040/timer_rp2350.c

# Generic ARM Cortex-M files (conditional to avoid conflicts)
src-$(CONFIG_MACH_RP2040) += generic/timer_irq.c


