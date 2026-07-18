#include "wayland-client-kit-shims.h"
#include "generated/legacy-unstable/keyboard-shortcuts-inhibit/keyboard-shortcuts-inhibit-unstable-v1-client-protocol.h"
#include "generated/legacy-unstable/relative-pointer/relative-pointer-unstable-v1-client-protocol.h"
#include "generated/legacy-unstable/pointer-constraints/pointer-constraints-unstable-v1-client-protocol.h"

#ifdef SWL_ENABLE_TESTING
static struct swl_test_pointer_capture_listener_record
    swl_test_pointer_capture_listener_latest;
static int swl_test_keyboard_shortcuts_inhibitor_listener_add_result;

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
    callbacks.relative_motion(
        callbacks.data,
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
    callbacks.locked(callbacks.data, locked_pointer);
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
    callbacks.unlocked(callbacks.data, locked_pointer);
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
    callbacks.confined(callbacks.data, confined_pointer);
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
    callbacks.unconfined(callbacks.data, confined_pointer);
    if (record)
        *record = swl_test_pointer_capture_listener_latest;
}
#endif

static void swl_zwp_keyboard_shortcuts_inhibitor_v1_handle_active(
    void *data,
    struct zwp_keyboard_shortcuts_inhibitor_v1 *inhibitor)
{
    const struct
        swl_zwp_keyboard_shortcuts_inhibitor_v1_listener_callbacks *cb = data;
    if (cb && cb->active)
        cb->active(cb->data, inhibitor);
}

static void swl_zwp_keyboard_shortcuts_inhibitor_v1_handle_inactive(
    void *data,
    struct zwp_keyboard_shortcuts_inhibitor_v1 *inhibitor)
{
    const struct
        swl_zwp_keyboard_shortcuts_inhibitor_v1_listener_callbacks *cb = data;
    if (cb && cb->inactive)
        cb->inactive(cb->data, inhibitor);
}

static const struct zwp_keyboard_shortcuts_inhibitor_v1_listener
    swl_zwp_keyboard_shortcuts_inhibitor_v1_listener_impl = {
        .active = swl_zwp_keyboard_shortcuts_inhibitor_v1_handle_active,
        .inactive = swl_zwp_keyboard_shortcuts_inhibitor_v1_handle_inactive,
    };

int swl_zwp_keyboard_shortcuts_inhibitor_v1_add_listener(
    struct zwp_keyboard_shortcuts_inhibitor_v1 *inhibitor,
    const struct
        swl_zwp_keyboard_shortcuts_inhibitor_v1_listener_callbacks *callbacks)
{
#ifdef SWL_ENABLE_TESTING
    if (swl_test_keyboard_shortcuts_inhibitor_listener_add_result)
        return swl_test_keyboard_shortcuts_inhibitor_listener_add_result;
#endif
    return zwp_keyboard_shortcuts_inhibitor_v1_add_listener(
        inhibitor,
        &swl_zwp_keyboard_shortcuts_inhibitor_v1_listener_impl,
        (void *)callbacks);
}

#ifdef SWL_ENABLE_TESTING
static void swl_test_record_keyboard_shortcuts_active(
    void *data,
    struct zwp_keyboard_shortcuts_inhibitor_v1 *inhibitor)
{
    swl_test_pointer_capture_listener_latest.call_count += 1;
    swl_test_pointer_capture_listener_latest.kind =
        SWL_TEST_POINTER_CAPTURE_LISTENER_SHORTCUTS_ACTIVE;
    swl_test_pointer_capture_listener_latest.data = data;
    swl_test_pointer_capture_listener_latest.object = inhibitor;
}

static void swl_test_record_keyboard_shortcuts_inactive(
    void *data,
    struct zwp_keyboard_shortcuts_inhibitor_v1 *inhibitor)
{
    swl_test_pointer_capture_listener_latest.call_count += 1;
    swl_test_pointer_capture_listener_latest.kind =
        SWL_TEST_POINTER_CAPTURE_LISTENER_SHORTCUTS_INACTIVE;
    swl_test_pointer_capture_listener_latest.data = data;
    swl_test_pointer_capture_listener_latest.object = inhibitor;
}

static struct swl_zwp_keyboard_shortcuts_inhibitor_v1_listener_callbacks
swl_test_keyboard_shortcuts_inhibitor_callbacks(void *data)
{
    return (struct
            swl_zwp_keyboard_shortcuts_inhibitor_v1_listener_callbacks){
        .active = swl_test_record_keyboard_shortcuts_active,
        .inactive = swl_test_record_keyboard_shortcuts_inactive,
        .data = data,
    };
}

void swl_test_keyboard_shortcuts_inhibitor_listener_emit_active(
    void *data,
    struct zwp_keyboard_shortcuts_inhibitor_v1 *inhibitor,
    struct swl_test_pointer_capture_listener_record *record)
{
    swl_test_pointer_capture_listener_latest =
        (struct swl_test_pointer_capture_listener_record){0};
    struct swl_zwp_keyboard_shortcuts_inhibitor_v1_listener_callbacks
        callbacks = swl_test_keyboard_shortcuts_inhibitor_callbacks(data);
    swl_zwp_keyboard_shortcuts_inhibitor_v1_handle_active(
        &callbacks,
        inhibitor);
    if (record)
        *record = swl_test_pointer_capture_listener_latest;
}

void swl_test_keyboard_shortcuts_inhibitor_listener_emit_inactive(
    void *data,
    struct zwp_keyboard_shortcuts_inhibitor_v1 *inhibitor,
    struct swl_test_pointer_capture_listener_record *record)
{
    swl_test_pointer_capture_listener_latest =
        (struct swl_test_pointer_capture_listener_record){0};
    struct swl_zwp_keyboard_shortcuts_inhibitor_v1_listener_callbacks
        callbacks = swl_test_keyboard_shortcuts_inhibitor_callbacks(data);
    swl_zwp_keyboard_shortcuts_inhibitor_v1_handle_inactive(
        &callbacks,
        inhibitor);
    if (record)
        *record = swl_test_pointer_capture_listener_latest;
}

void swl_test_keyboard_shortcuts_inhibitor_listener_set_add_result(int result)
{
    swl_test_keyboard_shortcuts_inhibitor_listener_add_result = result;
}
#endif
