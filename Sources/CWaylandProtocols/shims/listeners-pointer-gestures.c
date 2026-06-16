#include "wayland-client-kit-shims.h"
#include "generated/legacy-unstable/pointer-gestures/pointer-gestures-unstable-v1-client-protocol.h"

static void swl_zwp_pointer_gesture_swipe_v1_handle_begin(
    void *data,
    struct zwp_pointer_gesture_swipe_v1 *gesture,
    uint32_t serial,
    uint32_t time,
    struct wl_surface *surface,
    uint32_t fingers)
{
    const struct swl_zwp_pointer_gesture_swipe_v1_listener_callbacks *cb =
        data;
    if (cb && cb->begin)
        cb->begin(cb->data, gesture, serial, time, surface, fingers);
}

static void swl_zwp_pointer_gesture_swipe_v1_handle_update(
    void *data,
    struct zwp_pointer_gesture_swipe_v1 *gesture,
    uint32_t time,
    wl_fixed_t dx,
    wl_fixed_t dy)
{
    const struct swl_zwp_pointer_gesture_swipe_v1_listener_callbacks *cb =
        data;
    if (cb && cb->update)
        cb->update(cb->data, gesture, time, dx, dy);
}

static void swl_zwp_pointer_gesture_swipe_v1_handle_end(
    void *data,
    struct zwp_pointer_gesture_swipe_v1 *gesture,
    uint32_t serial,
    uint32_t time,
    int32_t cancelled)
{
    const struct swl_zwp_pointer_gesture_swipe_v1_listener_callbacks *cb =
        data;
    if (cb && cb->end)
        cb->end(cb->data, gesture, serial, time, cancelled);
}

static const struct zwp_pointer_gesture_swipe_v1_listener
    swl_zwp_pointer_gesture_swipe_v1_listener_impl = {
        .begin = swl_zwp_pointer_gesture_swipe_v1_handle_begin,
        .update = swl_zwp_pointer_gesture_swipe_v1_handle_update,
        .end = swl_zwp_pointer_gesture_swipe_v1_handle_end,
    };

int swl_zwp_pointer_gesture_swipe_v1_add_listener(
    struct zwp_pointer_gesture_swipe_v1 *gesture,
    const struct swl_zwp_pointer_gesture_swipe_v1_listener_callbacks *callbacks)
{
    return zwp_pointer_gesture_swipe_v1_add_listener(
        gesture,
        &swl_zwp_pointer_gesture_swipe_v1_listener_impl,
        (void *)callbacks);
}

static void swl_zwp_pointer_gesture_pinch_v1_handle_begin(
    void *data,
    struct zwp_pointer_gesture_pinch_v1 *gesture,
    uint32_t serial,
    uint32_t time,
    struct wl_surface *surface,
    uint32_t fingers)
{
    const struct swl_zwp_pointer_gesture_pinch_v1_listener_callbacks *cb =
        data;
    if (cb && cb->begin)
        cb->begin(cb->data, gesture, serial, time, surface, fingers);
}

static void swl_zwp_pointer_gesture_pinch_v1_handle_update(
    void *data,
    struct zwp_pointer_gesture_pinch_v1 *gesture,
    uint32_t time,
    wl_fixed_t dx,
    wl_fixed_t dy,
    wl_fixed_t scale,
    wl_fixed_t rotation)
{
    const struct swl_zwp_pointer_gesture_pinch_v1_listener_callbacks *cb =
        data;
    if (cb && cb->update)
        cb->update(cb->data, gesture, time, dx, dy, scale, rotation);
}

static void swl_zwp_pointer_gesture_pinch_v1_handle_end(
    void *data,
    struct zwp_pointer_gesture_pinch_v1 *gesture,
    uint32_t serial,
    uint32_t time,
    int32_t cancelled)
{
    const struct swl_zwp_pointer_gesture_pinch_v1_listener_callbacks *cb =
        data;
    if (cb && cb->end)
        cb->end(cb->data, gesture, serial, time, cancelled);
}

static const struct zwp_pointer_gesture_pinch_v1_listener
    swl_zwp_pointer_gesture_pinch_v1_listener_impl = {
        .begin = swl_zwp_pointer_gesture_pinch_v1_handle_begin,
        .update = swl_zwp_pointer_gesture_pinch_v1_handle_update,
        .end = swl_zwp_pointer_gesture_pinch_v1_handle_end,
    };

int swl_zwp_pointer_gesture_pinch_v1_add_listener(
    struct zwp_pointer_gesture_pinch_v1 *gesture,
    const struct swl_zwp_pointer_gesture_pinch_v1_listener_callbacks *callbacks)
{
    return zwp_pointer_gesture_pinch_v1_add_listener(
        gesture,
        &swl_zwp_pointer_gesture_pinch_v1_listener_impl,
        (void *)callbacks);
}

static void swl_zwp_pointer_gesture_hold_v1_handle_begin(
    void *data,
    struct zwp_pointer_gesture_hold_v1 *gesture,
    uint32_t serial,
    uint32_t time,
    struct wl_surface *surface,
    uint32_t fingers)
{
    const struct swl_zwp_pointer_gesture_hold_v1_listener_callbacks *cb =
        data;
    if (cb && cb->begin)
        cb->begin(cb->data, gesture, serial, time, surface, fingers);
}

static void swl_zwp_pointer_gesture_hold_v1_handle_end(
    void *data,
    struct zwp_pointer_gesture_hold_v1 *gesture,
    uint32_t serial,
    uint32_t time,
    int32_t cancelled)
{
    const struct swl_zwp_pointer_gesture_hold_v1_listener_callbacks *cb =
        data;
    if (cb && cb->end)
        cb->end(cb->data, gesture, serial, time, cancelled);
}

static const struct zwp_pointer_gesture_hold_v1_listener
    swl_zwp_pointer_gesture_hold_v1_listener_impl = {
        .begin = swl_zwp_pointer_gesture_hold_v1_handle_begin,
        .end = swl_zwp_pointer_gesture_hold_v1_handle_end,
    };

int swl_zwp_pointer_gesture_hold_v1_add_listener(
    struct zwp_pointer_gesture_hold_v1 *gesture,
    const struct swl_zwp_pointer_gesture_hold_v1_listener_callbacks *callbacks)
{
    return zwp_pointer_gesture_hold_v1_add_listener(
        gesture,
        &swl_zwp_pointer_gesture_hold_v1_listener_impl,
        (void *)callbacks);
}
