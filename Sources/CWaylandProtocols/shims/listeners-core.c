#include "swift-wayland-shims.h"

/*
 * wl_registry listener bridge
 */

static void swl_registry_handle_global(
    void *data, struct wl_registry *registry, uint32_t name,
    const char *interface, uint32_t version)
{
    const struct swl_registry_listener_callbacks *cb = data;
    if (cb && cb->global)
        cb->global(cb->data, registry, name, interface, version);
}

static void swl_registry_handle_global_remove(
    void *data, struct wl_registry *registry, uint32_t name)
{
    const struct swl_registry_listener_callbacks *cb = data;
    if (cb && cb->global_remove)
        cb->global_remove(cb->data, registry, name);
}

static const struct wl_registry_listener swl_registry_listener_impl = {
    .global        = swl_registry_handle_global,
    .global_remove = swl_registry_handle_global_remove,
};

int swl_registry_add_listener(
    struct wl_registry *registry,
    const struct swl_registry_listener_callbacks *callbacks)
{
    return wl_registry_add_listener(
        registry, &swl_registry_listener_impl, (void *)callbacks);
}

/*
 * wl_callback listener bridge
 */

static void swl_callback_handle_done(
    void *data, struct wl_callback *callback, uint32_t callback_data)
{
    const struct swl_callback_listener_callbacks *cb = data;
    if (cb && cb->done)
        cb->done(cb->data, callback, callback_data);
}

static const struct wl_callback_listener swl_callback_listener_impl = {
    .done = swl_callback_handle_done,
};

int swl_callback_add_listener(
    struct wl_callback *callback,
    const struct swl_callback_listener_callbacks *callbacks)
{
    return wl_callback_add_listener(
        callback, &swl_callback_listener_impl, (void *)callbacks);
}

/*
 * wl_buffer listener bridge
 */

static void swl_buffer_handle_release(void *data, struct wl_buffer *buffer)
{
    const struct swl_buffer_listener_callbacks *cb = data;
    if (cb && cb->release)
        cb->release(cb->data, buffer);
}

static const struct wl_buffer_listener swl_buffer_listener_impl = {
    .release = swl_buffer_handle_release,
};

int swl_buffer_add_listener(
    struct wl_buffer *buffer,
    const struct swl_buffer_listener_callbacks *callbacks)
{
    return wl_buffer_add_listener(
        buffer, &swl_buffer_listener_impl, (void *)callbacks);
}

/*
 * wl_surface listener bridge
 */

static void swl_surface_handle_enter(
    void *data, struct wl_surface *surface, struct wl_output *output)
{
    (void)data;
    (void)surface;
    (void)output;
}

static void swl_surface_handle_leave(
    void *data, struct wl_surface *surface, struct wl_output *output)
{
    (void)data;
    (void)surface;
    (void)output;
}

#ifdef WL_SURFACE_PREFERRED_BUFFER_SCALE_SINCE_VERSION
static void swl_surface_handle_preferred_buffer_scale(
    void *data, struct wl_surface *surface, int32_t factor)
{
    const struct swl_surface_listener_callbacks *cb = data;
    if (cb && cb->preferred_buffer_scale)
        cb->preferred_buffer_scale(cb->data, surface, factor);
}
#endif

#ifdef WL_SURFACE_PREFERRED_BUFFER_TRANSFORM_SINCE_VERSION
static void swl_surface_handle_preferred_buffer_transform(
    void *data, struct wl_surface *surface, uint32_t transform)
{
    (void)data;
    (void)surface;
    (void)transform;
}
#endif

static const struct wl_surface_listener swl_surface_listener_impl = {
    .enter = swl_surface_handle_enter,
    .leave = swl_surface_handle_leave,
#ifdef WL_SURFACE_PREFERRED_BUFFER_SCALE_SINCE_VERSION
    .preferred_buffer_scale = swl_surface_handle_preferred_buffer_scale,
#endif
#ifdef WL_SURFACE_PREFERRED_BUFFER_TRANSFORM_SINCE_VERSION
    .preferred_buffer_transform = swl_surface_handle_preferred_buffer_transform,
#endif
};

int swl_surface_add_listener(
    struct wl_surface *surface,
    const struct swl_surface_listener_callbacks *callbacks)
{
    return wl_surface_add_listener(
        surface, &swl_surface_listener_impl, (void *)callbacks);
}

/*
 * wl_output listener bridge
 */

static void swl_output_handle_geometry(
    void *data,
    struct wl_output *output,
    int32_t x,
    int32_t y,
    int32_t physical_width,
    int32_t physical_height,
    int32_t subpixel,
    const char *make,
    const char *model,
    int32_t transform)
{
    const struct swl_output_listener_callbacks *cb = data;
    if (cb && cb->geometry)
        cb->geometry(
            cb->data,
            output,
            x,
            y,
            physical_width,
            physical_height,
            subpixel,
            make,
            model,
            transform);
}

static void swl_output_handle_mode(
    void *data,
    struct wl_output *output,
    uint32_t flags,
    int32_t width,
    int32_t height,
    int32_t refresh)
{
    const struct swl_output_listener_callbacks *cb = data;
    if (cb && cb->mode)
        cb->mode(cb->data, output, flags, width, height, refresh);
}

static void swl_output_handle_done(void *data, struct wl_output *output)
{
    const struct swl_output_listener_callbacks *cb = data;
    if (cb && cb->done)
        cb->done(cb->data, output);
}

static void swl_output_handle_scale(
    void *data, struct wl_output *output, int32_t factor)
{
    const struct swl_output_listener_callbacks *cb = data;
    if (cb && cb->scale)
        cb->scale(cb->data, output, factor);
}

#ifdef WL_OUTPUT_NAME_SINCE_VERSION
static void swl_output_handle_name(
    void *data, struct wl_output *output, const char *name)
{
    const struct swl_output_listener_callbacks *cb = data;
    if (cb && cb->name)
        cb->name(cb->data, output, name);
}
#endif

#ifdef WL_OUTPUT_DESCRIPTION_SINCE_VERSION
static void swl_output_handle_description(
    void *data, struct wl_output *output, const char *description)
{
    const struct swl_output_listener_callbacks *cb = data;
    if (cb && cb->description)
        cb->description(cb->data, output, description);
}
#endif

static const struct wl_output_listener swl_output_listener_impl = {
    .geometry = swl_output_handle_geometry,
    .mode     = swl_output_handle_mode,
    .done     = swl_output_handle_done,
    .scale    = swl_output_handle_scale,
#ifdef WL_OUTPUT_NAME_SINCE_VERSION
    .name = swl_output_handle_name,
#endif
#ifdef WL_OUTPUT_DESCRIPTION_SINCE_VERSION
    .description = swl_output_handle_description,
#endif
};

int swl_output_add_listener(
    struct wl_output *output,
    const struct swl_output_listener_callbacks *callbacks)
{
    return wl_output_add_listener(
        output, &swl_output_listener_impl, (void *)callbacks);
}

#ifdef SWL_ENABLE_TESTING
static struct swl_test_surface_preferred_buffer_scale_record
    swl_test_surface_preferred_buffer_scale_latest;

static void swl_test_record_surface_preferred_buffer_scale(
    void *data, struct wl_surface *surface, int32_t factor)
{
    swl_test_surface_preferred_buffer_scale_latest.call_count += 1;
    swl_test_surface_preferred_buffer_scale_latest.data = data;
    swl_test_surface_preferred_buffer_scale_latest.surface = surface;
    swl_test_surface_preferred_buffer_scale_latest.factor = factor;
}

int swl_test_surface_listener_emit_preferred_buffer_scale(
    void *data,
    struct wl_surface *surface,
    int32_t factor,
    struct swl_test_surface_preferred_buffer_scale_record *record)
{
    swl_test_surface_preferred_buffer_scale_latest =
        (struct swl_test_surface_preferred_buffer_scale_record){0};

#ifdef WL_SURFACE_PREFERRED_BUFFER_SCALE_SINCE_VERSION
    const struct swl_surface_listener_callbacks callbacks = {
        .preferred_buffer_scale = swl_test_record_surface_preferred_buffer_scale,
        .data = data,
    };

    swl_surface_handle_preferred_buffer_scale(
        (void *)&callbacks, surface, factor);

    if (record)
        *record = swl_test_surface_preferred_buffer_scale_latest;

    return 1;
#else
    (void)data;
    (void)surface;
    (void)factor;

    if (record)
        *record = swl_test_surface_preferred_buffer_scale_latest;

    return 0;
#endif
}
#endif
