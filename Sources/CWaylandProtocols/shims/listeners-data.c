#include "wayland-client-kit-shims.h"
#include "generated/core/wayland-client-protocol.h"

#ifdef SWL_ENABLE_TESTING
static struct swl_test_data_offer_offer_record
    swl_test_data_offer_offer_latest;
static struct swl_test_data_offer_action_record
    swl_test_data_offer_action_latest;
static struct swl_test_data_source_send_record
    swl_test_data_source_send_latest;
static struct swl_test_data_source_lifecycle_record
    swl_test_data_source_lifecycle_latest;
static struct swl_test_data_source_action_record
    swl_test_data_source_action_latest;
static struct swl_test_data_device_offer_record
    swl_test_data_device_offer_latest;
static struct swl_test_data_device_enter_record
    swl_test_data_device_enter_latest;
static struct swl_test_data_device_motion_record
    swl_test_data_device_motion_latest;
static struct swl_test_data_device_lifecycle_record
    swl_test_data_device_lifecycle_latest;

static void swl_test_record_data_offer_offer(
    void *data,
    struct wl_data_offer *offer,
    const char *mime_type)
{
    swl_test_data_offer_offer_latest.call_count += 1;
    swl_test_data_offer_offer_latest.data = data;
    swl_test_data_offer_offer_latest.offer = offer;
    swl_test_data_offer_offer_latest.mime_type = mime_type;
}

static void swl_test_record_data_offer_action(
    void *data,
    struct wl_data_offer *offer,
    uint32_t action)
{
    swl_test_data_offer_action_latest.call_count += 1;
    swl_test_data_offer_action_latest.data = data;
    swl_test_data_offer_action_latest.offer = offer;
    swl_test_data_offer_action_latest.action = action;
}

static void swl_test_record_data_source_send(
    void *data,
    struct wl_data_source *source,
    const char *mime_type,
    int32_t fd)
{
    swl_test_data_source_send_latest.call_count += 1;
    swl_test_data_source_send_latest.data = data;
    swl_test_data_source_send_latest.source = source;
    swl_test_data_source_send_latest.mime_type = mime_type;
    swl_test_data_source_send_latest.fd = fd;
}

static void swl_test_record_data_source_target(
    void *data,
    struct wl_data_source *source,
    const char *mime_type)
{
    swl_test_record_data_source_send(data, source, mime_type, -1);
}

static void swl_test_record_data_source_lifecycle(
    void *data,
    struct wl_data_source *source)
{
    swl_test_data_source_lifecycle_latest.call_count += 1;
    swl_test_data_source_lifecycle_latest.data = data;
    swl_test_data_source_lifecycle_latest.source = source;
}

static void swl_test_record_data_source_action(
    void *data,
    struct wl_data_source *source,
    uint32_t action)
{
    swl_test_data_source_action_latest.call_count += 1;
    swl_test_data_source_action_latest.data = data;
    swl_test_data_source_action_latest.source = source;
    swl_test_data_source_action_latest.action = action;
}

static void swl_test_record_data_device_offer(
    void *data,
    struct wl_data_device *device,
    struct wl_data_offer *offer)
{
    swl_test_data_device_offer_latest.call_count += 1;
    swl_test_data_device_offer_latest.data = data;
    swl_test_data_device_offer_latest.device = device;
    swl_test_data_device_offer_latest.offer = offer;
}

static void swl_test_record_data_device_enter(
    void *data,
    struct wl_data_device *device,
    uint32_t serial,
    struct wl_surface *surface,
    wl_fixed_t x,
    wl_fixed_t y,
    struct wl_data_offer *offer)
{
    swl_test_data_device_enter_latest.call_count += 1;
    swl_test_data_device_enter_latest.data = data;
    swl_test_data_device_enter_latest.device = device;
    swl_test_data_device_enter_latest.serial = serial;
    swl_test_data_device_enter_latest.surface = surface;
    swl_test_data_device_enter_latest.x = x;
    swl_test_data_device_enter_latest.y = y;
    swl_test_data_device_enter_latest.offer = offer;
}

static void swl_test_record_data_device_motion(
    void *data,
    struct wl_data_device *device,
    uint32_t time,
    wl_fixed_t x,
    wl_fixed_t y)
{
    swl_test_data_device_motion_latest.call_count += 1;
    swl_test_data_device_motion_latest.data = data;
    swl_test_data_device_motion_latest.device = device;
    swl_test_data_device_motion_latest.time = time;
    swl_test_data_device_motion_latest.x = x;
    swl_test_data_device_motion_latest.y = y;
}

static void swl_test_record_data_device_lifecycle(
    void *data,
    struct wl_data_device *device)
{
    swl_test_data_device_lifecycle_latest.call_count += 1;
    swl_test_data_device_lifecycle_latest.data = data;
    swl_test_data_device_lifecycle_latest.device = device;
}

void swl_test_data_offer_listener_emit_offer(
    void *data,
    struct wl_data_offer *offer,
    const char *mime_type,
    struct swl_test_data_offer_offer_record *record)
{
    swl_test_data_offer_offer_latest =
        (struct swl_test_data_offer_offer_record){0};

    const struct swl_data_offer_listener_callbacks callbacks = {
        .offer = swl_test_record_data_offer_offer,
        .data = data,
    };

    callbacks.offer(callbacks.data, offer, mime_type);

    if (record)
        *record = swl_test_data_offer_offer_latest;
}

void swl_test_data_offer_listener_emit_source_actions(
    void *data,
    struct wl_data_offer *offer,
    uint32_t source_actions,
    struct swl_test_data_offer_action_record *record)
{
    swl_test_data_offer_action_latest =
        (struct swl_test_data_offer_action_record){0};

    const struct swl_data_offer_listener_callbacks callbacks = {
        .source_actions = swl_test_record_data_offer_action,
        .data = data,
    };

    callbacks.source_actions(callbacks.data, offer, source_actions);

    if (record)
        *record = swl_test_data_offer_action_latest;
}

void swl_test_data_offer_listener_emit_action(
    void *data,
    struct wl_data_offer *offer,
    uint32_t action,
    struct swl_test_data_offer_action_record *record)
{
    swl_test_data_offer_action_latest =
        (struct swl_test_data_offer_action_record){0};

    const struct swl_data_offer_listener_callbacks callbacks = {
        .action = swl_test_record_data_offer_action,
        .data = data,
    };

    callbacks.action(callbacks.data, offer, action);

    if (record)
        *record = swl_test_data_offer_action_latest;
}

void swl_test_data_source_listener_emit_target(
    void *data,
    struct wl_data_source *source,
    const char *mime_type,
    struct swl_test_data_source_send_record *record)
{
    swl_test_data_source_send_latest =
        (struct swl_test_data_source_send_record){0};

    const struct swl_data_source_listener_callbacks callbacks = {
        .target = swl_test_record_data_source_target,
        .data = data,
    };

    callbacks.target(callbacks.data, source, mime_type);

    if (record)
        *record = swl_test_data_source_send_latest;
}

void swl_test_data_source_listener_emit_send(
    void *data,
    struct wl_data_source *source,
    const char *mime_type,
    int32_t fd,
    struct swl_test_data_source_send_record *record)
{
    swl_test_data_source_send_latest =
        (struct swl_test_data_source_send_record){0};

    const struct swl_data_source_listener_callbacks callbacks = {
        .send = swl_test_record_data_source_send,
        .data = data,
    };

    callbacks.send(callbacks.data, source, mime_type, fd);

    if (record)
        *record = swl_test_data_source_send_latest;
}

void swl_test_data_source_listener_emit_cancelled(
    void *data,
    struct wl_data_source *source,
    struct swl_test_data_source_lifecycle_record *record)
{
    swl_test_data_source_lifecycle_latest =
        (struct swl_test_data_source_lifecycle_record){0};

    const struct swl_data_source_listener_callbacks callbacks = {
        .cancelled = swl_test_record_data_source_lifecycle,
        .data = data,
    };

    callbacks.cancelled(callbacks.data, source);

    if (record)
        *record = swl_test_data_source_lifecycle_latest;
}

void swl_test_data_source_listener_emit_dnd_drop_performed(
    void *data,
    struct wl_data_source *source,
    struct swl_test_data_source_lifecycle_record *record)
{
    swl_test_data_source_lifecycle_latest =
        (struct swl_test_data_source_lifecycle_record){0};

    const struct swl_data_source_listener_callbacks callbacks = {
        .dnd_drop_performed = swl_test_record_data_source_lifecycle,
        .data = data,
    };

    callbacks.dnd_drop_performed(callbacks.data, source);

    if (record)
        *record = swl_test_data_source_lifecycle_latest;
}

void swl_test_data_source_listener_emit_dnd_finished(
    void *data,
    struct wl_data_source *source,
    struct swl_test_data_source_lifecycle_record *record)
{
    swl_test_data_source_lifecycle_latest =
        (struct swl_test_data_source_lifecycle_record){0};

    const struct swl_data_source_listener_callbacks callbacks = {
        .dnd_finished = swl_test_record_data_source_lifecycle,
        .data = data,
    };

    callbacks.dnd_finished(callbacks.data, source);

    if (record)
        *record = swl_test_data_source_lifecycle_latest;
}

void swl_test_data_source_listener_emit_action(
    void *data,
    struct wl_data_source *source,
    uint32_t action,
    struct swl_test_data_source_action_record *record)
{
    swl_test_data_source_action_latest =
        (struct swl_test_data_source_action_record){0};

    const struct swl_data_source_listener_callbacks callbacks = {
        .action = swl_test_record_data_source_action,
        .data = data,
    };

    callbacks.action(callbacks.data, source, action);

    if (record)
        *record = swl_test_data_source_action_latest;
}

void swl_test_data_device_listener_emit_data_offer(
    void *data,
    struct wl_data_device *device,
    struct wl_data_offer *offer,
    struct swl_test_data_device_offer_record *record)
{
    swl_test_data_device_offer_latest =
        (struct swl_test_data_device_offer_record){0};

    const struct swl_data_device_listener_callbacks callbacks = {
        .data_offer = swl_test_record_data_device_offer,
        .data = data,
    };

    callbacks.data_offer(callbacks.data, device, offer);

    if (record)
        *record = swl_test_data_device_offer_latest;
}

void swl_test_data_device_listener_emit_enter(
    void *data,
    struct wl_data_device *device,
    uint32_t serial,
    struct wl_surface *surface,
    wl_fixed_t x,
    wl_fixed_t y,
    struct wl_data_offer *offer,
    struct swl_test_data_device_enter_record *record)
{
    swl_test_data_device_enter_latest =
        (struct swl_test_data_device_enter_record){0};

    const struct swl_data_device_listener_callbacks callbacks = {
        .enter = swl_test_record_data_device_enter,
        .data = data,
    };

    callbacks.enter(callbacks.data, device, serial, surface, x, y, offer);

    if (record)
        *record = swl_test_data_device_enter_latest;
}

void swl_test_data_device_listener_emit_leave(
    void *data,
    struct wl_data_device *device,
    struct swl_test_data_device_lifecycle_record *record)
{
    swl_test_data_device_lifecycle_latest =
        (struct swl_test_data_device_lifecycle_record){0};

    const struct swl_data_device_listener_callbacks callbacks = {
        .leave = swl_test_record_data_device_lifecycle,
        .data = data,
    };

    callbacks.leave(callbacks.data, device);

    if (record)
        *record = swl_test_data_device_lifecycle_latest;
}

void swl_test_data_device_listener_emit_motion(
    void *data,
    struct wl_data_device *device,
    uint32_t time,
    wl_fixed_t x,
    wl_fixed_t y,
    struct swl_test_data_device_motion_record *record)
{
    swl_test_data_device_motion_latest =
        (struct swl_test_data_device_motion_record){0};

    const struct swl_data_device_listener_callbacks callbacks = {
        .motion = swl_test_record_data_device_motion,
        .data = data,
    };

    callbacks.motion(callbacks.data, device, time, x, y);

    if (record)
        *record = swl_test_data_device_motion_latest;
}

void swl_test_data_device_listener_emit_drop(
    void *data,
    struct wl_data_device *device,
    struct swl_test_data_device_lifecycle_record *record)
{
    swl_test_data_device_lifecycle_latest =
        (struct swl_test_data_device_lifecycle_record){0};

    const struct swl_data_device_listener_callbacks callbacks = {
        .drop = swl_test_record_data_device_lifecycle,
        .data = data,
    };

    callbacks.drop(callbacks.data, device);

    if (record)
        *record = swl_test_data_device_lifecycle_latest;
}

void swl_test_data_device_listener_emit_selection(
    void *data,
    struct wl_data_device *device,
    struct wl_data_offer *offer,
    struct swl_test_data_device_offer_record *record)
{
    swl_test_data_device_offer_latest =
        (struct swl_test_data_device_offer_record){0};

    const struct swl_data_device_listener_callbacks callbacks = {
        .selection = swl_test_record_data_device_offer,
        .data = data,
    };

    callbacks.selection(callbacks.data, device, offer);

    if (record)
        *record = swl_test_data_device_offer_latest;
}
#endif
