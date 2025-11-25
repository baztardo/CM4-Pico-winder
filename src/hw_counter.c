// Hardware counter using STM32 EXTI interrupts
//
// Copyright (C) 2024
//
// This file may be distributed under the terms of the GNU GPLv3 license.

#include "autoconf.h" // CONFIG_MACH_STM32G0
#include "board/armcm_boot.h" // armcm_enable_irq
#include "board/gpio.h" // gpio_in_setup
#include "board/irq.h" // irq_disable
#include "board/misc.h" // timer_read_time
#include "command.h" // DECL_COMMAND
#include "sched.h" // struct timer
#include "basecmd.h" // oid_alloc

#if CONFIG_MACH_STM32G0

#include "board/internal.h" // GPIO2PORT, GPIO2BIT

struct hw_counter {
    struct timer timer;
    uint32_t sample_ticks, next_sample_time;
    uint32_t count;
    uint32_t last_count_time;
    uint8_t flags;
    uint8_t exti_line;
    struct gpio_in pin;
};

enum {
    HWC_PENDING = 1,
};

static struct task_wake hw_counter_wake;
static struct hw_counter *exti_counters[16] = {0};  // One per EXTI line

static void
hw_counter_configure_exti_source(uint8_t exti_line, uint8_t port)
{
    uint32_t shift = (exti_line % 4) * 4;
    volatile uint32_t *exticr = (volatile uint32_t *)((uint32_t)&SYSCFG->CFGR1 + (exti_line / 4) * 4);
    uint32_t mask = 0xF << shift;
    irqstatus_t flag = irq_save();
    *exticr = (*exticr & ~mask) | ((uint32_t)port << shift);
    irq_restore(flag);
}

// EXTI interrupt handler - called on EVERY edge
static void
hw_counter_exti_irq(uint8_t exti_line)
{
    struct hw_counter *hc = exti_counters[exti_line];
    if (!hc)
        return;
    
    // Increment count
    hc->count++;
    hc->last_count_time = timer_read_time();
    
    // Clear EXTI pending bits
    EXTI->RPR1 = (1 << exti_line);  // Rising edge
    EXTI->FPR1 = (1 << exti_line);  // Falling edge
}

// STM32G0 EXTI interrupt handlers
void
EXTI0_1_IRQHandler(void)
{
    uint32_t pending = EXTI->RPR1 | EXTI->FPR1;
    if (pending & (1 << 0))
        hw_counter_exti_irq(0);
    if (pending & (1 << 1))
        hw_counter_exti_irq(1);
}

void
EXTI2_3_IRQHandler(void)
{
    uint32_t pending = EXTI->RPR1 | EXTI->FPR1;
    if (pending & (1 << 2))
        hw_counter_exti_irq(2);
    if (pending & (1 << 3))
        hw_counter_exti_irq(3);
}

void
EXTI4_15_IRQHandler(void)
{
    uint32_t pending = EXTI->RPR1 | EXTI->FPR1;
    for (uint8_t i = 4; i <= 15; i++) {
        if (pending & (1 << i))
            hw_counter_exti_irq(i);
    }
}

// Timer event - just for periodic reporting
static uint_fast8_t
hw_counter_event(struct timer *timer)
{
    struct hw_counter *hc = container_of(timer, struct hw_counter, timer);
    
    // Check if we need to report
    uint32_t time = hc->timer.waketime;
    if (!timer_is_before(time, hc->next_sample_time)) {
        hc->flags |= HWC_PENDING;
        hc->next_sample_time = time + hc->sample_ticks;
        sched_wake_task(&hw_counter_wake);
    }
    
    // Reschedule
    hc->timer.waketime += hc->sample_ticks;
    return SF_RESCHEDULE;
}

void
command_config_hw_counter(uint32_t *args)
{
    struct hw_counter *hc = oid_alloc(
        args[0], command_config_hw_counter, sizeof(*hc));
    uint32_t pin_num = args[1];
    uint8_t pull_up = args[2];
    uint8_t exti_line = pin_num % 16;
    
    if (exti_line >= ARRAY_SIZE(exti_counters))
        shutdown("hw_counter: Invalid EXTI line");
    if (exti_counters[exti_line])
        shutdown("hw_counter: EXTI line already in use");

    // Setup GPIO pin
    hc->pin = gpio_in_setup(pin_num, pull_up);
    hc->count = 0;
    hc->last_count_time = 0;
    hc->flags = 0;
    hc->timer.func = hw_counter_event;
    
    // Get EXTI line (same as pin number within port)
    hc->exti_line = exti_line;
    
    // Get port number (0=A, 1=B, 2=C, etc.)
    uint8_t port = GPIO2PORT(pin_num);
    
    // Enable SYSCFG clock
    RCC->APBENR2 |= RCC_APBENR2_SYSCFGEN;

    uint32_t mask = 1 << exti_line;
    EXTI->IMR1 &= ~mask;
    EXTI->RTSR1 &= ~mask;
    EXTI->FTSR1 &= ~mask;
    EXTI->RPR1 = mask;
    EXTI->FPR1 = mask;

    hw_counter_configure_exti_source(exti_line, port);

    // Store counter before enabling interrupts
    exti_counters[exti_line] = hc;

    // Configure EXTI line for rising edge only (one pulse per magnet pass)
    EXTI->RTSR1 |= mask;  // Rising edge trigger
    // EXTI->FTSR1 |= mask;  // Falling edge trigger (DISABLED - only use rising)
    EXTI->IMR1 |= mask;   // Unmask interrupt

    // Enable NVIC interrupt using Klipper's armcm_enable_irq macro
    if (exti_line <= 1) {
        armcm_enable_irq(EXTI0_1_IRQHandler, EXTI0_1_IRQn, 0);
    } else if (exti_line <= 3) {
        armcm_enable_irq(EXTI2_3_IRQHandler, EXTI2_3_IRQn, 0);
    } else {
        armcm_enable_irq(EXTI4_15_IRQHandler, EXTI4_15_IRQn, 0);
    }
}
DECL_COMMAND(command_config_hw_counter,
             "config_hw_counter oid=%c pin=%u pull_up=%c");

void
command_query_hw_counter(uint32_t *args)
{
    struct hw_counter *hc = oid_lookup(args[0], command_config_hw_counter);
    sched_del_timer(&hc->timer);
    hc->timer.waketime = args[1];
    hc->sample_ticks = args[2];
    hc->next_sample_time = 0;
    
    sched_add_timer(&hc->timer);
}
DECL_COMMAND(command_query_hw_counter,
             "query_hw_counter oid=%c clock=%u sample_ticks=%u");

void
command_force_hw_counter(uint32_t *args)
{
    struct hw_counter *hc = oid_lookup(args[0], command_config_hw_counter);
    hc->flags |= HWC_PENDING;
    sched_wake_task(&hw_counter_wake);
}
DECL_COMMAND(command_force_hw_counter,
             "force_hw_counter oid=%c");

void
hw_counter_task(void)
{
    if (!sched_check_wake(&hw_counter_wake))
        return;

    uint8_t oid;
    struct hw_counter *hc;
    foreach_oid(oid, hc, command_config_hw_counter) {
        if (!(hc->flags & HWC_PENDING))
            continue;
        irq_disable();
        uint32_t count = hc->count;
        uint32_t count_time = hc->last_count_time;
        hc->flags &= ~HWC_PENDING;
        irq_enable();
        sendf("hw_counter_state oid=%c count=%u count_clock=%u",
              oid, count, count_time);
    }
}
DECL_TASK(hw_counter_task);

#endif // CONFIG_MACH_STM32G0
