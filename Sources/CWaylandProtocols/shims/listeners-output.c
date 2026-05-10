#include "swift-wayland-shims.h"
#include "generated/legacy-unstable/xdg-output/xdg-output-unstable-v1-client-protocol.h"

static void swl_zxdg_output_v1_handle_logical_position(
    void *data,
    struct zxdg_output_v1 *output,
    int32_t x,
    int32_t y)
{
    const struct swl_zxdg_output_v1_listener_callbacks *cb = data;
    if (cb && cb->logical_position)
        cb->logical_position(cb->data, output, x, y);
}

static void swl_zxdg_output_v1_handle_logical_size(
    void *data,
    struct zxdg_output_v1 *output,
    int32_t width,
    int32_t height)
{
    const struct swl_zxdg_output_v1_listener_callbacks *cb = data;
    if (cb && cb->logical_size)
        cb->logical_size(cb->data, output, width, height);
}

static void swl_zxdg_output_v1_handle_done(
    void *data,
    struct zxdg_output_v1 *output)
{
    const struct swl_zxdg_output_v1_listener_callbacks *cb = data;
    if (cb && cb->done)
        cb->done(cb->data, output);
}

static void swl_zxdg_output_v1_handle_name(
    void *data,
    struct zxdg_output_v1 *output,
    const char *name)
{
    const struct swl_zxdg_output_v1_listener_callbacks *cb = data;
    if (cb && cb->name)
        cb->name(cb->data, output, name);
}

static void swl_zxdg_output_v1_handle_description(
    void *data,
    struct zxdg_output_v1 *output,
    const char *description)
{
    const struct swl_zxdg_output_v1_listener_callbacks *cb = data;
    if (cb && cb->description)
        cb->description(cb->data, output, description);
}

static const struct zxdg_output_v1_listener swl_zxdg_output_v1_listener_impl = {
    .logical_position = swl_zxdg_output_v1_handle_logical_position,
    .logical_size = swl_zxdg_output_v1_handle_logical_size,
    .done = swl_zxdg_output_v1_handle_done,
    .name = swl_zxdg_output_v1_handle_name,
    .description = swl_zxdg_output_v1_handle_description,
};

int swl_zxdg_output_v1_add_listener(
    struct zxdg_output_v1 *output,
    const struct swl_zxdg_output_v1_listener_callbacks *callbacks)
{
    return zxdg_output_v1_add_listener(
        output,
        &swl_zxdg_output_v1_listener_impl,
        (void *)callbacks);
}
