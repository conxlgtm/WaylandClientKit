#include "swift-wayland-shims.h"
#include "generated/staging/color-representation/color-representation-v1-client-protocol.h"
#include "generated/staging/color-management/color-management-v1-client-protocol.h"

#ifdef SWL_ENABLE_TESTING
static struct swl_test_metadata_listener_record
    swl_test_metadata_listener_latest;
static struct wp_color_representation_manager_v1
    *swl_test_color_representation_manager_latest;
static const struct swl_wp_color_representation_manager_v1_listener_callbacks
    *swl_test_color_representation_callbacks_latest;
static struct wp_image_description_v1 *swl_test_image_description_latest;
static const struct swl_wp_image_description_v1_listener_callbacks
    *swl_test_image_description_callbacks_latest;

static int swl_wp_color_representation_manager_v1_add_listener_default(
    struct wp_color_representation_manager_v1 *manager,
    const struct swl_wp_color_representation_manager_v1_listener_callbacks *callbacks);
static int swl_wp_color_manager_v1_add_listener_default(
    struct wp_color_manager_v1 *manager,
    const struct swl_wp_color_manager_v1_listener_callbacks *callbacks);
static int swl_wp_image_description_v1_add_listener_default(
    struct wp_image_description_v1 *image_description,
    const struct swl_wp_image_description_v1_listener_callbacks *callbacks);

static int (*swl_wp_color_representation_manager_v1_add_listener_impl)(
    struct wp_color_representation_manager_v1 *manager,
    const struct swl_wp_color_representation_manager_v1_listener_callbacks *callbacks) =
        swl_wp_color_representation_manager_v1_add_listener_default;
static int (*swl_wp_color_manager_v1_add_listener_impl)(
    struct wp_color_manager_v1 *manager,
    const struct swl_wp_color_manager_v1_listener_callbacks *callbacks) =
        swl_wp_color_manager_v1_add_listener_default;
static int (*swl_wp_image_description_v1_add_listener_impl)(
    struct wp_image_description_v1 *image_description,
    const struct swl_wp_image_description_v1_listener_callbacks *callbacks) =
        swl_wp_image_description_v1_add_listener_default;

static int swl_test_color_representation_manager_add_listener_record(
    struct wp_color_representation_manager_v1 *manager,
    const struct swl_wp_color_representation_manager_v1_listener_callbacks *callbacks)
{
    swl_test_metadata_listener_latest.call_count += 1;
    swl_test_metadata_listener_latest.object = manager;
    swl_test_color_representation_manager_latest = manager;
    swl_test_color_representation_callbacks_latest = callbacks;
    return 0;
}

static int swl_test_color_manager_add_listener_record(
    struct wp_color_manager_v1 *manager,
    const struct swl_wp_color_manager_v1_listener_callbacks *callbacks)
{
    (void)callbacks;
    swl_test_metadata_listener_latest.call_count += 1;
    swl_test_metadata_listener_latest.object = manager;
    return 0;
}

static int swl_test_image_description_add_listener_record(
    struct wp_image_description_v1 *image_description,
    const struct swl_wp_image_description_v1_listener_callbacks *callbacks)
{
    swl_test_metadata_listener_latest.call_count += 1;
    swl_test_metadata_listener_latest.object = image_description;
    swl_test_image_description_latest = image_description;
    swl_test_image_description_callbacks_latest = callbacks;
    return 0;
}
#endif

static void swl_wp_color_representation_manager_v1_handle_supported_alpha_mode(
    void *data,
    struct wp_color_representation_manager_v1 *manager,
    uint32_t alpha_mode)
{
    const struct swl_wp_color_representation_manager_v1_listener_callbacks *cb =
        data;
    if (cb && cb->supported_alpha_mode)
        cb->supported_alpha_mode(cb->data, manager, alpha_mode);
}

static void
swl_wp_color_representation_manager_v1_handle_supported_coefficients_and_ranges(
    void *data,
    struct wp_color_representation_manager_v1 *manager,
    uint32_t coefficients,
    uint32_t range)
{
    const struct swl_wp_color_representation_manager_v1_listener_callbacks *cb =
        data;
    if (cb && cb->supported_coefficients_and_ranges)
        cb->supported_coefficients_and_ranges(
            cb->data, manager, coefficients, range);
}

static void swl_wp_color_representation_manager_v1_handle_done(
    void *data,
    struct wp_color_representation_manager_v1 *manager)
{
    const struct swl_wp_color_representation_manager_v1_listener_callbacks *cb =
        data;
    if (cb && cb->done)
        cb->done(cb->data, manager);
}

static const struct wp_color_representation_manager_v1_listener
    swl_wp_color_representation_manager_v1_listener_impl = {
        .supported_alpha_mode =
            swl_wp_color_representation_manager_v1_handle_supported_alpha_mode,
        .supported_coefficients_and_ranges =
            swl_wp_color_representation_manager_v1_handle_supported_coefficients_and_ranges,
        .done = swl_wp_color_representation_manager_v1_handle_done,
    };

static int swl_wp_color_representation_manager_v1_add_listener_default(
    struct wp_color_representation_manager_v1 *manager,
    const struct swl_wp_color_representation_manager_v1_listener_callbacks *callbacks)
{
    return wp_color_representation_manager_v1_add_listener(
        manager,
        &swl_wp_color_representation_manager_v1_listener_impl,
        (void *)callbacks);
}

#ifndef SWL_ENABLE_TESTING
#define swl_wp_color_representation_manager_v1_add_listener_impl \
    swl_wp_color_representation_manager_v1_add_listener_default
#endif

int swl_wp_color_representation_manager_v1_add_listener(
    struct wp_color_representation_manager_v1 *manager,
    const struct swl_wp_color_representation_manager_v1_listener_callbacks *callbacks)
{
    return swl_wp_color_representation_manager_v1_add_listener_impl(
        manager, callbacks);
}

static void swl_wp_color_manager_v1_handle_supported_intent(
    void *data,
    struct wp_color_manager_v1 *manager,
    uint32_t render_intent)
{
    const struct swl_wp_color_manager_v1_listener_callbacks *cb = data;
    if (cb && cb->supported_intent)
        cb->supported_intent(cb->data, manager, render_intent);
}

static void swl_wp_color_manager_v1_handle_supported_feature(
    void *data,
    struct wp_color_manager_v1 *manager,
    uint32_t feature)
{
    const struct swl_wp_color_manager_v1_listener_callbacks *cb = data;
    if (cb && cb->supported_feature)
        cb->supported_feature(cb->data, manager, feature);
}

static void swl_wp_color_manager_v1_handle_supported_tf_named(
    void *data,
    struct wp_color_manager_v1 *manager,
    uint32_t transfer_function)
{
    const struct swl_wp_color_manager_v1_listener_callbacks *cb = data;
    if (cb && cb->supported_tf_named)
        cb->supported_tf_named(cb->data, manager, transfer_function);
}

static void swl_wp_color_manager_v1_handle_supported_primaries_named(
    void *data,
    struct wp_color_manager_v1 *manager,
    uint32_t primaries)
{
    const struct swl_wp_color_manager_v1_listener_callbacks *cb = data;
    if (cb && cb->supported_primaries_named)
        cb->supported_primaries_named(cb->data, manager, primaries);
}

static void swl_wp_color_manager_v1_handle_done(
    void *data,
    struct wp_color_manager_v1 *manager)
{
    const struct swl_wp_color_manager_v1_listener_callbacks *cb = data;
    if (cb && cb->done)
        cb->done(cb->data, manager);
}

static const struct wp_color_manager_v1_listener
    swl_wp_color_manager_v1_listener_impl = {
        .supported_intent = swl_wp_color_manager_v1_handle_supported_intent,
        .supported_feature = swl_wp_color_manager_v1_handle_supported_feature,
        .supported_tf_named = swl_wp_color_manager_v1_handle_supported_tf_named,
        .supported_primaries_named =
            swl_wp_color_manager_v1_handle_supported_primaries_named,
        .done = swl_wp_color_manager_v1_handle_done,
    };

static int swl_wp_color_manager_v1_add_listener_default(
    struct wp_color_manager_v1 *manager,
    const struct swl_wp_color_manager_v1_listener_callbacks *callbacks)
{
    return wp_color_manager_v1_add_listener(
        manager, &swl_wp_color_manager_v1_listener_impl, (void *)callbacks);
}

#ifndef SWL_ENABLE_TESTING
#define swl_wp_color_manager_v1_add_listener_impl \
    swl_wp_color_manager_v1_add_listener_default
#endif

int swl_wp_color_manager_v1_add_listener(
    struct wp_color_manager_v1 *manager,
    const struct swl_wp_color_manager_v1_listener_callbacks *callbacks)
{
    return swl_wp_color_manager_v1_add_listener_impl(manager, callbacks);
}

static void swl_wp_image_description_v1_handle_failed(
    void *data,
    struct wp_image_description_v1 *image_description,
    uint32_t cause,
    const char *message)
{
    const struct swl_wp_image_description_v1_listener_callbacks *cb = data;
    if (cb && cb->failed)
        cb->failed(cb->data, image_description, cause, message);
}

static void swl_wp_image_description_v1_handle_ready(
    void *data,
    struct wp_image_description_v1 *image_description,
    uint32_t identity)
{
    const struct swl_wp_image_description_v1_listener_callbacks *cb = data;
    if (cb && cb->ready)
        cb->ready(cb->data, image_description, identity);
}

static void swl_wp_image_description_v1_handle_ready2(
    void *data,
    struct wp_image_description_v1 *image_description,
    uint32_t identity_hi,
    uint32_t identity_lo)
{
    const struct swl_wp_image_description_v1_listener_callbacks *cb = data;
    if (cb && cb->ready2)
        cb->ready2(cb->data, image_description, identity_hi, identity_lo);
}

static const struct wp_image_description_v1_listener
    swl_wp_image_description_v1_listener_impl = {
        .failed = swl_wp_image_description_v1_handle_failed,
        .ready = swl_wp_image_description_v1_handle_ready,
        .ready2 = swl_wp_image_description_v1_handle_ready2,
    };

static int swl_wp_image_description_v1_add_listener_default(
    struct wp_image_description_v1 *image_description,
    const struct swl_wp_image_description_v1_listener_callbacks *callbacks)
{
    return wp_image_description_v1_add_listener(
        image_description,
        &swl_wp_image_description_v1_listener_impl,
        (void *)callbacks);
}

#ifndef SWL_ENABLE_TESTING
#define swl_wp_image_description_v1_add_listener_impl \
    swl_wp_image_description_v1_add_listener_default
#endif

int swl_wp_image_description_v1_add_listener(
    struct wp_image_description_v1 *image_description,
    const struct swl_wp_image_description_v1_listener_callbacks *callbacks)
{
    return swl_wp_image_description_v1_add_listener_impl(
        image_description, callbacks);
}

#ifdef SWL_ENABLE_TESTING
void swl_test_metadata_listener_recording_begin(void)
{
    swl_test_metadata_listener_latest =
        (struct swl_test_metadata_listener_record){0};
    swl_test_color_representation_manager_latest = NULL;
    swl_test_color_representation_callbacks_latest = NULL;
    swl_test_image_description_latest = NULL;
    swl_test_image_description_callbacks_latest = NULL;
    swl_wp_color_representation_manager_v1_add_listener_impl =
        swl_test_color_representation_manager_add_listener_record;
    swl_wp_color_manager_v1_add_listener_impl =
        swl_test_color_manager_add_listener_record;
    swl_wp_image_description_v1_add_listener_impl =
        swl_test_image_description_add_listener_record;
}

void swl_test_metadata_listener_recording_end(void)
{
    swl_test_color_representation_manager_latest = NULL;
    swl_test_color_representation_callbacks_latest = NULL;
    swl_test_image_description_latest = NULL;
    swl_test_image_description_callbacks_latest = NULL;
    swl_wp_color_representation_manager_v1_add_listener_impl =
        swl_wp_color_representation_manager_v1_add_listener_default;
    swl_wp_color_manager_v1_add_listener_impl =
        swl_wp_color_manager_v1_add_listener_default;
    swl_wp_image_description_v1_add_listener_impl =
        swl_wp_image_description_v1_add_listener_default;
}

struct swl_test_metadata_listener_record swl_test_metadata_listener_record(void)
{
    return swl_test_metadata_listener_latest;
}

int swl_test_color_representation_listener_emit_supported_alpha_mode(
    uint32_t alpha_mode)
{
    if (!swl_test_color_representation_callbacks_latest ||
        !swl_test_color_representation_manager_latest)
        return 0;

    swl_wp_color_representation_manager_v1_handle_supported_alpha_mode(
        (void *)swl_test_color_representation_callbacks_latest,
        swl_test_color_representation_manager_latest,
        alpha_mode);
    return 1;
}

int swl_test_color_representation_listener_emit_supported_coefficients_and_ranges(
    uint32_t coefficients,
    uint32_t range)
{
    if (!swl_test_color_representation_callbacks_latest ||
        !swl_test_color_representation_manager_latest)
        return 0;

    swl_wp_color_representation_manager_v1_handle_supported_coefficients_and_ranges(
        (void *)swl_test_color_representation_callbacks_latest,
        swl_test_color_representation_manager_latest,
        coefficients,
        range);
    return 1;
}

int swl_test_color_representation_listener_emit_done(void)
{
    if (!swl_test_color_representation_callbacks_latest ||
        !swl_test_color_representation_manager_latest)
        return 0;

    swl_wp_color_representation_manager_v1_handle_done(
        (void *)swl_test_color_representation_callbacks_latest,
        swl_test_color_representation_manager_latest);
    return 1;
}

int swl_test_image_description_listener_emit_ready(uint32_t identity)
{
    if (!swl_test_image_description_callbacks_latest ||
        !swl_test_image_description_latest)
        return 0;

    swl_wp_image_description_v1_handle_ready(
        (void *)swl_test_image_description_callbacks_latest,
        swl_test_image_description_latest,
        identity);
    return 1;
}

int swl_test_image_description_listener_emit_ready2(
    uint32_t identity_hi,
    uint32_t identity_lo)
{
    if (!swl_test_image_description_callbacks_latest ||
        !swl_test_image_description_latest)
        return 0;

    swl_wp_image_description_v1_handle_ready2(
        (void *)swl_test_image_description_callbacks_latest,
        swl_test_image_description_latest,
        identity_hi,
        identity_lo);
    return 1;
}

int swl_test_image_description_listener_emit_failed(
    uint32_t cause,
    const char *message)
{
    if (!swl_test_image_description_callbacks_latest ||
        !swl_test_image_description_latest)
        return 0;

    swl_wp_image_description_v1_handle_failed(
        (void *)swl_test_image_description_callbacks_latest,
        swl_test_image_description_latest,
        cause,
        message);
    return 1;
}
#endif
