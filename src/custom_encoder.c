// Custom quadrature encoder reading - HIGH SPEED
//
// Copyright (C) 2024  Your Name
//
// This file may be distributed under the terms of the GNU GPLv3 license.

#include "basecmd.h" // oid_alloc
#include "board/gpio.h" // gpio_in_read
#include "board/irq.h" // irq_disable
#include "board/misc.h" // timer_read_time
#include "command.h" // DECL_COMMAND
#include "sched.h" // struct timer
#include "config.h"

struct custom_encoder {
    struct timer timer;
    struct gpio_in pin_a;
    struct gpio_in pin_b;
    
    int32_t count;              // Current encoder count
    uint32_t poll_ticks;        // Microseconds between polls
    uint32_t sample_ticks;      // Report interval
    uint32_t next_sample_time;
    
    uint8_t last_state;         // Previous AB state for quadrature
    uint8_t flags;
};

enum { EF_PENDING = 1<<0 };

static struct task_wake encoder_wake;

// Quadrature state table for X4 encoding
// Current AB | Last AB | Direction
// Each transition increments or decrements count
static const int8_t quadrature_table[16] = {
    0,  -1,   1,  0,  // 00 -> 00, 01, 10, 11
    1,   0,   0, -1,  // 01 -> 00, 01, 10, 11
   -1,   0,   0,  1,  // 10 -> 00, 01, 10, 11
    0,   1,  -1,  0   // 11 -> 00, 01, 10, 11
};

// High-speed encoder polling callback
static uint_fast8_t
encoder_event(struct timer *timer)
{
    struct custom_encoder *e = container_of(timer, struct custom_encoder, timer);
    uint32_t time = timer->waketime;
    
    // Read current encoder state
    uint8_t a = gpio_in_read(e->pin_a);
    uint8_t b = gpio_in_read(e->pin_b);
    uint8_t current_state = (a << 1) | b;
    
    // Lookup quadrature change
    uint8_t index = (e->last_state << 2) | current_state;
    int8_t delta = quadrature_table[index];
    
    if (delta != 0) {
        e->count += delta;
    }
    
    e->last_state = current_state;
    
    // Check if time to report
    if (timer_is_before(e->next_sample_time, time)) {
        e->flags |= EF_PENDING;
        e->next_sample_time = time + e->sample_ticks;
        sched_wake_task(&encoder_wake);
    }
    
    // Schedule next poll
    timer->waketime += e->poll_ticks;
    return SF_RESCHEDULE;
}

// Command: config_custom_encoder oid=%c pin_a=%u pin_b=%u pull_up=%c
void
command_config_custom_encoder(uint32_t *args)
{
    struct custom_encoder *e = oid_alloc(
        args[0], command_config_custom_encoder, sizeof(*e));
    
    e->pin_a = gpio_in_setup(args[1], args[3]);  // Pin A with pull-up
    e->pin_b = gpio_in_setup(args[2], args[3]);  // Pin B with pull-up
    
    e->timer.func = encoder_event;
    e->count = 0;
    e->last_state = (gpio_in_read(e->pin_a) << 1) | gpio_in_read(e->pin_b);
}
DECL_COMMAND(command_config_custom_encoder,
             "config_custom_encoder oid=%c pin_a=%u pin_b=%u pull_up=%c");

// Command: query_custom_encoder oid=%c clock=%u poll_ticks=%u sample_ticks=%u
void
command_query_custom_encoder(uint32_t *args)
{
    struct custom_encoder *e = oid_lookup(args[0], command_config_custom_encoder);
    
    sched_del_timer(&e->timer);
    e->timer.waketime = args[1];
    e->poll_ticks = args[2];        // How often to poll (10-50µs typical)
    e->sample_ticks = args[3];      // How often to report (100-1000ms)
    e->next_sample_time = e->timer.waketime;
    
    sched_add_timer(&e->timer);
}
DECL_COMMAND(command_query_custom_encoder,
             "query_custom_encoder oid=%c clock=%u poll_ticks=%u sample_ticks=%u");

// Task to report encoder values
void
custom_encoder_task(void)
{
    if (!sched_check_wake(&encoder_wake))
        return;
    
    uint8_t oid;
    struct custom_encoder *e;
    foreach_oid(oid, e, command_config_custom_encoder) {
        if (!(e->flags & EF_PENDING))
            continue;
        
        irq_disable();
        int32_t count = e->count;
        uint32_t time = e->timer.waketime;
        e->flags &= ~EF_PENDING;
        irq_enable();
        
        sendf("custom_encoder_state oid=%c next_clock=%u count=%i",
              oid, time, count);
    }
}
DECL_TASK(custom_encoder_task);

// Command: custom_encoder_set_position oid=%c count=%i
void
command_custom_encoder_set_position(uint32_t *args)
{
    struct custom_encoder *e = oid_lookup(args[0], command_config_custom_encoder);
    
    irq_disable();
    e->count = args[1];
    irq_enable();
}
DECL_COMMAND(command_custom_encoder_set_position,
             "custom_encoder_set_position oid=%c count=%i");
