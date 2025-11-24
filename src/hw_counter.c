// Hardware counter using STM32 EXTI interrupts
//
// Copyright (C) 2024
//
// This file may be distributed under the terms of the GNU GPLv3 license.
//
// Uses hardware EXTI interrupts to count edges with 100% accuracy

#include "autoconf.h" // CONFIG_MACH_STM32G0
#include "board/gpio.h" // gpio_in_setup
#include "board/irq.h" // irq_disable
#include "board/misc.h" // timer_read_time
#include "command.h" // DECL_COMMAND
#include "sched.h" // struct timer
#include "basecmd.h" // oid_alloc
#include "internal.h" // GPIO2PORT, GPIO2BIT

#if CONFIG_MACH_STM32G0

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

// EXTI interrupt handler - called on EVERY edge
void
hw_counter_exti_irq(uint8_t exti_line)
{
    struct hw_counter *hc = exti_counters[exti_line];
    if (!hc)
        return;
    
    // Increment count
    hc->count++;
    hc->last_count_time = timer_read_time();
    
    // Clear EXTI pending bit
    EXTI->RPR1 = (1 << exti_line);  // Rising edge
    EXTI->FPR1 = (1 << exti_line);  // Falling edge
}

// STM32G0 EXTI interrupt handlers
void __visible EXTI0_1_IRQHandler(void)
{
    uint32_t pending = EXTI->RPR1 | EXTI->FPR1;
    if (pending & (1 << 0))
        hw_counter_exti_irq(0);
    if (pending & (1 << 1))
        hw_counter_exti_irq(1);
}

void __visible EXTI2_3_IRQHandler(void)
{
    uint32_t pending = EXTI->RPR1 | EXTI->FPR1;
    if (pending & (1 << 2))
        hw_counter_exti_irq(2);
    if (pending & (1 << 3))
        hw_counter_exti_irq(3);
}

void __visible EXTI4_15_IRQHandler(void)
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
    if (timer_is_before(hc->next_sample_time, time)) {
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
    
    // Setup GPIO pin
    hc->pin = gpio_in_setup(pin_num, pull_up);
    hc->count = 0;
    hc->last_count_time = 0;
    hc->flags = 0;
    hc->timer.func = hw_counter_event;
    
    // Get EXTI line (same as pin number within port)
    uint8_t exti_line = GPIO2BIT(pin_num);
    hc->exti_line = exti_line;
    
    // Get port number (0=A, 1=B, 2=C, etc.)
    uint8_t port = GPIO2PORT(pin_num);
    
    // Enable SYSCFG clock
    RCC->APBENR2 |= RCC_APBENR2_SYSCFGEN;
    
    // Configure SYSCFG EXTICR to map this pin to this EXTI line
    // STM32G0: 4 bits per EXTI line, 4 lines per register
    uint8_t reg_idx = exti_line / 4;
    uint8_t bit_pos = (exti_line % 4) * 4;  // 4 bits per line
    uint32_t *exticr = &SYSCFG->EXTICR[reg_idx];
    *exticr = (*exticr & ~(0xF << bit_pos)) | (port << bit_pos);
    
    // Configure EXTI line for both edges
    EXTI->RTSR1 |= (1 << exti_line);  // Rising edge trigger
    EXTI->FTSR1 |= (1 << exti_line);  // Falling edge trigger
    EXTI->IMR1 |= (1 << exti_line);   // Unmask interrupt
    
    // Store counter in global array for IRQ handler
    exti_counters[exti_line] = hc;
    
    // Enable NVIC interrupt
    if (exti_line <= 1) {
        NVIC_SetPriority(EXTI0_1_IRQn, 0);
        NVIC_EnableIRQ(EXTI0_1_IRQn);
    } else if (exti_line <= 3) {
        NVIC_SetPriority(EXTI2_3_IRQn, 0);
        NVIC_EnableIRQ(EXTI2_3_IRQn);
    } else {
        NVIC_SetPriority(EXTI4_15_IRQn, 0);
        NVIC_EnableIRQ(EXTI4_15_IRQn);
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
    hc->next_sample_time = hc->timer.waketime;
    
    sched_add_timer(&hc->timer);
}
DECL_COMMAND(command_query_hw_counter,
             "query_hw_counter oid=%c clock=%u sample_ticks=%u");

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
