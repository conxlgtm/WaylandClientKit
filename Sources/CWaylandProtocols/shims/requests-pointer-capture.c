#include "wayland-client-kit-shims.h"
#include "generated/core/wayland-client-protocol.h"
#include "generated/staging/pointer-warp/pointer-warp-v1-client-protocol.h"
#include "generated/legacy-unstable/relative-pointer/relative-pointer-unstable-v1-client-protocol.h"
#include "generated/legacy-unstable/pointer-constraints/pointer-constraints-unstable-v1-client-protocol.h"

#ifdef SWL_ENABLE_TESTING
static struct swl_test_pointer_capture_request_record
    swl_test_pointer_capture_request_latest;
static struct swl_test_pointer_capture_destroy_record
    swl_test_pointer_capture_destroy_latest;

static struct zwp_relative_pointer_v1 *swl_relative_pointer_get_default(
    struct zwp_relative_pointer_manager_v1 *manager,
    struct wl_pointer *pointer)
{
    return zwp_relative_pointer_manager_v1_get_relative_pointer(manager, pointer);
}

static void swl_pointer_warp_pointer_default(
    struct wp_pointer_warp_v1 *warp,
    struct wl_surface *surface,
    struct wl_pointer *pointer,
    int32_t x,
    int32_t y,
    uint32_t serial)
{
    wp_pointer_warp_v1_warp_pointer(warp, surface, pointer, x, y, serial);
}

static void swl_pointer_warp_destroy_default(struct wp_pointer_warp_v1 *warp)
{
    wp_pointer_warp_v1_destroy(warp);
}

static void swl_relative_pointer_manager_destroy_default(
    struct zwp_relative_pointer_manager_v1 *manager)
{
    zwp_relative_pointer_manager_v1_destroy(manager);
}

static void swl_relative_pointer_destroy_default(
    struct zwp_relative_pointer_v1 *relative_pointer)
{
    zwp_relative_pointer_v1_destroy(relative_pointer);
}

static struct zwp_locked_pointer_v1 *swl_pointer_constraints_lock_default(
    struct zwp_pointer_constraints_v1 *constraints,
    struct wl_surface *surface,
    struct wl_pointer *pointer,
    struct wl_region *region,
    uint32_t lifetime)
{
    return zwp_pointer_constraints_v1_lock_pointer(
        constraints, surface, pointer, region, lifetime);
}

static struct zwp_confined_pointer_v1 *swl_pointer_constraints_confine_default(
    struct zwp_pointer_constraints_v1 *constraints,
    struct wl_surface *surface,
    struct wl_pointer *pointer,
    struct wl_region *region,
    uint32_t lifetime)
{
    return zwp_pointer_constraints_v1_confine_pointer(
        constraints, surface, pointer, region, lifetime);
}

static void swl_pointer_constraints_destroy_default(
    struct zwp_pointer_constraints_v1 *constraints)
{
    zwp_pointer_constraints_v1_destroy(constraints);
}

static void swl_locked_pointer_set_cursor_hint_default(
    struct zwp_locked_pointer_v1 *locked_pointer,
    int32_t surface_x,
    int32_t surface_y)
{
    zwp_locked_pointer_v1_set_cursor_position_hint(
        locked_pointer, surface_x, surface_y);
}

static void swl_locked_pointer_set_region_default(
    struct zwp_locked_pointer_v1 *locked_pointer,
    struct wl_region *region)
{
    zwp_locked_pointer_v1_set_region(locked_pointer, region);
}

static void swl_locked_pointer_destroy_default(
    struct zwp_locked_pointer_v1 *locked_pointer)
{
    zwp_locked_pointer_v1_destroy(locked_pointer);
}

static void swl_confined_pointer_set_region_default(
    struct zwp_confined_pointer_v1 *confined_pointer,
    struct wl_region *region)
{
    zwp_confined_pointer_v1_set_region(confined_pointer, region);
}

static void swl_confined_pointer_destroy_default(
    struct zwp_confined_pointer_v1 *confined_pointer)
{
    zwp_confined_pointer_v1_destroy(confined_pointer);
}

static struct wl_region *swl_compositor_create_region_default(
    struct wl_compositor *compositor)
{
    return wl_compositor_create_region(compositor);
}

static void swl_region_add_default(
    struct wl_region *region,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height)
{
    wl_region_add(region, x, y, width, height);
}

static void swl_region_subtract_default(
    struct wl_region *region,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height)
{
    wl_region_subtract(region, x, y, width, height);
}

static void swl_region_destroy_default(struct wl_region *region)
{
    wl_region_destroy(region);
}

static struct zwp_relative_pointer_v1 *(*swl_relative_pointer_get_impl)(
    struct zwp_relative_pointer_manager_v1 *manager,
    struct wl_pointer *pointer) =
        swl_relative_pointer_get_default;
static void (*swl_pointer_warp_pointer_impl)(
    struct wp_pointer_warp_v1 *warp,
    struct wl_surface *surface,
    struct wl_pointer *pointer,
    int32_t x,
    int32_t y,
    uint32_t serial) =
        swl_pointer_warp_pointer_default;
static void (*swl_pointer_warp_destroy_impl)(struct wp_pointer_warp_v1 *warp) =
    swl_pointer_warp_destroy_default;
static void (*swl_relative_pointer_manager_destroy_impl)(
    struct zwp_relative_pointer_manager_v1 *manager) =
        swl_relative_pointer_manager_destroy_default;
static void (*swl_relative_pointer_destroy_impl)(
    struct zwp_relative_pointer_v1 *relative_pointer) =
        swl_relative_pointer_destroy_default;
static struct zwp_locked_pointer_v1 *(*swl_pointer_constraints_lock_impl)(
    struct zwp_pointer_constraints_v1 *constraints,
    struct wl_surface *surface,
    struct wl_pointer *pointer,
    struct wl_region *region,
    uint32_t lifetime) =
        swl_pointer_constraints_lock_default;
static struct zwp_confined_pointer_v1 *(*swl_pointer_constraints_confine_impl)(
    struct zwp_pointer_constraints_v1 *constraints,
    struct wl_surface *surface,
    struct wl_pointer *pointer,
    struct wl_region *region,
    uint32_t lifetime) =
        swl_pointer_constraints_confine_default;
static void (*swl_pointer_constraints_destroy_impl)(
    struct zwp_pointer_constraints_v1 *constraints) =
        swl_pointer_constraints_destroy_default;
static void (*swl_locked_pointer_set_cursor_hint_impl)(
    struct zwp_locked_pointer_v1 *locked_pointer,
    int32_t surface_x,
    int32_t surface_y) =
        swl_locked_pointer_set_cursor_hint_default;
static void (*swl_locked_pointer_set_region_impl)(
    struct zwp_locked_pointer_v1 *locked_pointer,
    struct wl_region *region) =
        swl_locked_pointer_set_region_default;
static void (*swl_locked_pointer_destroy_impl)(
    struct zwp_locked_pointer_v1 *locked_pointer) =
        swl_locked_pointer_destroy_default;
static void (*swl_confined_pointer_set_region_impl)(
    struct zwp_confined_pointer_v1 *confined_pointer,
    struct wl_region *region) =
        swl_confined_pointer_set_region_default;
static void (*swl_confined_pointer_destroy_impl)(
    struct zwp_confined_pointer_v1 *confined_pointer) =
        swl_confined_pointer_destroy_default;
static struct wl_region *(*swl_compositor_create_region_impl)(
    struct wl_compositor *compositor) =
        swl_compositor_create_region_default;
static void (*swl_region_add_impl)(
    struct wl_region *region,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height) =
        swl_region_add_default;
static void (*swl_region_subtract_impl)(
    struct wl_region *region,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height) =
        swl_region_subtract_default;
static void (*swl_region_destroy_impl)(struct wl_region *region) =
    swl_region_destroy_default;

static void swl_test_record_pointer_capture_request(
    enum swl_test_pointer_capture_request_kind kind,
    void *object)
{
    swl_test_pointer_capture_request_latest.call_count += 1;
    swl_test_pointer_capture_request_latest.kind = kind;
    swl_test_pointer_capture_request_latest.object = object;
}

static struct zwp_relative_pointer_v1 *swl_test_relative_pointer_get_record(
    struct zwp_relative_pointer_manager_v1 *manager,
    struct wl_pointer *pointer)
{
    swl_test_record_pointer_capture_request(
        SWL_TEST_POINTER_CAPTURE_GET_RELATIVE_POINTER, manager);
    swl_test_pointer_capture_request_latest.pointer = pointer;
    return (struct zwp_relative_pointer_v1 *)0xB001;
}

static void swl_test_pointer_warp_record(
    struct wp_pointer_warp_v1 *warp,
    struct wl_surface *surface,
    struct wl_pointer *pointer,
    int32_t x,
    int32_t y,
    uint32_t serial)
{
    swl_test_record_pointer_capture_request(
        SWL_TEST_POINTER_CAPTURE_WARP_POINTER, warp);
    swl_test_pointer_capture_request_latest.surface = surface;
    swl_test_pointer_capture_request_latest.pointer = pointer;
    swl_test_pointer_capture_request_latest.x = x;
    swl_test_pointer_capture_request_latest.y = y;
    swl_test_pointer_capture_request_latest.serial = serial;
}

static struct zwp_locked_pointer_v1 *swl_test_pointer_constraints_lock_record(
    struct zwp_pointer_constraints_v1 *constraints,
    struct wl_surface *surface,
    struct wl_pointer *pointer,
    struct wl_region *region,
    uint32_t lifetime)
{
    swl_test_record_pointer_capture_request(
        SWL_TEST_POINTER_CAPTURE_LOCK_POINTER, constraints);
    swl_test_pointer_capture_request_latest.surface = surface;
    swl_test_pointer_capture_request_latest.pointer = pointer;
    swl_test_pointer_capture_request_latest.region = region;
    swl_test_pointer_capture_request_latest.lifetime = lifetime;
    return (struct zwp_locked_pointer_v1 *)0xB002;
}

static struct zwp_confined_pointer_v1 *swl_test_pointer_constraints_confine_record(
    struct zwp_pointer_constraints_v1 *constraints,
    struct wl_surface *surface,
    struct wl_pointer *pointer,
    struct wl_region *region,
    uint32_t lifetime)
{
    swl_test_record_pointer_capture_request(
        SWL_TEST_POINTER_CAPTURE_CONFINE_POINTER, constraints);
    swl_test_pointer_capture_request_latest.surface = surface;
    swl_test_pointer_capture_request_latest.pointer = pointer;
    swl_test_pointer_capture_request_latest.region = region;
    swl_test_pointer_capture_request_latest.lifetime = lifetime;
    return (struct zwp_confined_pointer_v1 *)0xB003;
}

static void swl_test_locked_pointer_set_cursor_hint_record(
    struct zwp_locked_pointer_v1 *locked_pointer,
    int32_t surface_x,
    int32_t surface_y)
{
    swl_test_record_pointer_capture_request(
        SWL_TEST_POINTER_CAPTURE_LOCK_SET_CURSOR_HINT, locked_pointer);
    swl_test_pointer_capture_request_latest.x = surface_x;
    swl_test_pointer_capture_request_latest.y = surface_y;
}

static void swl_test_locked_pointer_set_region_record(
    struct zwp_locked_pointer_v1 *locked_pointer,
    struct wl_region *region)
{
    swl_test_record_pointer_capture_request(
        SWL_TEST_POINTER_CAPTURE_LOCK_SET_REGION, locked_pointer);
    swl_test_pointer_capture_request_latest.region = region;
}

static void swl_test_confined_pointer_set_region_record(
    struct zwp_confined_pointer_v1 *confined_pointer,
    struct wl_region *region)
{
    swl_test_record_pointer_capture_request(
        SWL_TEST_POINTER_CAPTURE_CONFINE_SET_REGION, confined_pointer);
    swl_test_pointer_capture_request_latest.region = region;
}

static struct wl_region *swl_test_compositor_create_region_record(
    struct wl_compositor *compositor)
{
    (void)compositor;
    return (struct wl_region *)0xB004;
}

static void swl_test_region_add_record(
    struct wl_region *region,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height)
{
    swl_test_record_pointer_capture_request(
        SWL_TEST_POINTER_CAPTURE_REGION_ADD, region);
    swl_test_pointer_capture_request_latest.x = x;
    swl_test_pointer_capture_request_latest.y = y;
    swl_test_pointer_capture_request_latest.width = width;
    swl_test_pointer_capture_request_latest.height = height;
}

static void swl_test_region_subtract_record(
    struct wl_region *region,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height)
{
    swl_test_record_pointer_capture_request(
        SWL_TEST_POINTER_CAPTURE_REGION_SUBTRACT, region);
    swl_test_pointer_capture_request_latest.x = x;
    swl_test_pointer_capture_request_latest.y = y;
    swl_test_pointer_capture_request_latest.width = width;
    swl_test_pointer_capture_request_latest.height = height;
}

static void swl_test_record_pointer_capture_destroy(
    enum swl_test_pointer_capture_destroy_kind kind,
    void *object)
{
    swl_test_pointer_capture_destroy_latest.call_count += 1;
    swl_test_pointer_capture_destroy_latest.kind = kind;
    swl_test_pointer_capture_destroy_latest.object = object;
}

static void swl_test_relative_pointer_manager_destroy_record(
    struct zwp_relative_pointer_manager_v1 *manager)
{
    swl_test_record_pointer_capture_destroy(
        SWL_TEST_POINTER_CAPTURE_DESTROY_RELATIVE_MANAGER, manager);
}

static void swl_test_relative_pointer_destroy_record(
    struct zwp_relative_pointer_v1 *relative_pointer)
{
    swl_test_record_pointer_capture_destroy(
        SWL_TEST_POINTER_CAPTURE_DESTROY_RELATIVE_POINTER, relative_pointer);
}

static void swl_test_pointer_constraints_destroy_record(
    struct zwp_pointer_constraints_v1 *constraints)
{
    swl_test_record_pointer_capture_destroy(
        SWL_TEST_POINTER_CAPTURE_DESTROY_CONSTRAINTS, constraints);
}

static void swl_test_pointer_warp_destroy_record(struct wp_pointer_warp_v1 *warp)
{
    swl_test_record_pointer_capture_destroy(
        SWL_TEST_POINTER_CAPTURE_DESTROY_POINTER_WARP, warp);
}

static void swl_test_locked_pointer_destroy_record(
    struct zwp_locked_pointer_v1 *locked_pointer)
{
    swl_test_record_pointer_capture_destroy(
        SWL_TEST_POINTER_CAPTURE_DESTROY_LOCKED_POINTER, locked_pointer);
}

static void swl_test_confined_pointer_destroy_record(
    struct zwp_confined_pointer_v1 *confined_pointer)
{
    swl_test_record_pointer_capture_destroy(
        SWL_TEST_POINTER_CAPTURE_DESTROY_CONFINED_POINTER, confined_pointer);
}

static void swl_test_region_destroy_record(struct wl_region *region)
{
    swl_test_record_pointer_capture_destroy(
        SWL_TEST_POINTER_CAPTURE_DESTROY_REGION, region);
}
#else
#define swl_relative_pointer_get_impl \
    zwp_relative_pointer_manager_v1_get_relative_pointer
#define swl_pointer_warp_pointer_impl wp_pointer_warp_v1_warp_pointer
#define swl_pointer_warp_destroy_impl wp_pointer_warp_v1_destroy
#define swl_relative_pointer_manager_destroy_impl \
    zwp_relative_pointer_manager_v1_destroy
#define swl_relative_pointer_destroy_impl zwp_relative_pointer_v1_destroy
#define swl_pointer_constraints_lock_impl \
    zwp_pointer_constraints_v1_lock_pointer
#define swl_pointer_constraints_confine_impl \
    zwp_pointer_constraints_v1_confine_pointer
#define swl_pointer_constraints_destroy_impl zwp_pointer_constraints_v1_destroy
#define swl_locked_pointer_set_cursor_hint_impl \
    zwp_locked_pointer_v1_set_cursor_position_hint
#define swl_locked_pointer_set_region_impl zwp_locked_pointer_v1_set_region
#define swl_locked_pointer_destroy_impl zwp_locked_pointer_v1_destroy
#define swl_confined_pointer_set_region_impl zwp_confined_pointer_v1_set_region
#define swl_confined_pointer_destroy_impl zwp_confined_pointer_v1_destroy
#define swl_compositor_create_region_impl wl_compositor_create_region
#define swl_region_add_impl wl_region_add
#define swl_region_subtract_impl wl_region_subtract
#define swl_region_destroy_impl wl_region_destroy
#endif

void swl_wp_pointer_warp_v1_warp_pointer(
    struct wp_pointer_warp_v1 *warp,
    struct wl_surface *surface,
    struct wl_pointer *pointer,
    int32_t x,
    int32_t y,
    uint32_t serial)
{
    swl_pointer_warp_pointer_impl(warp, surface, pointer, x, y, serial);
}

void swl_wp_pointer_warp_v1_destroy(struct wp_pointer_warp_v1 *warp)
{
    swl_pointer_warp_destroy_impl(warp);
}

struct zwp_relative_pointer_v1 *
swl_zwp_relative_pointer_manager_v1_get_relative_pointer(
    struct zwp_relative_pointer_manager_v1 *manager,
    struct wl_pointer *pointer)
{
    return swl_relative_pointer_get_impl(manager, pointer);
}

void swl_zwp_relative_pointer_manager_v1_destroy(
    struct zwp_relative_pointer_manager_v1 *manager)
{
    swl_relative_pointer_manager_destroy_impl(manager);
}

void swl_zwp_relative_pointer_v1_destroy(
    struct zwp_relative_pointer_v1 *relative_pointer)
{
    swl_relative_pointer_destroy_impl(relative_pointer);
}

struct zwp_locked_pointer_v1 *
swl_zwp_pointer_constraints_v1_lock_pointer(
    struct zwp_pointer_constraints_v1 *constraints,
    struct wl_surface *surface,
    struct wl_pointer *pointer,
    struct wl_region *region,
    uint32_t lifetime)
{
    return swl_pointer_constraints_lock_impl(
        constraints, surface, pointer, region, lifetime);
}

struct zwp_confined_pointer_v1 *
swl_zwp_pointer_constraints_v1_confine_pointer(
    struct zwp_pointer_constraints_v1 *constraints,
    struct wl_surface *surface,
    struct wl_pointer *pointer,
    struct wl_region *region,
    uint32_t lifetime)
{
    return swl_pointer_constraints_confine_impl(
        constraints, surface, pointer, region, lifetime);
}

void swl_zwp_pointer_constraints_v1_destroy(
    struct zwp_pointer_constraints_v1 *constraints)
{
    swl_pointer_constraints_destroy_impl(constraints);
}

void swl_zwp_locked_pointer_v1_set_cursor_position_hint(
    struct zwp_locked_pointer_v1 *locked_pointer,
    int32_t surface_x,
    int32_t surface_y)
{
    swl_locked_pointer_set_cursor_hint_impl(
        locked_pointer, surface_x, surface_y);
}

void swl_zwp_locked_pointer_v1_set_region(
    struct zwp_locked_pointer_v1 *locked_pointer,
    struct wl_region *region)
{
    swl_locked_pointer_set_region_impl(locked_pointer, region);
}

void swl_zwp_locked_pointer_v1_destroy(
    struct zwp_locked_pointer_v1 *locked_pointer)
{
    swl_locked_pointer_destroy_impl(locked_pointer);
}

void swl_zwp_confined_pointer_v1_set_region(
    struct zwp_confined_pointer_v1 *confined_pointer,
    struct wl_region *region)
{
    swl_confined_pointer_set_region_impl(confined_pointer, region);
}

void swl_zwp_confined_pointer_v1_destroy(
    struct zwp_confined_pointer_v1 *confined_pointer)
{
    swl_confined_pointer_destroy_impl(confined_pointer);
}

struct wl_region *swl_compositor_create_region(struct wl_compositor *compositor)
{
    return swl_compositor_create_region_impl(compositor);
}

void swl_region_add(
    struct wl_region *region,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height)
{
    swl_region_add_impl(region, x, y, width, height);
}

void swl_region_subtract(
    struct wl_region *region,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height)
{
    swl_region_subtract_impl(region, x, y, width, height);
}

void swl_region_destroy(struct wl_region *region)
{
    swl_region_destroy_impl(region);
}

#ifdef SWL_ENABLE_TESTING
void swl_test_pointer_capture_request_recording_begin(void)
{
    swl_test_pointer_capture_request_latest =
        (struct swl_test_pointer_capture_request_record){0};
    swl_test_pointer_capture_destroy_latest =
        (struct swl_test_pointer_capture_destroy_record){0};
    swl_pointer_warp_pointer_impl = swl_test_pointer_warp_record;
    swl_pointer_warp_destroy_impl = swl_test_pointer_warp_destroy_record;
    swl_relative_pointer_get_impl = swl_test_relative_pointer_get_record;
    swl_relative_pointer_manager_destroy_impl =
        swl_test_relative_pointer_manager_destroy_record;
    swl_relative_pointer_destroy_impl = swl_test_relative_pointer_destroy_record;
    swl_pointer_constraints_lock_impl = swl_test_pointer_constraints_lock_record;
    swl_pointer_constraints_confine_impl =
        swl_test_pointer_constraints_confine_record;
    swl_pointer_constraints_destroy_impl =
        swl_test_pointer_constraints_destroy_record;
    swl_locked_pointer_set_cursor_hint_impl =
        swl_test_locked_pointer_set_cursor_hint_record;
    swl_locked_pointer_set_region_impl =
        swl_test_locked_pointer_set_region_record;
    swl_locked_pointer_destroy_impl = swl_test_locked_pointer_destroy_record;
    swl_confined_pointer_set_region_impl =
        swl_test_confined_pointer_set_region_record;
    swl_confined_pointer_destroy_impl = swl_test_confined_pointer_destroy_record;
    swl_compositor_create_region_impl = swl_test_compositor_create_region_record;
    swl_region_add_impl = swl_test_region_add_record;
    swl_region_subtract_impl = swl_test_region_subtract_record;
    swl_region_destroy_impl = swl_test_region_destroy_record;
}

void swl_test_pointer_capture_request_recording_end(void)
{
    swl_pointer_warp_pointer_impl = swl_pointer_warp_pointer_default;
    swl_pointer_warp_destroy_impl = swl_pointer_warp_destroy_default;
    swl_relative_pointer_get_impl = swl_relative_pointer_get_default;
    swl_relative_pointer_manager_destroy_impl =
        swl_relative_pointer_manager_destroy_default;
    swl_relative_pointer_destroy_impl = swl_relative_pointer_destroy_default;
    swl_pointer_constraints_lock_impl = swl_pointer_constraints_lock_default;
    swl_pointer_constraints_confine_impl =
        swl_pointer_constraints_confine_default;
    swl_pointer_constraints_destroy_impl = swl_pointer_constraints_destroy_default;
    swl_locked_pointer_set_cursor_hint_impl =
        swl_locked_pointer_set_cursor_hint_default;
    swl_locked_pointer_set_region_impl = swl_locked_pointer_set_region_default;
    swl_locked_pointer_destroy_impl = swl_locked_pointer_destroy_default;
    swl_confined_pointer_set_region_impl =
        swl_confined_pointer_set_region_default;
    swl_confined_pointer_destroy_impl = swl_confined_pointer_destroy_default;
    swl_compositor_create_region_impl = swl_compositor_create_region_default;
    swl_region_add_impl = swl_region_add_default;
    swl_region_subtract_impl = swl_region_subtract_default;
    swl_region_destroy_impl = swl_region_destroy_default;
}

struct swl_test_pointer_capture_request_record
swl_test_pointer_capture_request_record(void)
{
    return swl_test_pointer_capture_request_latest;
}

struct swl_test_pointer_capture_destroy_record
swl_test_pointer_capture_destroy_record(void)
{
    return swl_test_pointer_capture_destroy_latest;
}
#endif
