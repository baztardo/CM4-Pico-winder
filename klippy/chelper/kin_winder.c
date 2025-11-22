// Winder kinematics stepper pulse time generation
//
// Copyright (C) 2024
//
// This file may be distributed under the terms of the GNU GPLv3 license.
//
// Winder kinematics for CNC Guitar Pickup Winder:
// - Y-axis (traverse) stepper synchronized with spindle rotation
// - Accounts for gear ratios, wire diameter, and layer calculations
// - Future: Real-time spindle RPM feedback for dynamic synchronization

#include <stdlib.h> // malloc
#include <string.h> // memset
#include "compiler.h" // __visible
#include "itersolve.h" // struct stepper_kinematics
#include "pyhelper.h" // errorf
#include "trapq.h" // move_get_coord

struct winder_stepper {
    struct stepper_kinematics sk;
    // Future: Add spindle sync parameters
    // double gear_ratio;           // Motor:Spindle gear ratio (e.g., 0.667 for 40:60)
    // double wire_diameter;         // Wire diameter in mm (e.g., 0.056 for 43AWG)
    // double bobbin_diameter;        // Current bobbin diameter (changes with layers)
    // double current_layer;         // Current layer number
};

static double
winder_stepper_y_calc_position(struct stepper_kinematics *sk, struct move *m
                               , double move_time)
{
    // For now, this is identical to cartesian Y-axis calculation
    // The synchronization happens at the Python level when creating moves
    // Future: Could add real-time spindle RPM feedback here for tighter sync
    return move_get_coord(m, move_time).y;
}

struct stepper_kinematics * __visible
winder_stepper_alloc(char axis)
{
    struct winder_stepper *ws = malloc(sizeof(*ws));
    memset(ws, 0, sizeof(*ws));
    
    if (axis == 'y') {
        ws->sk.calc_position_cb = winder_stepper_y_calc_position;
        ws->sk.active_flags = AF_Y;
    } else {
        // Winder kinematics only supports Y-axis (traverse)
        errorf("winder_stepper_alloc: axis '%c' not supported (only 'y')", axis);
        free(ws);
        return NULL;
    }
    
    return &ws->sk;
}

