#include "swift-wayland-shims.h"
#include "generated/staging/color-representation/color-representation-v1-client-protocol.h"
#include "generated/staging/color-management/color-management-v1-client-protocol.h"

#ifdef SWL_ENABLE_TESTING
static struct swl_test_metadata_listener_record
    swl_test_metadata_listener_latest;

static int swl_wp_color_representation_manager_v1_add_listener_default(
    struct wp_color_representation_manager_v1 *manager,
    const struct swl_wp_color_representation_manager_v1_listener_callbacks *callbacks);
static int swl_wp_color_manager_v1_add_listener_default(
    struct wp_color_manager_v1 *manager,
    const struct swl_wp_color_manager_v1_listener_callbacks *callbacks);

static int (*swl_wp_color_representation_manager_v1_add_listener_impl)(
    struct wp_color_representation_manager_v1 *manager,
    const struct swl_wp_color_representation_manager_v1_listener_callbacks *callbacks) =
        swl_wp_color_representation_manager_v1_add_listener_default;
static int (*swl_wp_color_manager_v1_add_listener_impl)(
    struct wp_color_manager_v1 *manager,
    const struct swl_wp_color_manager_v1_listener_callbacks *callbacks) =
        swl_wp_color_manager_v1_add_listener_default;

static int swl_test_color_representation_manager_add_listener_record(
    struct wp_color_representation_manager_v1 *manager,
    const struct swl_wp_color_representation_manager_v1_listener_callbacks *callbacks)
{
    (void)callbacks;
    swl_test_metadata_listener_latest.call_count += 1;
    swl_test_metadata_listener_latest.object = manager;
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

#ifdef SWL_ENABLE_TESTING
void swl_test_metadata_listener_recording_begin(void)
{
    swl_test_metadata_listener_latest =
        (struct swl_test_metadata_listener_record){0};
    swl_wp_color_representation_manager_v1_add_listener_impl =
        swl_test_color_representation_manager_add_listener_record;
    swl_wp_color_manager_v1_add_listener_impl =
        swl_test_color_manager_add_listener_record;
}

void swl_test_metadata_listener_recording_end(void)
{
    swl_wp_color_representation_manager_v1_add_listener_impl =
        swl_wp_color_representation_manager_v1_add_listener_default;
    swl_wp_color_manager_v1_add_listener_impl =
        swl_wp_color_manager_v1_add_listener_default;
}

struct swl_test_metadata_listener_record swl_test_metadata_listener_record(void)
{
    return swl_test_metadata_listener_latest;
}
#endif
