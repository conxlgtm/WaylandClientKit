#include "wayland-client-kit-shims.h"
#include "generated/legacy-unstable/xdg-output/xdg-output-unstable-v1-client-protocol.h"
#include "generated/wlr-unstable/output-management/wlr-output-management-unstable-v1-client-protocol.h"

#ifdef SWL_ENABLE_TESTING
static int swl_test_output_request_recording_enabled;
static struct swl_test_output_destroy_record swl_test_output_destroy_latest;

static void swl_test_record_output_destroy(
    enum swl_test_output_destroy_kind kind,
    void *object)
{
    if (!swl_test_output_request_recording_enabled)
        return;

    swl_test_output_destroy_latest.call_count += 1;
    swl_test_output_destroy_latest.kind = kind;
    swl_test_output_destroy_latest.object = object;
}
#endif

struct zxdg_output_v1 *swl_zxdg_output_manager_v1_get_xdg_output(
    struct zxdg_output_manager_v1 *manager,
    struct wl_output *output)
{
    return zxdg_output_manager_v1_get_xdg_output(manager, output);
}

void swl_zxdg_output_v1_destroy(struct zxdg_output_v1 *output)
{
    zxdg_output_v1_destroy(output);
}

void swl_zxdg_output_manager_v1_destroy(
    struct zxdg_output_manager_v1 *manager)
{
    zxdg_output_manager_v1_destroy(manager);
}

struct zwlr_output_configuration_v1 *
swl_zwlr_output_manager_v1_create_configuration(
    struct zwlr_output_manager_v1 *manager,
    uint32_t serial)
{
    return zwlr_output_manager_v1_create_configuration(manager, serial);
}

void swl_zwlr_output_manager_v1_stop(struct zwlr_output_manager_v1 *manager)
{
    zwlr_output_manager_v1_stop(manager);
}

void swl_zwlr_output_manager_v1_destroy(struct zwlr_output_manager_v1 *manager)
{
    zwlr_output_manager_v1_destroy(manager);
}

void swl_zwlr_output_head_v1_destroy(struct zwlr_output_head_v1 *head)
{
    zwlr_output_head_v1_destroy(head);
}

void swl_zwlr_output_head_v1_release(struct zwlr_output_head_v1 *head)
{
#ifdef SWL_ENABLE_TESTING
    if (swl_test_output_request_recording_enabled) {
        swl_test_record_output_destroy(SWL_TEST_OUTPUT_HEAD_RELEASE, head);
        return;
    }
#endif
    zwlr_output_head_v1_release(head);
}

void swl_zwlr_output_mode_v1_destroy(struct zwlr_output_mode_v1 *mode)
{
    zwlr_output_mode_v1_destroy(mode);
}

void swl_zwlr_output_mode_v1_release(struct zwlr_output_mode_v1 *mode)
{
#ifdef SWL_ENABLE_TESTING
    if (swl_test_output_request_recording_enabled) {
        swl_test_record_output_destroy(SWL_TEST_OUTPUT_MODE_RELEASE, mode);
        return;
    }
#endif
    zwlr_output_mode_v1_release(mode);
}

struct zwlr_output_configuration_head_v1 *
swl_zwlr_output_configuration_v1_enable_head(
    struct zwlr_output_configuration_v1 *configuration,
    struct zwlr_output_head_v1 *head)
{
    return zwlr_output_configuration_v1_enable_head(configuration, head);
}

void swl_zwlr_output_configuration_v1_disable_head(
    struct zwlr_output_configuration_v1 *configuration,
    struct zwlr_output_head_v1 *head)
{
    zwlr_output_configuration_v1_disable_head(configuration, head);
}

void swl_zwlr_output_configuration_v1_apply(
    struct zwlr_output_configuration_v1 *configuration)
{
    zwlr_output_configuration_v1_apply(configuration);
}

void swl_zwlr_output_configuration_v1_test(
    struct zwlr_output_configuration_v1 *configuration)
{
    zwlr_output_configuration_v1_test(configuration);
}

void swl_zwlr_output_configuration_v1_destroy(
    struct zwlr_output_configuration_v1 *configuration)
{
    zwlr_output_configuration_v1_destroy(configuration);
}

void swl_zwlr_output_configuration_head_v1_set_mode(
    struct zwlr_output_configuration_head_v1 *head,
    struct zwlr_output_mode_v1 *mode)
{
    zwlr_output_configuration_head_v1_set_mode(head, mode);
}

void swl_zwlr_output_configuration_head_v1_set_custom_mode(
    struct zwlr_output_configuration_head_v1 *head,
    int32_t width,
    int32_t height,
    int32_t refresh)
{
    zwlr_output_configuration_head_v1_set_custom_mode(head, width, height, refresh);
}

void swl_zwlr_output_configuration_head_v1_set_position(
    struct zwlr_output_configuration_head_v1 *head,
    int32_t x,
    int32_t y)
{
    zwlr_output_configuration_head_v1_set_position(head, x, y);
}

void swl_zwlr_output_configuration_head_v1_set_transform(
    struct zwlr_output_configuration_head_v1 *head,
    int32_t transform)
{
    zwlr_output_configuration_head_v1_set_transform(head, transform);
}

void swl_zwlr_output_configuration_head_v1_set_scale(
    struct zwlr_output_configuration_head_v1 *head,
    int32_t scale)
{
    zwlr_output_configuration_head_v1_set_scale(head, scale);
}

void swl_zwlr_output_configuration_head_v1_destroy(
    struct zwlr_output_configuration_head_v1 *head)
{
    zwlr_output_configuration_head_v1_destroy(head);
}

#ifdef SWL_ENABLE_TESTING
void swl_test_output_request_recording_begin(void)
{
    swl_test_output_request_recording_enabled = 1;
    swl_test_output_destroy_latest =
        (struct swl_test_output_destroy_record){0};
}

void swl_test_output_request_recording_end(void)
{
    swl_test_output_request_recording_enabled = 0;
    swl_test_output_destroy_latest =
        (struct swl_test_output_destroy_record){0};
}

struct swl_test_output_destroy_record swl_test_output_destroy_record(void)
{
    return swl_test_output_destroy_latest;
}
#endif
