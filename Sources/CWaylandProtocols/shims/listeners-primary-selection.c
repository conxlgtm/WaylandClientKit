#include "wayland-client-kit-shims.h"
#include "generated/legacy-unstable/primary-selection/primary-selection-unstable-v1-client-protocol.h"

/*
 * zwp_primary_selection_offer_v1 listener bridge
 */

static void swl_primary_selection_offer_handle_offer(
    void *data,
    struct zwp_primary_selection_offer_v1 *offer,
    const char *mime_type)
{
    const struct swl_primary_selection_offer_listener_callbacks *cb = data;
    if (cb && cb->offer)
        cb->offer(cb->data, offer, mime_type);
}

static const struct zwp_primary_selection_offer_v1_listener
    swl_primary_selection_offer_listener_impl = {
        .offer = swl_primary_selection_offer_handle_offer,
    };

int swl_primary_selection_offer_add_listener(
    struct zwp_primary_selection_offer_v1 *offer,
    const struct swl_primary_selection_offer_listener_callbacks *callbacks)
{
    return zwp_primary_selection_offer_v1_add_listener(
        offer, &swl_primary_selection_offer_listener_impl, (void *)callbacks);
}

/*
 * zwp_primary_selection_source_v1 listener bridge
 */

static void swl_primary_selection_source_handle_send(
    void *data,
    struct zwp_primary_selection_source_v1 *source,
    const char *mime_type,
    int32_t fd)
{
    const struct swl_primary_selection_source_listener_callbacks *cb = data;
    if (cb && cb->send)
        cb->send(cb->data, source, mime_type, fd);
}

static void swl_primary_selection_source_handle_cancelled(
    void *data,
    struct zwp_primary_selection_source_v1 *source)
{
    const struct swl_primary_selection_source_listener_callbacks *cb = data;
    if (cb && cb->cancelled)
        cb->cancelled(cb->data, source);
}

static const struct zwp_primary_selection_source_v1_listener
    swl_primary_selection_source_listener_impl = {
        .send      = swl_primary_selection_source_handle_send,
        .cancelled = swl_primary_selection_source_handle_cancelled,
    };

int swl_primary_selection_source_add_listener(
    struct zwp_primary_selection_source_v1 *source,
    const struct swl_primary_selection_source_listener_callbacks *callbacks)
{
    return zwp_primary_selection_source_v1_add_listener(
        source, &swl_primary_selection_source_listener_impl, (void *)callbacks);
}

/*
 * zwp_primary_selection_device_v1 listener bridge
 */

static void swl_primary_selection_device_handle_data_offer(
    void *data,
    struct zwp_primary_selection_device_v1 *device,
    struct zwp_primary_selection_offer_v1 *offer)
{
    const struct swl_primary_selection_device_listener_callbacks *cb = data;
    if (cb && cb->data_offer)
        cb->data_offer(cb->data, device, offer);
}

static void swl_primary_selection_device_handle_selection(
    void *data,
    struct zwp_primary_selection_device_v1 *device,
    struct zwp_primary_selection_offer_v1 *offer)
{
    const struct swl_primary_selection_device_listener_callbacks *cb = data;
    if (cb && cb->selection)
        cb->selection(cb->data, device, offer);
}

static const struct zwp_primary_selection_device_v1_listener
    swl_primary_selection_device_listener_impl = {
        .data_offer = swl_primary_selection_device_handle_data_offer,
        .selection  = swl_primary_selection_device_handle_selection,
    };

int swl_primary_selection_device_add_listener(
    struct zwp_primary_selection_device_v1 *device,
    const struct swl_primary_selection_device_listener_callbacks *callbacks)
{
    return zwp_primary_selection_device_v1_add_listener(
        device, &swl_primary_selection_device_listener_impl, (void *)callbacks);
}

#ifdef SWL_ENABLE_TESTING
static struct swl_test_primary_selection_offer_offer_record
    swl_test_primary_selection_offer_offer_latest;
static struct swl_test_primary_selection_source_send_record
    swl_test_primary_selection_source_send_latest;
static struct swl_test_primary_selection_source_lifecycle_record
    swl_test_primary_selection_source_lifecycle_latest;
static struct swl_test_primary_selection_device_offer_record
    swl_test_primary_selection_device_offer_latest;

static void swl_test_record_primary_selection_offer_offer(
    void *data,
    struct zwp_primary_selection_offer_v1 *offer,
    const char *mime_type)
{
    swl_test_primary_selection_offer_offer_latest.call_count += 1;
    swl_test_primary_selection_offer_offer_latest.data = data;
    swl_test_primary_selection_offer_offer_latest.offer = offer;
    swl_test_primary_selection_offer_offer_latest.mime_type = mime_type;
}

static void swl_test_record_primary_selection_source_send(
    void *data,
    struct zwp_primary_selection_source_v1 *source,
    const char *mime_type,
    int32_t fd)
{
    swl_test_primary_selection_source_send_latest.call_count += 1;
    swl_test_primary_selection_source_send_latest.data = data;
    swl_test_primary_selection_source_send_latest.source = source;
    swl_test_primary_selection_source_send_latest.mime_type = mime_type;
    swl_test_primary_selection_source_send_latest.fd = fd;
}

static void swl_test_record_primary_selection_source_cancelled(
    void *data,
    struct zwp_primary_selection_source_v1 *source)
{
    swl_test_primary_selection_source_lifecycle_latest.call_count += 1;
    swl_test_primary_selection_source_lifecycle_latest.data = data;
    swl_test_primary_selection_source_lifecycle_latest.source = source;
}

static void swl_test_record_primary_selection_device_offer(
    void *data,
    struct zwp_primary_selection_device_v1 *device,
    struct zwp_primary_selection_offer_v1 *offer)
{
    swl_test_primary_selection_device_offer_latest.call_count += 1;
    swl_test_primary_selection_device_offer_latest.data = data;
    swl_test_primary_selection_device_offer_latest.device = device;
    swl_test_primary_selection_device_offer_latest.offer = offer;
}

void swl_test_primary_selection_offer_listener_emit_offer(
    void *data,
    struct zwp_primary_selection_offer_v1 *offer,
    const char *mime_type,
    struct swl_test_primary_selection_offer_offer_record *record)
{
    swl_test_primary_selection_offer_offer_latest =
        (struct swl_test_primary_selection_offer_offer_record){0};

    const struct swl_primary_selection_offer_listener_callbacks callbacks = {
        .offer = swl_test_record_primary_selection_offer_offer,
        .data = data,
    };

    swl_primary_selection_offer_handle_offer(
        (void *)&callbacks, offer, mime_type);

    if (record)
        *record = swl_test_primary_selection_offer_offer_latest;
}

void swl_test_primary_selection_source_listener_emit_send(
    void *data,
    struct zwp_primary_selection_source_v1 *source,
    const char *mime_type,
    int32_t fd,
    struct swl_test_primary_selection_source_send_record *record)
{
    swl_test_primary_selection_source_send_latest =
        (struct swl_test_primary_selection_source_send_record){0};

    const struct swl_primary_selection_source_listener_callbacks callbacks = {
        .send = swl_test_record_primary_selection_source_send,
        .data = data,
    };

    swl_primary_selection_source_handle_send(
        (void *)&callbacks, source, mime_type, fd);

    if (record)
        *record = swl_test_primary_selection_source_send_latest;
}

void swl_test_primary_selection_source_listener_emit_cancelled(
    void *data,
    struct zwp_primary_selection_source_v1 *source,
    struct swl_test_primary_selection_source_lifecycle_record *record)
{
    swl_test_primary_selection_source_lifecycle_latest =
        (struct swl_test_primary_selection_source_lifecycle_record){0};

    const struct swl_primary_selection_source_listener_callbacks callbacks = {
        .cancelled = swl_test_record_primary_selection_source_cancelled,
        .data = data,
    };

    swl_primary_selection_source_handle_cancelled((void *)&callbacks, source);

    if (record)
        *record = swl_test_primary_selection_source_lifecycle_latest;
}

void swl_test_primary_selection_device_listener_emit_data_offer(
    void *data,
    struct zwp_primary_selection_device_v1 *device,
    struct zwp_primary_selection_offer_v1 *offer,
    struct swl_test_primary_selection_device_offer_record *record)
{
    swl_test_primary_selection_device_offer_latest =
        (struct swl_test_primary_selection_device_offer_record){0};

    const struct swl_primary_selection_device_listener_callbacks callbacks = {
        .data_offer = swl_test_record_primary_selection_device_offer,
        .data = data,
    };

    swl_primary_selection_device_handle_data_offer(
        (void *)&callbacks, device, offer);

    if (record)
        *record = swl_test_primary_selection_device_offer_latest;
}

void swl_test_primary_selection_device_listener_emit_selection(
    void *data,
    struct zwp_primary_selection_device_v1 *device,
    struct zwp_primary_selection_offer_v1 *offer,
    struct swl_test_primary_selection_device_offer_record *record)
{
    swl_test_primary_selection_device_offer_latest =
        (struct swl_test_primary_selection_device_offer_record){0};

    const struct swl_primary_selection_device_listener_callbacks callbacks = {
        .selection = swl_test_record_primary_selection_device_offer,
        .data = data,
    };

    swl_primary_selection_device_handle_selection(
        (void *)&callbacks, device, offer);

    if (record)
        *record = swl_test_primary_selection_device_offer_latest;
}
#endif
