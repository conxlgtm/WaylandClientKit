#include "swift-wayland-shims.h"
#include "generated/staging/linux-drm-syncobj/linux-drm-syncobj-v1-client-protocol.h"

#ifdef SWL_ENABLE_TESTING
static struct swl_test_syncobj_request_record swl_test_syncobj_request_latest;
static struct swl_test_syncobj_destroy_record swl_test_syncobj_destroy_latest;

static struct wp_linux_drm_syncobj_surface_v1 *
swl_syncobj_get_surface_default(
    struct wp_linux_drm_syncobj_manager_v1 *manager,
    struct wl_surface *surface)
{
    return wp_linux_drm_syncobj_manager_v1_get_surface(manager, surface);
}

static struct wp_linux_drm_syncobj_timeline_v1 *
swl_syncobj_import_timeline_default(
    struct wp_linux_drm_syncobj_manager_v1 *manager,
    int32_t fd)
{
    return wp_linux_drm_syncobj_manager_v1_import_timeline(manager, fd);
}

static void swl_syncobj_set_acquire_point_default(
    struct wp_linux_drm_syncobj_surface_v1 *syncobj_surface,
    struct wp_linux_drm_syncobj_timeline_v1 *timeline,
    uint32_t point_hi,
    uint32_t point_lo)
{
    wp_linux_drm_syncobj_surface_v1_set_acquire_point(
        syncobj_surface, timeline, point_hi, point_lo);
}

static void swl_syncobj_set_release_point_default(
    struct wp_linux_drm_syncobj_surface_v1 *syncobj_surface,
    struct wp_linux_drm_syncobj_timeline_v1 *timeline,
    uint32_t point_hi,
    uint32_t point_lo)
{
    wp_linux_drm_syncobj_surface_v1_set_release_point(
        syncobj_surface, timeline, point_hi, point_lo);
}

static void swl_syncobj_surface_destroy_default(
    struct wp_linux_drm_syncobj_surface_v1 *syncobj_surface)
{
    wp_linux_drm_syncobj_surface_v1_destroy(syncobj_surface);
}

static void swl_syncobj_timeline_destroy_default(
    struct wp_linux_drm_syncobj_timeline_v1 *timeline)
{
    wp_linux_drm_syncobj_timeline_v1_destroy(timeline);
}

static void swl_syncobj_manager_destroy_default(
    struct wp_linux_drm_syncobj_manager_v1 *manager)
{
    wp_linux_drm_syncobj_manager_v1_destroy(manager);
}

static struct wp_linux_drm_syncobj_surface_v1 *(*swl_syncobj_get_surface_impl)(
    struct wp_linux_drm_syncobj_manager_v1 *manager,
    struct wl_surface *surface) =
        swl_syncobj_get_surface_default;
static struct wp_linux_drm_syncobj_timeline_v1 *(*swl_syncobj_import_timeline_impl)(
    struct wp_linux_drm_syncobj_manager_v1 *manager,
    int32_t fd) =
        swl_syncobj_import_timeline_default;
static void (*swl_syncobj_set_acquire_point_impl)(
    struct wp_linux_drm_syncobj_surface_v1 *syncobj_surface,
    struct wp_linux_drm_syncobj_timeline_v1 *timeline,
    uint32_t point_hi,
    uint32_t point_lo) =
        swl_syncobj_set_acquire_point_default;
static void (*swl_syncobj_set_release_point_impl)(
    struct wp_linux_drm_syncobj_surface_v1 *syncobj_surface,
    struct wp_linux_drm_syncobj_timeline_v1 *timeline,
    uint32_t point_hi,
    uint32_t point_lo) =
        swl_syncobj_set_release_point_default;
static void (*swl_syncobj_surface_destroy_impl)(
    struct wp_linux_drm_syncobj_surface_v1 *syncobj_surface) =
        swl_syncobj_surface_destroy_default;
static void (*swl_syncobj_timeline_destroy_impl)(
    struct wp_linux_drm_syncobj_timeline_v1 *timeline) =
        swl_syncobj_timeline_destroy_default;
static void (*swl_syncobj_manager_destroy_impl)(
    struct wp_linux_drm_syncobj_manager_v1 *manager) =
        swl_syncobj_manager_destroy_default;

static void swl_test_record_syncobj_request(
    enum swl_test_syncobj_request_kind kind,
    void *object,
    void *surface,
    void *timeline,
    int32_t fd,
    uint32_t point_hi,
    uint32_t point_lo)
{
    swl_test_syncobj_request_latest.call_count += 1;
    swl_test_syncobj_request_latest.kind = kind;
    swl_test_syncobj_request_latest.object = object;
    swl_test_syncobj_request_latest.surface = surface;
    swl_test_syncobj_request_latest.timeline = timeline;
    swl_test_syncobj_request_latest.fd = fd;
    swl_test_syncobj_request_latest.point_hi = point_hi;
    swl_test_syncobj_request_latest.point_lo = point_lo;
}

static struct wp_linux_drm_syncobj_surface_v1 *swl_test_syncobj_get_surface_record(
    struct wp_linux_drm_syncobj_manager_v1 *manager,
    struct wl_surface *surface)
{
    swl_test_record_syncobj_request(
        SWL_TEST_SYNCOBJ_GET_SURFACE, manager, surface, NULL, -1, 0, 0);
    return (struct wp_linux_drm_syncobj_surface_v1 *)0xD501;
}

static struct wp_linux_drm_syncobj_timeline_v1 *
swl_test_syncobj_import_timeline_record(
    struct wp_linux_drm_syncobj_manager_v1 *manager,
    int32_t fd)
{
    swl_test_record_syncobj_request(
        SWL_TEST_SYNCOBJ_IMPORT_TIMELINE, manager, NULL, NULL, fd, 0, 0);
    return (struct wp_linux_drm_syncobj_timeline_v1 *)0xD502;
}

static void swl_test_syncobj_set_acquire_point_record(
    struct wp_linux_drm_syncobj_surface_v1 *syncobj_surface,
    struct wp_linux_drm_syncobj_timeline_v1 *timeline,
    uint32_t point_hi,
    uint32_t point_lo)
{
    swl_test_record_syncobj_request(
        SWL_TEST_SYNCOBJ_SET_ACQUIRE_POINT, syncobj_surface, NULL,
        timeline, -1, point_hi, point_lo);
}

static void swl_test_syncobj_set_release_point_record(
    struct wp_linux_drm_syncobj_surface_v1 *syncobj_surface,
    struct wp_linux_drm_syncobj_timeline_v1 *timeline,
    uint32_t point_hi,
    uint32_t point_lo)
{
    swl_test_record_syncobj_request(
        SWL_TEST_SYNCOBJ_SET_RELEASE_POINT, syncobj_surface, NULL,
        timeline, -1, point_hi, point_lo);
}

static void swl_test_syncobj_surface_destroy_record(
    struct wp_linux_drm_syncobj_surface_v1 *syncobj_surface)
{
    swl_test_syncobj_destroy_latest.call_count += 1;
    swl_test_syncobj_destroy_latest.kind = SWL_TEST_SYNCOBJ_DESTROY_SURFACE;
    swl_test_syncobj_destroy_latest.object = syncobj_surface;
}

static void swl_test_syncobj_timeline_destroy_record(
    struct wp_linux_drm_syncobj_timeline_v1 *timeline)
{
    swl_test_syncobj_destroy_latest.call_count += 1;
    swl_test_syncobj_destroy_latest.kind = SWL_TEST_SYNCOBJ_DESTROY_TIMELINE;
    swl_test_syncobj_destroy_latest.object = timeline;
}

static void swl_test_syncobj_manager_destroy_record(
    struct wp_linux_drm_syncobj_manager_v1 *manager)
{
    swl_test_syncobj_destroy_latest.call_count += 1;
    swl_test_syncobj_destroy_latest.kind = SWL_TEST_SYNCOBJ_DESTROY_MANAGER;
    swl_test_syncobj_destroy_latest.object = manager;
}
#else
#define swl_syncobj_get_surface_impl wp_linux_drm_syncobj_manager_v1_get_surface
#define swl_syncobj_import_timeline_impl wp_linux_drm_syncobj_manager_v1_import_timeline
#define swl_syncobj_set_acquire_point_impl wp_linux_drm_syncobj_surface_v1_set_acquire_point
#define swl_syncobj_set_release_point_impl wp_linux_drm_syncobj_surface_v1_set_release_point
#define swl_syncobj_surface_destroy_impl wp_linux_drm_syncobj_surface_v1_destroy
#define swl_syncobj_timeline_destroy_impl wp_linux_drm_syncobj_timeline_v1_destroy
#define swl_syncobj_manager_destroy_impl wp_linux_drm_syncobj_manager_v1_destroy
#endif

struct wp_linux_drm_syncobj_surface_v1 *
swl_wp_linux_drm_syncobj_manager_v1_get_surface(
    struct wp_linux_drm_syncobj_manager_v1 *manager,
    struct wl_surface *surface)
{
    return swl_syncobj_get_surface_impl(manager, surface);
}

struct wp_linux_drm_syncobj_timeline_v1 *
swl_wp_linux_drm_syncobj_manager_v1_import_timeline(
    struct wp_linux_drm_syncobj_manager_v1 *manager,
    int32_t fd)
{
    return swl_syncobj_import_timeline_impl(manager, fd);
}

void swl_wp_linux_drm_syncobj_surface_v1_set_acquire_point(
    struct wp_linux_drm_syncobj_surface_v1 *syncobj_surface,
    struct wp_linux_drm_syncobj_timeline_v1 *timeline,
    uint32_t point_hi,
    uint32_t point_lo)
{
    swl_syncobj_set_acquire_point_impl(
        syncobj_surface, timeline, point_hi, point_lo);
}

void swl_wp_linux_drm_syncobj_surface_v1_set_release_point(
    struct wp_linux_drm_syncobj_surface_v1 *syncobj_surface,
    struct wp_linux_drm_syncobj_timeline_v1 *timeline,
    uint32_t point_hi,
    uint32_t point_lo)
{
    swl_syncobj_set_release_point_impl(
        syncobj_surface, timeline, point_hi, point_lo);
}

void swl_wp_linux_drm_syncobj_surface_v1_destroy(
    struct wp_linux_drm_syncobj_surface_v1 *syncobj_surface)
{
    swl_syncobj_surface_destroy_impl(syncobj_surface);
}

void swl_wp_linux_drm_syncobj_timeline_v1_destroy(
    struct wp_linux_drm_syncobj_timeline_v1 *timeline)
{
    swl_syncobj_timeline_destroy_impl(timeline);
}

void swl_wp_linux_drm_syncobj_manager_v1_destroy(
    struct wp_linux_drm_syncobj_manager_v1 *manager)
{
    swl_syncobj_manager_destroy_impl(manager);
}

#ifdef SWL_ENABLE_TESTING
void swl_test_syncobj_request_recording_begin(void)
{
    swl_test_syncobj_request_latest =
        (struct swl_test_syncobj_request_record){
            .kind = SWL_TEST_SYNCOBJ_REQUEST_NONE,
            .fd = -1,
        };
    swl_test_syncobj_destroy_latest =
        (struct swl_test_syncobj_destroy_record){0};
    swl_syncobj_get_surface_impl = swl_test_syncobj_get_surface_record;
    swl_syncobj_import_timeline_impl = swl_test_syncobj_import_timeline_record;
    swl_syncobj_set_acquire_point_impl =
        swl_test_syncobj_set_acquire_point_record;
    swl_syncobj_set_release_point_impl =
        swl_test_syncobj_set_release_point_record;
    swl_syncobj_surface_destroy_impl = swl_test_syncobj_surface_destroy_record;
    swl_syncobj_timeline_destroy_impl = swl_test_syncobj_timeline_destroy_record;
    swl_syncobj_manager_destroy_impl = swl_test_syncobj_manager_destroy_record;
}

void swl_test_syncobj_request_recording_end(void)
{
    swl_syncobj_get_surface_impl = swl_syncobj_get_surface_default;
    swl_syncobj_import_timeline_impl = swl_syncobj_import_timeline_default;
    swl_syncobj_set_acquire_point_impl = swl_syncobj_set_acquire_point_default;
    swl_syncobj_set_release_point_impl = swl_syncobj_set_release_point_default;
    swl_syncobj_surface_destroy_impl = swl_syncobj_surface_destroy_default;
    swl_syncobj_timeline_destroy_impl = swl_syncobj_timeline_destroy_default;
    swl_syncobj_manager_destroy_impl = swl_syncobj_manager_destroy_default;
}

struct swl_test_syncobj_request_record swl_test_syncobj_request_record(void)
{
    return swl_test_syncobj_request_latest;
}

struct swl_test_syncobj_destroy_record swl_test_syncobj_destroy_record(void)
{
    return swl_test_syncobj_destroy_latest;
}
#endif

