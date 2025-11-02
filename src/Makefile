# Main code build rules

# Core system files
src-y += sched.c command.c basecmd.c

# GPIO and hardware interface
src-$(CONFIG_HAVE_GPIO) += initial_pins.c gpiocmds.c

# Optional features
src-$(CONFIG_WANT_TMCUART) += tmcuart.c
src-$(CONFIG_WANT_PULSE_COUNTER) += pulse_counter.c

# CNC winder code
src-y += stepper.c

# RP2350 specific files (only essential ones)
src-$(CONFIG_MACH_RP2350) += rp2040/timer_rp2350.c

# Generic ARM Cortex-M files (minimal set to avoid conflicts)
src-y += generic/timer_irq.c generic/armcm_boot.c


