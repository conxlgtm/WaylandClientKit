#include "swift-wayland-shims.h"
#include "generated/wayland-client-protocol.h"

/*
 * wl_data_offer listener bridge
 */

static void swl_data_offer_handle_offer(
    void *data,
    struct wl_data_offer *offer,
    const char *mime_type)
{
    const struct swl_data_offer_listener_callbacks *cb = data;
    if (cb && cb->offer)
        cb->offer(cb->data, offer, mime_type);
}

static void swl_data_offer_handle_source_actions(
    void *data,
    struct wl_data_offer *offer,
    uint32_t source_actions)
{
    const struct swl_data_offer_listener_callbacks *cb = data;
    if (cb && cb->source_actions)
        cb->source_actions(cb->data, offer, source_actions);
}

static void swl_data_offer_handle_action(
    void *data,
    struct wl_data_offer *offer,
    uint32_t action)
{
    const struct swl_data_offer_listener_callbacks *cb = data;
    if (cb && cb->action)
        cb->action(cb->data, offer, action);
}

static const struct wl_data_offer_listener swl_data_offer_listener_impl = {
    .offer          = swl_data_offer_handle_offer,
    .source_actions = swl_data_offer_handle_source_actions,
    .action         = swl_data_offer_handle_action,
};

int swl_data_offer_add_listener(
    struct wl_data_offer *offer,
    const struct swl_data_offer_listener_callbacks *callbacks)
{
    return wl_data_offer_add_listener(
        offer, &swl_data_offer_listener_impl, (void *)callbacks);
}

/*
 * wl_data_source listener bridge
 */

static void swl_data_source_handle_target(
    void *data,
    struct wl_data_source *source,
    const char *mime_type)
{
    const struct swl_data_source_listener_callbacks *cb = data;
    if (cb && cb->target)
        cb->target(cb->data, source, mime_type);
}

static void swl_data_source_handle_send(
    void *data,
    struct wl_data_source *source,
    const char *mime_type,
    int32_t fd)
{
    const struct swl_data_source_listener_callbacks *cb = data;
    if (cb && cb->send)
        cb->send(cb->data, source, mime_type, fd);
}

static void swl_data_source_handle_cancelled(
    void *data,
    struct wl_data_source *source)
{
    const struct swl_data_source_listener_callbacks *cb = data;
    if (cb && cb->cancelled)
        cb->cancelled(cb->data, source);
}

static void swl_data_source_handle_dnd_drop_performed(
    void *data,
    struct wl_data_source *source)
{
    const struct swl_data_source_listener_callbacks *cb = data;
    if (cb && cb->dnd_drop_performed)
        cb->dnd_drop_performed(cb->data, source);
}

static void swl_data_source_handle_dnd_finished(
    void *data,
    struct wl_data_source *source)
{
    const struct swl_data_source_listener_callbacks *cb = data;
    if (cb && cb->dnd_finished)
        cb->dnd_finished(cb->data, source);
}

static void swl_data_source_handle_action(
    void *data,
    struct wl_data_source *source,
    uint32_t action)
{
    const struct swl_data_source_listener_callbacks *cb = data;
    if (cb && cb->action)
        cb->action(cb->data, source, action);
}

static const struct wl_data_source_listener swl_data_source_listener_impl = {
    .target             = swl_data_source_handle_target,
    .send               = swl_data_source_handle_send,
    .cancelled          = swl_data_source_handle_cancelled,
    .dnd_drop_performed = swl_data_source_handle_dnd_drop_performed,
    .dnd_finished       = swl_data_source_handle_dnd_finished,
    .action             = swl_data_source_handle_action,
};

int swl_data_source_add_listener(
    struct wl_data_source *source,
    const struct swl_data_source_listener_callbacks *callbacks)
{
    return wl_data_source_add_listener(
        source, &swl_data_source_listener_impl, (void *)callbacks);
}

/*
 * wl_data_device listener bridge
 */

static void swl_data_device_handle_data_offer(
    void *data,
    struct wl_data_device *device,
    struct wl_data_offer *offer)
{
    const struct swl_data_device_listener_callbacks *cb = data;
    if (cb && cb->data_offer)
        cb->data_offer(cb->data, device, offer);
}

static void swl_data_device_handle_enter(
    void *data,
    struct wl_data_device *device,
    uint32_t serial,
    struct wl_surface *surface,
    wl_fixed_t x,
    wl_fixed_t y,
    struct wl_data_offer *offer)
{
    const struct swl_data_device_listener_callbacks *cb = data;
    if (cb && cb->enter)
        cb->enter(cb->data, device, serial, surface, x, y, offer);
}

static void swl_data_device_handle_leave(
    void *data,
    struct wl_data_device *device)
{
    const struct swl_data_device_listener_callbacks *cb = data;
    if (cb && cb->leave)
        cb->leave(cb->data, device);
}

static void swl_data_device_handle_motion(
    void *data,
    struct wl_data_device *device,
    uint32_t time,
    wl_fixed_t x,
    wl_fixed_t y)
{
    const struct swl_data_device_listener_callbacks *cb = data;
    if (cb && cb->motion)
        cb->motion(cb->data, device, time, x, y);
}

static void swl_data_device_handle_drop(
    void *data,
    struct wl_data_device *device)
{
    const struct swl_data_device_listener_callbacks *cb = data;
    if (cb && cb->drop)
        cb->drop(cb->data, device);
}

static void swl_data_device_handle_selection(
    void *data,
    struct wl_data_device *device,
    struct wl_data_offer *offer)
{
    const struct swl_data_device_listener_callbacks *cb = data;
    if (cb && cb->selection)
        cb->selection(cb->data, device, offer);
}

static const struct wl_data_device_listener swl_data_device_listener_impl = {
    .data_offer = swl_data_device_handle_data_offer,
    .enter      = swl_data_device_handle_enter,
    .leave      = swl_data_device_handle_leave,
    .motion     = swl_data_device_handle_motion,
    .drop       = swl_data_device_handle_drop,
    .selection  = swl_data_device_handle_selection,
};

int swl_data_device_add_listener(
    struct wl_data_device *device,
    const struct swl_data_device_listener_callbacks *callbacks)
{
    return wl_data_device_add_listener(
        device, &swl_data_device_listener_impl, (void *)callbacks);
}

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

    swl_data_offer_handle_offer((void *)&callbacks, offer, mime_type);

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

    swl_data_offer_handle_source_actions((void *)&callbacks, offer, source_actions);

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

    swl_data_offer_handle_action((void *)&callbacks, offer, action);

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

    swl_data_source_handle_target((void *)&callbacks, source, mime_type);

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

    swl_data_source_handle_send((void *)&callbacks, source, mime_type, fd);

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

    swl_data_source_handle_cancelled((void *)&callbacks, source);

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

    swl_data_source_handle_dnd_drop_performed((void *)&callbacks, source);

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

    swl_data_source_handle_dnd_finished((void *)&callbacks, source);

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

    swl_data_source_handle_action((void *)&callbacks, source, action);

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

    swl_data_device_handle_data_offer((void *)&callbacks, device, offer);

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

    swl_data_device_handle_enter(
        (void *)&callbacks, device, serial, surface, x, y, offer);

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

    swl_data_device_handle_leave((void *)&callbacks, device);

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

    swl_data_device_handle_motion((void *)&callbacks, device, time, x, y);

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

    swl_data_device_handle_drop((void *)&callbacks, device);

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

    swl_data_device_handle_selection((void *)&callbacks, device, offer);

    if (record)
        *record = swl_test_data_device_offer_latest;
}
#endif
