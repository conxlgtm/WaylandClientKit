#include "swift-wayland-shims.h"
#include "generated/core/wayland-client-protocol.h"
#include "generated/legacy-unstable/relative-pointer/relative-pointer-unstable-v1-client-protocol.h"
#include "generated/legacy-unstable/pointer-constraints/pointer-constraints-unstable-v1-client-protocol.h"

struct zwp_relative_pointer_v1 *
swl_zwp_relative_pointer_manager_v1_get_relative_pointer(
    struct zwp_relative_pointer_manager_v1 *manager,
    struct wl_pointer *pointer)
{
    return zwp_relative_pointer_manager_v1_get_relative_pointer(manager, pointer);
}

void swl_zwp_relative_pointer_manager_v1_destroy(
    struct zwp_relative_pointer_manager_v1 *manager)
{
    zwp_relative_pointer_manager_v1_destroy(manager);
}

void swl_zwp_relative_pointer_v1_destroy(
    struct zwp_relative_pointer_v1 *relative_pointer)
{
    zwp_relative_pointer_v1_destroy(relative_pointer);
}

struct zwp_locked_pointer_v1 *
swl_zwp_pointer_constraints_v1_lock_pointer(
    struct zwp_pointer_constraints_v1 *constraints,
    struct wl_surface *surface,
    struct wl_pointer *pointer,
    struct wl_region *region,
    uint32_t lifetime)
{
    return zwp_pointer_constraints_v1_lock_pointer(
        constraints,
        surface,
        pointer,
        region,
        lifetime);
}

struct zwp_confined_pointer_v1 *
swl_zwp_pointer_constraints_v1_confine_pointer(
    struct zwp_pointer_constraints_v1 *constraints,
    struct wl_surface *surface,
    struct wl_pointer *pointer,
    struct wl_region *region,
    uint32_t lifetime)
{
    return zwp_pointer_constraints_v1_confine_pointer(
        constraints,
        surface,
        pointer,
        region,
        lifetime);
}

void swl_zwp_pointer_constraints_v1_destroy(
    struct zwp_pointer_constraints_v1 *constraints)
{
    zwp_pointer_constraints_v1_destroy(constraints);
}

void swl_zwp_locked_pointer_v1_set_cursor_position_hint(
    struct zwp_locked_pointer_v1 *locked_pointer,
    int32_t surface_x,
    int32_t surface_y)
{
    zwp_locked_pointer_v1_set_cursor_position_hint(
        locked_pointer,
        surface_x,
        surface_y);
}

void swl_zwp_locked_pointer_v1_set_region(
    struct zwp_locked_pointer_v1 *locked_pointer,
    struct wl_region *region)
{
    zwp_locked_pointer_v1_set_region(locked_pointer, region);
}

void swl_zwp_locked_pointer_v1_destroy(
    struct zwp_locked_pointer_v1 *locked_pointer)
{
    zwp_locked_pointer_v1_destroy(locked_pointer);
}

void swl_zwp_confined_pointer_v1_set_region(
    struct zwp_confined_pointer_v1 *confined_pointer,
    struct wl_region *region)
{
    zwp_confined_pointer_v1_set_region(confined_pointer, region);
}

void swl_zwp_confined_pointer_v1_destroy(
    struct zwp_confined_pointer_v1 *confined_pointer)
{
    zwp_confined_pointer_v1_destroy(confined_pointer);
}

struct wl_region *swl_compositor_create_region(struct wl_compositor *compositor)
{
    return wl_compositor_create_region(compositor);
}

void swl_region_add(
    struct wl_region *region,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height)
{
    wl_region_add(region, x, y, width, height);
}

void swl_region_destroy(struct wl_region *region)
{
    wl_region_destroy(region);
}
