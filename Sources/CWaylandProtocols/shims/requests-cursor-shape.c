#include "swift-wayland-shims.h"
#include "generated/staging/cursor-shape/cursor-shape-v1-client-protocol.h"

struct wp_cursor_shape_device_v1 *swl_wp_cursor_shape_manager_v1_get_pointer(
    struct wp_cursor_shape_manager_v1 *manager,
    struct wl_pointer *pointer)
{
    return wp_cursor_shape_manager_v1_get_pointer(manager, pointer);
}

void swl_wp_cursor_shape_device_v1_set_shape(
    struct wp_cursor_shape_device_v1 *device,
    uint32_t serial,
    uint32_t shape)
{
    wp_cursor_shape_device_v1_set_shape(device, serial, shape);
}

void swl_wp_cursor_shape_device_v1_destroy(
    struct wp_cursor_shape_device_v1 *device)
{
    wp_cursor_shape_device_v1_destroy(device);
}

void swl_wp_cursor_shape_manager_v1_destroy(
    struct wp_cursor_shape_manager_v1 *manager)
{
    wp_cursor_shape_manager_v1_destroy(manager);
}
