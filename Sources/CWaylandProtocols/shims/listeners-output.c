#include "wayland-client-kit-shims.h"
#include "generated/legacy-unstable/xdg-output/xdg-output-unstable-v1-client-protocol.h"
#include "generated/wlr-unstable/output-management/wlr-output-management-unstable-v1-client-protocol.h"

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

static void swl_zwlr_output_manager_v1_handle_head(
    void *data,
    struct zwlr_output_manager_v1 *manager,
    struct zwlr_output_head_v1 *head)
{
    const struct swl_zwlr_output_manager_v1_listener_callbacks *cb = data;
    if (cb && cb->head)
        cb->head(cb->data, manager, head);
}

static void swl_zwlr_output_manager_v1_handle_done(
    void *data,
    struct zwlr_output_manager_v1 *manager,
    uint32_t serial)
{
    const struct swl_zwlr_output_manager_v1_listener_callbacks *cb = data;
    if (cb && cb->done)
        cb->done(cb->data, manager, serial);
}

static void swl_zwlr_output_manager_v1_handle_finished(
    void *data,
    struct zwlr_output_manager_v1 *manager)
{
    const struct swl_zwlr_output_manager_v1_listener_callbacks *cb = data;
    if (cb && cb->finished)
        cb->finished(cb->data, manager);
}

static const struct zwlr_output_manager_v1_listener
    swl_zwlr_output_manager_v1_listener_impl = {
        .head = swl_zwlr_output_manager_v1_handle_head,
        .done = swl_zwlr_output_manager_v1_handle_done,
        .finished = swl_zwlr_output_manager_v1_handle_finished,
    };

int swl_zwlr_output_manager_v1_add_listener(
    struct zwlr_output_manager_v1 *manager,
    const struct swl_zwlr_output_manager_v1_listener_callbacks *callbacks)
{
    return zwlr_output_manager_v1_add_listener(
        manager,
        &swl_zwlr_output_manager_v1_listener_impl,
        (void *)callbacks);
}

static void swl_zwlr_output_head_v1_handle_name(
    void *data,
    struct zwlr_output_head_v1 *head,
    const char *name)
{
    const struct swl_zwlr_output_head_v1_listener_callbacks *cb = data;
    if (cb && cb->name)
        cb->name(cb->data, head, name);
}

static void swl_zwlr_output_head_v1_handle_description(
    void *data,
    struct zwlr_output_head_v1 *head,
    const char *description)
{
    const struct swl_zwlr_output_head_v1_listener_callbacks *cb = data;
    if (cb && cb->description)
        cb->description(cb->data, head, description);
}

static void swl_zwlr_output_head_v1_handle_physical_size(
    void *data,
    struct zwlr_output_head_v1 *head,
    int32_t width,
    int32_t height)
{
    const struct swl_zwlr_output_head_v1_listener_callbacks *cb = data;
    if (cb && cb->physical_size)
        cb->physical_size(cb->data, head, width, height);
}

static void swl_zwlr_output_head_v1_handle_mode(
    void *data,
    struct zwlr_output_head_v1 *head,
    struct zwlr_output_mode_v1 *mode)
{
    const struct swl_zwlr_output_head_v1_listener_callbacks *cb = data;
    if (cb && cb->mode)
        cb->mode(cb->data, head, mode);
}

static void swl_zwlr_output_head_v1_handle_enabled(
    void *data,
    struct zwlr_output_head_v1 *head,
    int32_t enabled)
{
    const struct swl_zwlr_output_head_v1_listener_callbacks *cb = data;
    if (cb && cb->enabled)
        cb->enabled(cb->data, head, enabled);
}

static void swl_zwlr_output_head_v1_handle_current_mode(
    void *data,
    struct zwlr_output_head_v1 *head,
    struct zwlr_output_mode_v1 *mode)
{
    const struct swl_zwlr_output_head_v1_listener_callbacks *cb = data;
    if (cb && cb->current_mode)
        cb->current_mode(cb->data, head, mode);
}

static void swl_zwlr_output_head_v1_handle_position(
    void *data,
    struct zwlr_output_head_v1 *head,
    int32_t x,
    int32_t y)
{
    const struct swl_zwlr_output_head_v1_listener_callbacks *cb = data;
    if (cb && cb->position)
        cb->position(cb->data, head, x, y);
}

static void swl_zwlr_output_head_v1_handle_transform(
    void *data,
    struct zwlr_output_head_v1 *head,
    int32_t transform)
{
    const struct swl_zwlr_output_head_v1_listener_callbacks *cb = data;
    if (cb && cb->transform)
        cb->transform(cb->data, head, transform);
}

static void swl_zwlr_output_head_v1_handle_scale(
    void *data,
    struct zwlr_output_head_v1 *head,
    wl_fixed_t scale)
{
    const struct swl_zwlr_output_head_v1_listener_callbacks *cb = data;
    if (cb && cb->scale)
        cb->scale(cb->data, head, scale);
}

static void swl_zwlr_output_head_v1_handle_finished(
    void *data,
    struct zwlr_output_head_v1 *head)
{
    const struct swl_zwlr_output_head_v1_listener_callbacks *cb = data;
    if (cb && cb->finished)
        cb->finished(cb->data, head);
}

static void swl_zwlr_output_head_v1_handle_make(
    void *data,
    struct zwlr_output_head_v1 *head,
    const char *make)
{
    const struct swl_zwlr_output_head_v1_listener_callbacks *cb = data;
    if (cb && cb->make)
        cb->make(cb->data, head, make);
}

static void swl_zwlr_output_head_v1_handle_model(
    void *data,
    struct zwlr_output_head_v1 *head,
    const char *model)
{
    const struct swl_zwlr_output_head_v1_listener_callbacks *cb = data;
    if (cb && cb->model)
        cb->model(cb->data, head, model);
}

static void swl_zwlr_output_head_v1_handle_serial_number(
    void *data,
    struct zwlr_output_head_v1 *head,
    const char *serial_number)
{
    const struct swl_zwlr_output_head_v1_listener_callbacks *cb = data;
    if (cb && cb->serial_number)
        cb->serial_number(cb->data, head, serial_number);
}

static void swl_zwlr_output_head_v1_handle_adaptive_sync(
    void *data,
    struct zwlr_output_head_v1 *head,
    uint32_t state)
{
    const struct swl_zwlr_output_head_v1_listener_callbacks *cb = data;
    if (cb && cb->adaptive_sync)
        cb->adaptive_sync(cb->data, head, state);
}

static const struct zwlr_output_head_v1_listener
    swl_zwlr_output_head_v1_listener_impl = {
        .name = swl_zwlr_output_head_v1_handle_name,
        .description = swl_zwlr_output_head_v1_handle_description,
        .physical_size = swl_zwlr_output_head_v1_handle_physical_size,
        .mode = swl_zwlr_output_head_v1_handle_mode,
        .enabled = swl_zwlr_output_head_v1_handle_enabled,
        .current_mode = swl_zwlr_output_head_v1_handle_current_mode,
        .position = swl_zwlr_output_head_v1_handle_position,
        .transform = swl_zwlr_output_head_v1_handle_transform,
        .scale = swl_zwlr_output_head_v1_handle_scale,
        .finished = swl_zwlr_output_head_v1_handle_finished,
        .make = swl_zwlr_output_head_v1_handle_make,
        .model = swl_zwlr_output_head_v1_handle_model,
        .serial_number = swl_zwlr_output_head_v1_handle_serial_number,
        .adaptive_sync = swl_zwlr_output_head_v1_handle_adaptive_sync,
    };

int swl_zwlr_output_head_v1_add_listener(
    struct zwlr_output_head_v1 *head,
    const struct swl_zwlr_output_head_v1_listener_callbacks *callbacks)
{
    return zwlr_output_head_v1_add_listener(
        head,
        &swl_zwlr_output_head_v1_listener_impl,
        (void *)callbacks);
}

static void swl_zwlr_output_mode_v1_handle_size(
    void *data,
    struct zwlr_output_mode_v1 *mode,
    int32_t width,
    int32_t height)
{
    const struct swl_zwlr_output_mode_v1_listener_callbacks *cb = data;
    if (cb && cb->size)
        cb->size(cb->data, mode, width, height);
}

static void swl_zwlr_output_mode_v1_handle_refresh(
    void *data,
    struct zwlr_output_mode_v1 *mode,
    int32_t refresh)
{
    const struct swl_zwlr_output_mode_v1_listener_callbacks *cb = data;
    if (cb && cb->refresh)
        cb->refresh(cb->data, mode, refresh);
}

static void swl_zwlr_output_mode_v1_handle_preferred(
    void *data,
    struct zwlr_output_mode_v1 *mode)
{
    const struct swl_zwlr_output_mode_v1_listener_callbacks *cb = data;
    if (cb && cb->preferred)
        cb->preferred(cb->data, mode);
}

static void swl_zwlr_output_mode_v1_handle_finished(
    void *data,
    struct zwlr_output_mode_v1 *mode)
{
    const struct swl_zwlr_output_mode_v1_listener_callbacks *cb = data;
    if (cb && cb->finished)
        cb->finished(cb->data, mode);
}

static const struct zwlr_output_mode_v1_listener
    swl_zwlr_output_mode_v1_listener_impl = {
        .size = swl_zwlr_output_mode_v1_handle_size,
        .refresh = swl_zwlr_output_mode_v1_handle_refresh,
        .preferred = swl_zwlr_output_mode_v1_handle_preferred,
        .finished = swl_zwlr_output_mode_v1_handle_finished,
    };

int swl_zwlr_output_mode_v1_add_listener(
    struct zwlr_output_mode_v1 *mode,
    const struct swl_zwlr_output_mode_v1_listener_callbacks *callbacks)
{
    return zwlr_output_mode_v1_add_listener(
        mode,
        &swl_zwlr_output_mode_v1_listener_impl,
        (void *)callbacks);
}

static void swl_zwlr_output_configuration_v1_handle_succeeded(
    void *data,
    struct zwlr_output_configuration_v1 *configuration)
{
    const struct swl_zwlr_output_configuration_v1_listener_callbacks *cb = data;
    if (cb && cb->succeeded)
        cb->succeeded(cb->data, configuration);
}

static void swl_zwlr_output_configuration_v1_handle_failed(
    void *data,
    struct zwlr_output_configuration_v1 *configuration)
{
    const struct swl_zwlr_output_configuration_v1_listener_callbacks *cb = data;
    if (cb && cb->failed)
        cb->failed(cb->data, configuration);
}

static void swl_zwlr_output_configuration_v1_handle_cancelled(
    void *data,
    struct zwlr_output_configuration_v1 *configuration)
{
    const struct swl_zwlr_output_configuration_v1_listener_callbacks *cb = data;
    if (cb && cb->cancelled)
        cb->cancelled(cb->data, configuration);
}

static const struct zwlr_output_configuration_v1_listener
    swl_zwlr_output_configuration_v1_listener_impl = {
        .succeeded = swl_zwlr_output_configuration_v1_handle_succeeded,
        .failed = swl_zwlr_output_configuration_v1_handle_failed,
        .cancelled = swl_zwlr_output_configuration_v1_handle_cancelled,
    };

int swl_zwlr_output_configuration_v1_add_listener(
    struct zwlr_output_configuration_v1 *configuration,
    const struct swl_zwlr_output_configuration_v1_listener_callbacks *callbacks)
{
    return zwlr_output_configuration_v1_add_listener(
        configuration,
        &swl_zwlr_output_configuration_v1_listener_impl,
        (void *)callbacks);
}
