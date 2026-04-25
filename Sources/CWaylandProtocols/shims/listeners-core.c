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
