#include "swift-wayland-shims.h"
#include "generated/legacy-unstable/relative-pointer/relative-pointer-unstable-v1-client-protocol.h"
#include "generated/legacy-unstable/pointer-constraints/pointer-constraints-unstable-v1-client-protocol.h"

static void swl_zwp_relative_pointer_v1_handle_relative_motion(
    void *data,
    struct zwp_relative_pointer_v1 *relative_pointer,
    uint32_t utime_hi,
    uint32_t utime_lo,
    wl_fixed_t dx,
    wl_fixed_t dy,
    wl_fixed_t dx_unaccel,
    wl_fixed_t dy_unaccel)
{
    const struct swl_zwp_relative_pointer_v1_listener_callbacks *cb = data;
    if (cb && cb->relative_motion)
        cb->relative_motion(
            cb->data,
            relative_pointer,
            utime_hi,
            utime_lo,
            dx,
            dy,
            dx_unaccel,
            dy_unaccel);
}

static const struct zwp_relative_pointer_v1_listener
    swl_zwp_relative_pointer_v1_listener_impl = {
        .relative_motion = swl_zwp_relative_pointer_v1_handle_relative_motion,
};

int swl_zwp_relative_pointer_v1_add_listener(
    struct zwp_relative_pointer_v1 *relative_pointer,
    const struct swl_zwp_relative_pointer_v1_listener_callbacks *callbacks)
{
    return zwp_relative_pointer_v1_add_listener(
        relative_pointer,
        &swl_zwp_relative_pointer_v1_listener_impl,
        (void *)callbacks);
}

static void swl_zwp_locked_pointer_v1_handle_locked(
    void *data,
    struct zwp_locked_pointer_v1 *locked_pointer)
{
    const struct swl_zwp_locked_pointer_v1_listener_callbacks *cb = data;
    if (cb && cb->locked)
        cb->locked(cb->data, locked_pointer);
}

static void swl_zwp_locked_pointer_v1_handle_unlocked(
    void *data,
    struct zwp_locked_pointer_v1 *locked_pointer)
{
    const struct swl_zwp_locked_pointer_v1_listener_callbacks *cb = data;
    if (cb && cb->unlocked)
        cb->unlocked(cb->data, locked_pointer);
}

static const struct zwp_locked_pointer_v1_listener
    swl_zwp_locked_pointer_v1_listener_impl = {
        .locked = swl_zwp_locked_pointer_v1_handle_locked,
        .unlocked = swl_zwp_locked_pointer_v1_handle_unlocked,
};

int swl_zwp_locked_pointer_v1_add_listener(
    struct zwp_locked_pointer_v1 *locked_pointer,
    const struct swl_zwp_locked_pointer_v1_listener_callbacks *callbacks)
{
    return zwp_locked_pointer_v1_add_listener(
        locked_pointer,
        &swl_zwp_locked_pointer_v1_listener_impl,
        (void *)callbacks);
}

static void swl_zwp_confined_pointer_v1_handle_confined(
    void *data,
    struct zwp_confined_pointer_v1 *confined_pointer)
{
    const struct swl_zwp_confined_pointer_v1_listener_callbacks *cb = data;
    if (cb && cb->confined)
        cb->confined(cb->data, confined_pointer);
}

static void swl_zwp_confined_pointer_v1_handle_unconfined(
    void *data,
    struct zwp_confined_pointer_v1 *confined_pointer)
{
    const struct swl_zwp_confined_pointer_v1_listener_callbacks *cb = data;
    if (cb && cb->unconfined)
        cb->unconfined(cb->data, confined_pointer);
}

static const struct zwp_confined_pointer_v1_listener
    swl_zwp_confined_pointer_v1_listener_impl = {
        .confined = swl_zwp_confined_pointer_v1_handle_confined,
        .unconfined = swl_zwp_confined_pointer_v1_handle_unconfined,
};

int swl_zwp_confined_pointer_v1_add_listener(
    struct zwp_confined_pointer_v1 *confined_pointer,
    const struct swl_zwp_confined_pointer_v1_listener_callbacks *callbacks)
{
    return zwp_confined_pointer_v1_add_listener(
        confined_pointer,
        &swl_zwp_confined_pointer_v1_listener_impl,
        (void *)callbacks);
}
