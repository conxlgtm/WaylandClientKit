#include "wayland-client-kit-shims.h"
#include "generated/staging/cursor-shape/cursor-shape-v1-client-protocol.h"

#ifdef SWL_ENABLE_TESTING
static struct swl_test_cursor_shape_request_record
    swl_test_cursor_shape_request_latest;
static struct swl_test_cursor_shape_destroy_record
    swl_test_cursor_shape_destroy_latest;

static struct wp_cursor_shape_device_v1 *
swl_wp_cursor_shape_manager_v1_get_pointer_default(
    struct wp_cursor_shape_manager_v1 *manager,
    struct wl_pointer *pointer)
{
    return wp_cursor_shape_manager_v1_get_pointer(manager, pointer);
}

static void swl_wp_cursor_shape_device_v1_set_shape_default(
    struct wp_cursor_shape_device_v1 *device,
    uint32_t serial,
    uint32_t shape)
{
    wp_cursor_shape_device_v1_set_shape(device, serial, shape);
}

static void swl_wp_cursor_shape_device_v1_destroy_default(
    struct wp_cursor_shape_device_v1 *device)
{
    wp_cursor_shape_device_v1_destroy(device);
}

static void swl_wp_cursor_shape_manager_v1_destroy_default(
    struct wp_cursor_shape_manager_v1 *manager)
{
    wp_cursor_shape_manager_v1_destroy(manager);
}

static struct wp_cursor_shape_device_v1 *(*swl_cursor_shape_get_pointer_impl)(
    struct wp_cursor_shape_manager_v1 *manager,
    struct wl_pointer *pointer) =
        swl_wp_cursor_shape_manager_v1_get_pointer_default;
static void (*swl_cursor_shape_set_shape_impl)(
    struct wp_cursor_shape_device_v1 *device,
    uint32_t serial,
    uint32_t shape) =
        swl_wp_cursor_shape_device_v1_set_shape_default;
static void (*swl_cursor_shape_device_destroy_impl)(
    struct wp_cursor_shape_device_v1 *device) =
        swl_wp_cursor_shape_device_v1_destroy_default;
static void (*swl_cursor_shape_manager_destroy_impl)(
    struct wp_cursor_shape_manager_v1 *manager) =
        swl_wp_cursor_shape_manager_v1_destroy_default;

static struct wp_cursor_shape_device_v1 *swl_test_cursor_shape_get_pointer_record(
    struct wp_cursor_shape_manager_v1 *manager,
    struct wl_pointer *pointer)
{
    swl_test_cursor_shape_request_latest.call_count += 1;
    swl_test_cursor_shape_request_latest.kind =
        SWL_TEST_CURSOR_SHAPE_GET_POINTER;
    swl_test_cursor_shape_request_latest.object = manager;
    swl_test_cursor_shape_request_latest.pointer = pointer;
    return (struct wp_cursor_shape_device_v1 *)0xC512;
}

static void swl_test_cursor_shape_set_shape_record(
    struct wp_cursor_shape_device_v1 *device,
    uint32_t serial,
    uint32_t shape)
{
    swl_test_cursor_shape_request_latest.call_count += 1;
    swl_test_cursor_shape_request_latest.kind =
        SWL_TEST_CURSOR_SHAPE_SET_SHAPE;
    swl_test_cursor_shape_request_latest.object = device;
    swl_test_cursor_shape_request_latest.serial = serial;
    swl_test_cursor_shape_request_latest.shape = shape;
}

static void swl_test_cursor_shape_device_destroy_record(
    struct wp_cursor_shape_device_v1 *device)
{
    swl_test_cursor_shape_destroy_latest.call_count += 1;
    swl_test_cursor_shape_destroy_latest.kind =
        SWL_TEST_CURSOR_SHAPE_DESTROY_DEVICE;
    swl_test_cursor_shape_destroy_latest.object = device;
}

static void swl_test_cursor_shape_manager_destroy_record(
    struct wp_cursor_shape_manager_v1 *manager)
{
    swl_test_cursor_shape_destroy_latest.call_count += 1;
    swl_test_cursor_shape_destroy_latest.kind =
        SWL_TEST_CURSOR_SHAPE_DESTROY_MANAGER;
    swl_test_cursor_shape_destroy_latest.object = manager;
}
#else
#define swl_cursor_shape_get_pointer_impl wp_cursor_shape_manager_v1_get_pointer
#define swl_cursor_shape_set_shape_impl wp_cursor_shape_device_v1_set_shape
#define swl_cursor_shape_device_destroy_impl wp_cursor_shape_device_v1_destroy
#define swl_cursor_shape_manager_destroy_impl wp_cursor_shape_manager_v1_destroy
#endif

struct wp_cursor_shape_device_v1 *swl_wp_cursor_shape_manager_v1_get_pointer(
    struct wp_cursor_shape_manager_v1 *manager,
    struct wl_pointer *pointer)
{
    return swl_cursor_shape_get_pointer_impl(manager, pointer);
}

void swl_wp_cursor_shape_device_v1_set_shape(
    struct wp_cursor_shape_device_v1 *device,
    uint32_t serial,
    uint32_t shape)
{
    swl_cursor_shape_set_shape_impl(device, serial, shape);
}

void swl_wp_cursor_shape_device_v1_destroy(
    struct wp_cursor_shape_device_v1 *device)
{
    swl_cursor_shape_device_destroy_impl(device);
}

void swl_wp_cursor_shape_manager_v1_destroy(
    struct wp_cursor_shape_manager_v1 *manager)
{
    swl_cursor_shape_manager_destroy_impl(manager);
}

#ifdef SWL_ENABLE_TESTING
void swl_test_cursor_shape_request_recording_begin(void)
{
    swl_test_cursor_shape_request_latest =
        (struct swl_test_cursor_shape_request_record){0};
    swl_test_cursor_shape_destroy_latest =
        (struct swl_test_cursor_shape_destroy_record){0};
    swl_cursor_shape_get_pointer_impl =
        swl_test_cursor_shape_get_pointer_record;
    swl_cursor_shape_set_shape_impl =
        swl_test_cursor_shape_set_shape_record;
    swl_cursor_shape_device_destroy_impl =
        swl_test_cursor_shape_device_destroy_record;
    swl_cursor_shape_manager_destroy_impl =
        swl_test_cursor_shape_manager_destroy_record;
}

void swl_test_cursor_shape_request_recording_end(void)
{
    swl_cursor_shape_get_pointer_impl =
        swl_wp_cursor_shape_manager_v1_get_pointer_default;
    swl_cursor_shape_set_shape_impl =
        swl_wp_cursor_shape_device_v1_set_shape_default;
    swl_cursor_shape_device_destroy_impl =
        swl_wp_cursor_shape_device_v1_destroy_default;
    swl_cursor_shape_manager_destroy_impl =
        swl_wp_cursor_shape_manager_v1_destroy_default;
}

struct swl_test_cursor_shape_request_record
swl_test_cursor_shape_request_record(void)
{
    return swl_test_cursor_shape_request_latest;
}

struct swl_test_cursor_shape_destroy_record
swl_test_cursor_shape_destroy_record(void)
{
    return swl_test_cursor_shape_destroy_latest;
}
#endif
