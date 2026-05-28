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

#ifdef SWL_ENABLE_TESTING
static struct swl_test_pointer_capture_listener_record
    swl_test_pointer_capture_listener_latest;

static void swl_test_record_relative_motion(
    void *data,
    struct zwp_relative_pointer_v1 *relative_pointer,
    uint32_t utime_hi,
    uint32_t utime_lo,
    int32_t dx,
    int32_t dy,
    int32_t dx_unaccel,
    int32_t dy_unaccel)
{
    swl_test_pointer_capture_listener_latest.call_count += 1;
    swl_test_pointer_capture_listener_latest.kind =
        SWL_TEST_POINTER_CAPTURE_LISTENER_RELATIVE_MOTION;
    swl_test_pointer_capture_listener_latest.data = data;
    swl_test_pointer_capture_listener_latest.object = relative_pointer;
    swl_test_pointer_capture_listener_latest.utime_hi = utime_hi;
    swl_test_pointer_capture_listener_latest.utime_lo = utime_lo;
    swl_test_pointer_capture_listener_latest.dx = dx;
    swl_test_pointer_capture_listener_latest.dy = dy;
    swl_test_pointer_capture_listener_latest.dx_unaccel = dx_unaccel;
    swl_test_pointer_capture_listener_latest.dy_unaccel = dy_unaccel;
}

static void swl_test_record_locked(
    void *data,
    struct zwp_locked_pointer_v1 *locked_pointer)
{
    swl_test_pointer_capture_listener_latest.call_count += 1;
    swl_test_pointer_capture_listener_latest.kind =
        SWL_TEST_POINTER_CAPTURE_LISTENER_LOCKED;
    swl_test_pointer_capture_listener_latest.data = data;
    swl_test_pointer_capture_listener_latest.object = locked_pointer;
}

static void swl_test_record_unlocked(
    void *data,
    struct zwp_locked_pointer_v1 *locked_pointer)
{
    swl_test_pointer_capture_listener_latest.call_count += 1;
    swl_test_pointer_capture_listener_latest.kind =
        SWL_TEST_POINTER_CAPTURE_LISTENER_UNLOCKED;
    swl_test_pointer_capture_listener_latest.data = data;
    swl_test_pointer_capture_listener_latest.object = locked_pointer;
}

static void swl_test_record_confined(
    void *data,
    struct zwp_confined_pointer_v1 *confined_pointer)
{
    swl_test_pointer_capture_listener_latest.call_count += 1;
    swl_test_pointer_capture_listener_latest.kind =
        SWL_TEST_POINTER_CAPTURE_LISTENER_CONFINED;
    swl_test_pointer_capture_listener_latest.data = data;
    swl_test_pointer_capture_listener_latest.object = confined_pointer;
}

static void swl_test_record_unconfined(
    void *data,
    struct zwp_confined_pointer_v1 *confined_pointer)
{
    swl_test_pointer_capture_listener_latest.call_count += 1;
    swl_test_pointer_capture_listener_latest.kind =
        SWL_TEST_POINTER_CAPTURE_LISTENER_UNCONFINED;
    swl_test_pointer_capture_listener_latest.data = data;
    swl_test_pointer_capture_listener_latest.object = confined_pointer;
}

static struct swl_zwp_relative_pointer_v1_listener_callbacks
swl_test_relative_pointer_callbacks(void *data)
{
    return (struct swl_zwp_relative_pointer_v1_listener_callbacks){
        .relative_motion = swl_test_record_relative_motion,
        .data = data,
    };
}

static struct swl_zwp_locked_pointer_v1_listener_callbacks
swl_test_locked_pointer_callbacks(void *data)
{
    return (struct swl_zwp_locked_pointer_v1_listener_callbacks){
        .locked = swl_test_record_locked,
        .unlocked = swl_test_record_unlocked,
        .data = data,
    };
}

static struct swl_zwp_confined_pointer_v1_listener_callbacks
swl_test_confined_pointer_callbacks(void *data)
{
    return (struct swl_zwp_confined_pointer_v1_listener_callbacks){
        .confined = swl_test_record_confined,
        .unconfined = swl_test_record_unconfined,
        .data = data,
    };
}
#endif

int swl_zwp_confined_pointer_v1_add_listener(
    struct zwp_confined_pointer_v1 *confined_pointer,
    const struct swl_zwp_confined_pointer_v1_listener_callbacks *callbacks)
{
    return zwp_confined_pointer_v1_add_listener(
        confined_pointer,
        &swl_zwp_confined_pointer_v1_listener_impl,
        (void *)callbacks);
}

#ifdef SWL_ENABLE_TESTING
void swl_test_relative_pointer_listener_emit_relative_motion(
    void *data,
    struct zwp_relative_pointer_v1 *relative_pointer,
    uint32_t utime_hi,
    uint32_t utime_lo,
    int32_t dx,
    int32_t dy,
    int32_t dx_unaccel,
    int32_t dy_unaccel,
    struct swl_test_pointer_capture_listener_record *record)
{
    swl_test_pointer_capture_listener_latest =
        (struct swl_test_pointer_capture_listener_record){0};
    struct swl_zwp_relative_pointer_v1_listener_callbacks callbacks =
        swl_test_relative_pointer_callbacks(data);
    swl_zwp_relative_pointer_v1_handle_relative_motion(
        &callbacks,
        relative_pointer,
        utime_hi,
        utime_lo,
        dx,
        dy,
        dx_unaccel,
        dy_unaccel);
    if (record)
        *record = swl_test_pointer_capture_listener_latest;
}

void swl_test_locked_pointer_listener_emit_locked(
    void *data,
    struct zwp_locked_pointer_v1 *locked_pointer,
    struct swl_test_pointer_capture_listener_record *record)
{
    swl_test_pointer_capture_listener_latest =
        (struct swl_test_pointer_capture_listener_record){0};
    struct swl_zwp_locked_pointer_v1_listener_callbacks callbacks =
        swl_test_locked_pointer_callbacks(data);
    swl_zwp_locked_pointer_v1_handle_locked(&callbacks, locked_pointer);
    if (record)
        *record = swl_test_pointer_capture_listener_latest;
}

void swl_test_locked_pointer_listener_emit_unlocked(
    void *data,
    struct zwp_locked_pointer_v1 *locked_pointer,
    struct swl_test_pointer_capture_listener_record *record)
{
    swl_test_pointer_capture_listener_latest =
        (struct swl_test_pointer_capture_listener_record){0};
    struct swl_zwp_locked_pointer_v1_listener_callbacks callbacks =
        swl_test_locked_pointer_callbacks(data);
    swl_zwp_locked_pointer_v1_handle_unlocked(&callbacks, locked_pointer);
    if (record)
        *record = swl_test_pointer_capture_listener_latest;
}

void swl_test_confined_pointer_listener_emit_confined(
    void *data,
    struct zwp_confined_pointer_v1 *confined_pointer,
    struct swl_test_pointer_capture_listener_record *record)
{
    swl_test_pointer_capture_listener_latest =
        (struct swl_test_pointer_capture_listener_record){0};
    struct swl_zwp_confined_pointer_v1_listener_callbacks callbacks =
        swl_test_confined_pointer_callbacks(data);
    swl_zwp_confined_pointer_v1_handle_confined(&callbacks, confined_pointer);
    if (record)
        *record = swl_test_pointer_capture_listener_latest;
}

void swl_test_confined_pointer_listener_emit_unconfined(
    void *data,
    struct zwp_confined_pointer_v1 *confined_pointer,
    struct swl_test_pointer_capture_listener_record *record)
{
    swl_test_pointer_capture_listener_latest =
        (struct swl_test_pointer_capture_listener_record){0};
    struct swl_zwp_confined_pointer_v1_listener_callbacks callbacks =
        swl_test_confined_pointer_callbacks(data);
    swl_zwp_confined_pointer_v1_handle_unconfined(&callbacks, confined_pointer);
    if (record)
        *record = swl_test_pointer_capture_listener_latest;
}
#endif
