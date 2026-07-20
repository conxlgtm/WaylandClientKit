#include "wayland-client-kit-shims.h"
#include "generated/core/wayland-client-protocol.h"

#ifdef SWL_ENABLE_TESTING
#include <pthread.h>

// Live request tests switch these hooks from the test task while requests run
// on the display thread. This mutex keeps hook changes and captured records in
// one order that ThreadSanitizer can observe.
static pthread_mutex_t swl_test_core_request_mutex = PTHREAD_MUTEX_INITIALIZER;

#define SWL_CORE_REQUEST_LOCK() \
    ((void)pthread_mutex_lock(&swl_test_core_request_mutex))
#define SWL_CORE_REQUEST_UNLOCK() \
    ((void)pthread_mutex_unlock(&swl_test_core_request_mutex))
#else
#define SWL_CORE_REQUEST_LOCK() ((void)0)
#define SWL_CORE_REQUEST_UNLOCK() ((void)0)
#endif

#if defined(WAYLAND_VERSION_MAJOR) && defined(WAYLAND_VERSION_MINOR) && \
    (WAYLAND_VERSION_MAJOR > 1 || (WAYLAND_VERSION_MAJOR == 1 && WAYLAND_VERSION_MINOR >= 23))
#define SWL_HAS_WL_PROXY_GET_QUEUE 1
#else
#define SWL_HAS_WL_PROXY_GET_QUEUE 0
#endif

#ifdef SWL_ENABLE_TESTING
static struct swl_test_core_request_record swl_test_core_request_latest;
static uint32_t swl_test_core_request_sequence;
static int swl_test_core_request_forwards_requests;

static struct wl_shm_pool *swl_shm_create_pool_default(
    struct wl_shm *shm,
    int32_t fd,
    int32_t size)
{
    return wl_shm_create_pool(shm, fd, size);
}

static struct wl_buffer *swl_shm_pool_create_buffer_default(
    struct wl_shm_pool *pool,
    int32_t offset,
    int32_t width,
    int32_t height,
    int32_t stride,
    uint32_t format)
{
    return wl_shm_pool_create_buffer(pool, offset, width, height, stride, format);
}

static void swl_surface_attach_default(
    struct wl_surface *surface,
    struct wl_buffer *buffer,
    int32_t x,
    int32_t y)
{
    wl_surface_attach(surface, buffer, x, y);
}

static void swl_surface_commit_default(struct wl_surface *surface)
{
    wl_surface_commit(surface);
}

static void swl_surface_damage_default(
    struct wl_surface *surface,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height)
{
    wl_surface_damage(surface, x, y, width, height);
}

static void swl_surface_damage_buffer_default(
    struct wl_surface *surface,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height)
{
    wl_surface_damage_buffer(surface, x, y, width, height);
}

static void swl_surface_set_opaque_region_default(
    struct wl_surface *surface,
    struct wl_region *region)
{
    wl_surface_set_opaque_region(surface, region);
}

static void swl_surface_set_input_region_default(
    struct wl_surface *surface,
    struct wl_region *region)
{
    wl_surface_set_input_region(surface, region);
}

static void swl_buffer_destroy_default(struct wl_buffer *buffer)
{
    wl_buffer_destroy(buffer);
}

static void swl_surface_destroy_default(struct wl_surface *surface)
{
    wl_surface_destroy(surface);
}

static void swl_shm_pool_destroy_default(struct wl_shm_pool *pool)
{
    wl_shm_pool_destroy(pool);
}

static void swl_shm_destroy_default(struct wl_shm *shm)
{
    wl_shm_destroy(shm);
}

static void swl_subcompositor_destroy_default(
    struct wl_subcompositor *subcompositor)
{
    wl_subcompositor_destroy(subcompositor);
}

static struct wl_subsurface *swl_subcompositor_get_subsurface_default(
    struct wl_subcompositor *subcompositor,
    struct wl_surface *surface,
    struct wl_surface *parent)
{
    return wl_subcompositor_get_subsurface(subcompositor, surface, parent);
}

static void swl_subsurface_destroy_default(struct wl_subsurface *subsurface)
{
    wl_subsurface_destroy(subsurface);
}

static void swl_subsurface_set_position_default(
    struct wl_subsurface *subsurface,
    int32_t x,
    int32_t y)
{
    wl_subsurface_set_position(subsurface, x, y);
}

static void swl_subsurface_place_above_default(
    struct wl_subsurface *subsurface,
    struct wl_surface *sibling)
{
    wl_subsurface_place_above(subsurface, sibling);
}

static void swl_subsurface_place_below_default(
    struct wl_subsurface *subsurface,
    struct wl_surface *sibling)
{
    wl_subsurface_place_below(subsurface, sibling);
}

static void swl_subsurface_set_sync_default(struct wl_subsurface *subsurface)
{
    wl_subsurface_set_sync(subsurface);
}

static void swl_subsurface_set_desync_default(struct wl_subsurface *subsurface)
{
    wl_subsurface_set_desync(subsurface);
}

static struct wl_event_queue *swl_proxy_get_queue_raw_default(void *proxy)
{
#if SWL_HAS_WL_PROXY_GET_QUEUE
    return wl_proxy_get_queue((struct wl_proxy *)proxy);
#else
    (void)proxy;
    return NULL;
#endif
}

static uint32_t swl_proxy_get_id_default(void *proxy)
{
    return wl_proxy_get_id((struct wl_proxy *)proxy);
}

static struct wl_shm_pool *(*swl_shm_create_pool_impl)(
    struct wl_shm *shm,
    int32_t fd,
    int32_t size) = swl_shm_create_pool_default;
static struct wl_buffer *(*swl_shm_pool_create_buffer_impl)(
    struct wl_shm_pool *pool,
    int32_t offset,
    int32_t width,
    int32_t height,
    int32_t stride,
    uint32_t format) = swl_shm_pool_create_buffer_default;
static void (*swl_surface_attach_impl)(
    struct wl_surface *surface,
    struct wl_buffer *buffer,
    int32_t x,
    int32_t y) = swl_surface_attach_default;
static void (*swl_surface_commit_impl)(struct wl_surface *surface) =
    swl_surface_commit_default;
static void (*swl_surface_damage_impl)(
    struct wl_surface *surface,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height) = swl_surface_damage_default;
static void (*swl_surface_damage_buffer_impl)(
    struct wl_surface *surface,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height) = swl_surface_damage_buffer_default;
static void (*swl_surface_set_opaque_region_impl)(
    struct wl_surface *surface,
    struct wl_region *region) = swl_surface_set_opaque_region_default;
static void (*swl_surface_set_input_region_impl)(
    struct wl_surface *surface,
    struct wl_region *region) = swl_surface_set_input_region_default;
static void (*swl_buffer_destroy_impl)(struct wl_buffer *buffer) =
    swl_buffer_destroy_default;
static void (*swl_surface_destroy_impl)(struct wl_surface *surface) =
    swl_surface_destroy_default;
static void (*swl_shm_pool_destroy_impl)(struct wl_shm_pool *pool) =
    swl_shm_pool_destroy_default;
static void (*swl_shm_destroy_impl)(struct wl_shm *shm) =
    swl_shm_destroy_default;
static void (*swl_subcompositor_destroy_impl)(
    struct wl_subcompositor *subcompositor) = swl_subcompositor_destroy_default;
static struct wl_subsurface *(*swl_subcompositor_get_subsurface_impl)(
    struct wl_subcompositor *subcompositor,
    struct wl_surface *surface,
    struct wl_surface *parent) = swl_subcompositor_get_subsurface_default;
static void (*swl_subsurface_destroy_impl)(struct wl_subsurface *subsurface) =
    swl_subsurface_destroy_default;
static void (*swl_subsurface_set_position_impl)(
    struct wl_subsurface *subsurface,
    int32_t x,
    int32_t y) = swl_subsurface_set_position_default;
static void (*swl_subsurface_place_above_impl)(
    struct wl_subsurface *subsurface,
    struct wl_surface *sibling) = swl_subsurface_place_above_default;
static void (*swl_subsurface_place_below_impl)(
    struct wl_subsurface *subsurface,
    struct wl_surface *sibling) = swl_subsurface_place_below_default;
static void (*swl_subsurface_set_sync_impl)(struct wl_subsurface *subsurface) =
    swl_subsurface_set_sync_default;
static void (*swl_subsurface_set_desync_impl)(struct wl_subsurface *subsurface) =
    swl_subsurface_set_desync_default;
static struct wl_event_queue *(*swl_proxy_get_queue_raw_impl)(void *proxy) =
    swl_proxy_get_queue_raw_default;
static uint32_t (*swl_proxy_get_id_impl)(void *proxy) =
    swl_proxy_get_id_default;

static uint32_t swl_test_core_next_sequence(void)
{
    swl_test_core_request_sequence += 1;
    swl_test_core_request_latest.latest_sequence =
        swl_test_core_request_sequence;
    return swl_test_core_request_sequence;
}

static void swl_test_record_core_request(
    enum swl_test_core_request_kind kind,
    void *object)
{
    swl_test_core_request_latest.call_count += 1;
    swl_test_core_request_latest.kind = kind;
    swl_test_core_request_latest.object = object;
    swl_test_core_next_sequence();
}

static struct wl_shm_pool *swl_test_shm_create_pool_record(
    struct wl_shm *shm,
    int32_t fd,
    int32_t size)
{
    swl_test_record_core_request(SWL_TEST_CORE_SHM_CREATE_POOL, shm);
    swl_test_core_request_latest.fd = fd;
    swl_test_core_request_latest.size = size;
    if (swl_test_core_request_forwards_requests)
        return swl_shm_create_pool_default(shm, fd, size);
    return (struct wl_shm_pool *)0x5101;
}

static struct wl_buffer *swl_test_shm_pool_create_buffer_record(
    struct wl_shm_pool *pool,
    int32_t offset,
    int32_t width,
    int32_t height,
    int32_t stride,
    uint32_t format)
{
    swl_test_record_core_request(SWL_TEST_CORE_SHM_POOL_CREATE_BUFFER, pool);
    swl_test_core_request_latest.offset = offset;
    swl_test_core_request_latest.width = width;
    swl_test_core_request_latest.height = height;
    swl_test_core_request_latest.stride = stride;
    swl_test_core_request_latest.format = format;
    if (swl_test_core_request_forwards_requests) {
        return swl_shm_pool_create_buffer_default(
            pool, offset, width, height, stride, format);
    }
    return (struct wl_buffer *)0x5202;
}

static void swl_test_surface_attach_record(
    struct wl_surface *surface,
    struct wl_buffer *buffer,
    int32_t x,
    int32_t y)
{
    swl_test_record_core_request(SWL_TEST_CORE_SURFACE_ATTACH, surface);
    swl_test_core_request_latest.buffer = buffer;
    swl_test_core_request_latest.x = x;
    swl_test_core_request_latest.y = y;
    swl_test_core_request_latest.attach_sequence =
        swl_test_core_request_latest.latest_sequence;
    if (swl_test_core_request_forwards_requests)
        swl_surface_attach_default(surface, buffer, x, y);
}

static void swl_test_surface_commit_record(struct wl_surface *surface)
{
    swl_test_record_core_request(SWL_TEST_CORE_SURFACE_COMMIT, surface);
    swl_test_core_request_latest.commit_sequence =
        swl_test_core_request_latest.latest_sequence;
    if (swl_test_core_request_forwards_requests)
        swl_surface_commit_default(surface);
}

static void swl_test_surface_damage_record(
    enum swl_test_core_request_kind kind,
    struct wl_surface *surface,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height)
{
    swl_test_record_core_request(kind, surface);
    swl_test_core_request_latest.x = x;
    swl_test_core_request_latest.y = y;
    swl_test_core_request_latest.width = width;
    swl_test_core_request_latest.height = height;
    swl_test_core_request_latest.damage_sequence =
        swl_test_core_request_latest.latest_sequence;
}

static void swl_test_surface_damage_legacy_record(
    struct wl_surface *surface,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height)
{
    swl_test_surface_damage_record(
        SWL_TEST_CORE_SURFACE_DAMAGE, surface, x, y, width, height);
    if (swl_test_core_request_forwards_requests)
        swl_surface_damage_default(surface, x, y, width, height);
}

static void swl_test_surface_damage_buffer_record(
    struct wl_surface *surface,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height)
{
    swl_test_surface_damage_record(
        SWL_TEST_CORE_SURFACE_DAMAGE_BUFFER, surface, x, y, width, height);
    if (swl_test_core_request_forwards_requests)
        swl_surface_damage_buffer_default(surface, x, y, width, height);
}

static void swl_test_surface_set_region_record(
    enum swl_test_core_request_kind kind,
    struct wl_surface *surface,
    struct wl_region *region)
{
    swl_test_record_core_request(kind, surface);
    swl_test_core_request_latest.region = region;
    if (kind == SWL_TEST_CORE_SURFACE_SET_OPAQUE_REGION) {
        swl_test_core_request_latest.opaque_region_sequence =
            swl_test_core_request_latest.latest_sequence;
    } else {
        swl_test_core_request_latest.input_region_sequence =
            swl_test_core_request_latest.latest_sequence;
    }
}

static void swl_test_surface_set_opaque_region_record(
    struct wl_surface *surface,
    struct wl_region *region)
{
    swl_test_surface_set_region_record(
        SWL_TEST_CORE_SURFACE_SET_OPAQUE_REGION, surface, region);
    if (swl_test_core_request_forwards_requests)
        swl_surface_set_opaque_region_default(surface, region);
}

static void swl_test_surface_set_input_region_record(
    struct wl_surface *surface,
    struct wl_region *region)
{
    swl_test_surface_set_region_record(
        SWL_TEST_CORE_SURFACE_SET_INPUT_REGION, surface, region);
    if (swl_test_core_request_forwards_requests)
        swl_surface_set_input_region_default(surface, region);
}

static void swl_test_buffer_destroy_record(struct wl_buffer *buffer)
{
    swl_test_record_core_request(SWL_TEST_CORE_BUFFER_DESTROY, buffer);
    swl_test_core_request_latest.buffer_destroy_sequence =
        swl_test_core_request_latest.latest_sequence;
    if (swl_test_core_request_forwards_requests)
        swl_buffer_destroy_default(buffer);
}

static void swl_test_surface_destroy_record(struct wl_surface *surface)
{
    swl_test_record_core_request(SWL_TEST_CORE_SURFACE_DESTROY, surface);
    swl_test_core_request_latest.surface_destroy_sequence =
        swl_test_core_request_latest.latest_sequence;
    if (swl_test_core_request_forwards_requests)
        swl_surface_destroy_default(surface);
}

static void swl_test_shm_pool_destroy_record(struct wl_shm_pool *pool)
{
    swl_test_record_core_request(SWL_TEST_CORE_SHM_POOL_DESTROY, pool);
    swl_test_core_request_latest.shm_pool_destroy_sequence =
        swl_test_core_request_latest.latest_sequence;
    if (swl_test_core_request_forwards_requests)
        swl_shm_pool_destroy_default(pool);
}

static void swl_test_shm_destroy_record(struct wl_shm *shm)
{
    swl_test_record_core_request(SWL_TEST_CORE_SHM_DESTROY, shm);
    if (swl_test_core_request_forwards_requests)
        swl_shm_destroy_default(shm);
}

static void swl_test_subcompositor_destroy_record(
    struct wl_subcompositor *subcompositor)
{
    swl_test_record_core_request(
        SWL_TEST_CORE_SUBCOMPOSITOR_DESTROY, subcompositor);
    if (swl_test_core_request_forwards_requests)
        swl_subcompositor_destroy_default(subcompositor);
}

static struct wl_subsurface *swl_test_subcompositor_get_subsurface_record(
    struct wl_subcompositor *subcompositor,
    struct wl_surface *surface,
    struct wl_surface *parent)
{
    swl_test_record_core_request(
        SWL_TEST_CORE_SUBCOMPOSITOR_GET_SUBSURFACE, subcompositor);
    swl_test_core_request_latest.surface = surface;
    swl_test_core_request_latest.parent = parent;
    if (swl_test_core_request_forwards_requests) {
        return swl_subcompositor_get_subsurface_default(
            subcompositor, surface, parent);
    }
    swl_test_core_request_latest.subsurface = (struct wl_subsurface *)0x5303;
    return swl_test_core_request_latest.subsurface;
}

static void swl_test_subsurface_destroy_record(struct wl_subsurface *subsurface)
{
    swl_test_record_core_request(SWL_TEST_CORE_SUBSURFACE_DESTROY, subsurface);
    swl_test_core_request_latest.subsurface = subsurface;
    if (swl_test_core_request_forwards_requests)
        swl_subsurface_destroy_default(subsurface);
}

static void swl_test_subsurface_set_position_record(
    struct wl_subsurface *subsurface,
    int32_t x,
    int32_t y)
{
    swl_test_record_core_request(
        SWL_TEST_CORE_SUBSURFACE_SET_POSITION, subsurface);
    swl_test_core_request_latest.subsurface = subsurface;
    swl_test_core_request_latest.x = x;
    swl_test_core_request_latest.y = y;
    if (swl_test_core_request_forwards_requests)
        swl_subsurface_set_position_default(subsurface, x, y);
}

static void swl_test_subsurface_place_record(
    enum swl_test_core_request_kind kind,
    struct wl_subsurface *subsurface,
    struct wl_surface *sibling)
{
    swl_test_record_core_request(kind, subsurface);
    swl_test_core_request_latest.subsurface = subsurface;
    swl_test_core_request_latest.sibling = sibling;
}

static void swl_test_subsurface_place_above_record(
    struct wl_subsurface *subsurface,
    struct wl_surface *sibling)
{
    swl_test_subsurface_place_record(
        SWL_TEST_CORE_SUBSURFACE_PLACE_ABOVE, subsurface, sibling);
    if (swl_test_core_request_forwards_requests)
        swl_subsurface_place_above_default(subsurface, sibling);
}

static void swl_test_subsurface_place_below_record(
    struct wl_subsurface *subsurface,
    struct wl_surface *sibling)
{
    swl_test_subsurface_place_record(
        SWL_TEST_CORE_SUBSURFACE_PLACE_BELOW, subsurface, sibling);
    if (swl_test_core_request_forwards_requests)
        swl_subsurface_place_below_default(subsurface, sibling);
}

static void swl_test_subsurface_sync_record(
    enum swl_test_core_request_kind kind,
    struct wl_subsurface *subsurface)
{
    swl_test_record_core_request(kind, subsurface);
    swl_test_core_request_latest.subsurface = subsurface;
}

static void swl_test_subsurface_set_sync_record(struct wl_subsurface *subsurface)
{
    swl_test_subsurface_sync_record(SWL_TEST_CORE_SUBSURFACE_SET_SYNC, subsurface);
    if (swl_test_core_request_forwards_requests)
        swl_subsurface_set_sync_default(subsurface);
}

static void swl_test_subsurface_set_desync_record(
    struct wl_subsurface *subsurface)
{
    swl_test_subsurface_sync_record(
        SWL_TEST_CORE_SUBSURFACE_SET_DESYNC, subsurface);
    if (swl_test_core_request_forwards_requests)
        swl_subsurface_set_desync_default(subsurface);
}

static struct wl_event_queue *swl_test_proxy_get_queue_raw(void *proxy)
{
    if (swl_test_core_request_forwards_requests)
        return swl_proxy_get_queue_raw_default(proxy);
    (void)proxy;
    return NULL;
}

static uint32_t swl_test_proxy_get_id(void *proxy)
{
    if (swl_test_core_request_forwards_requests)
        return swl_proxy_get_id_default(proxy);
    (void)proxy;
    return 42;
}
#else
#define swl_shm_create_pool_impl wl_shm_create_pool
#define swl_shm_pool_create_buffer_impl wl_shm_pool_create_buffer
#define swl_surface_attach_impl wl_surface_attach
#define swl_surface_commit_impl wl_surface_commit
#define swl_surface_damage_impl wl_surface_damage
#define swl_surface_damage_buffer_impl wl_surface_damage_buffer
#define swl_surface_set_opaque_region_impl wl_surface_set_opaque_region
#define swl_surface_set_input_region_impl wl_surface_set_input_region
#define swl_buffer_destroy_impl wl_buffer_destroy
#define swl_surface_destroy_impl wl_surface_destroy
#define swl_shm_pool_destroy_impl wl_shm_pool_destroy
#define swl_shm_destroy_impl wl_shm_destroy
#define swl_subcompositor_destroy_impl wl_subcompositor_destroy
#define swl_subcompositor_get_subsurface_impl wl_subcompositor_get_subsurface
#define swl_subsurface_destroy_impl wl_subsurface_destroy
#define swl_subsurface_set_position_impl wl_subsurface_set_position
#define swl_subsurface_place_above_impl wl_subsurface_place_above
#define swl_subsurface_place_below_impl wl_subsurface_place_below
#define swl_subsurface_set_sync_impl wl_subsurface_set_sync
#define swl_subsurface_set_desync_impl wl_subsurface_set_desync
#endif

struct wl_shm_pool *swl_shm_create_pool(struct wl_shm *shm, int32_t fd, int32_t size)
{
    SWL_CORE_REQUEST_LOCK();
    struct wl_shm_pool *pool = swl_shm_create_pool_impl(shm, fd, size);
    SWL_CORE_REQUEST_UNLOCK();
    return pool;
}

struct wl_buffer *swl_shm_pool_create_buffer(
    struct wl_shm_pool *pool, int32_t offset, int32_t width,
    int32_t height, int32_t stride, uint32_t format)
{
    SWL_CORE_REQUEST_LOCK();
    struct wl_buffer *buffer = swl_shm_pool_create_buffer_impl(
        pool, offset, width, height, stride, format);
    SWL_CORE_REQUEST_UNLOCK();
    return buffer;
}

void swl_surface_attach(
    struct wl_surface *surface, struct wl_buffer *buffer, int32_t x, int32_t y)
{
    SWL_CORE_REQUEST_LOCK();
    swl_surface_attach_impl(surface, buffer, x, y);
    SWL_CORE_REQUEST_UNLOCK();
}

void swl_surface_commit(struct wl_surface *surface)
{
    SWL_CORE_REQUEST_LOCK();
    swl_surface_commit_impl(surface);
    SWL_CORE_REQUEST_UNLOCK();
}

void swl_surface_damage(
    struct wl_surface *surface, int32_t x, int32_t y,
    int32_t width, int32_t height)
{
    SWL_CORE_REQUEST_LOCK();
    swl_surface_damage_impl(surface, x, y, width, height);
    SWL_CORE_REQUEST_UNLOCK();
}

uint32_t swl_shm_format_xrgb8888(void)
{
    return WL_SHM_FORMAT_XRGB8888;
}

uint32_t swl_shm_format_argb8888(void)
{
    return WL_SHM_FORMAT_ARGB8888;
}

void swl_surface_damage_buffer(
    struct wl_surface *surface, int32_t x, int32_t y,
    int32_t width, int32_t height)
{
    SWL_CORE_REQUEST_LOCK();
    swl_surface_damage_buffer_impl(surface, x, y, width, height);
    SWL_CORE_REQUEST_UNLOCK();
}

void swl_surface_set_opaque_region(
    struct wl_surface *surface,
    struct wl_region *region)
{
    SWL_CORE_REQUEST_LOCK();
    swl_surface_set_opaque_region_impl(surface, region);
    SWL_CORE_REQUEST_UNLOCK();
}

void swl_surface_set_input_region(
    struct wl_surface *surface,
    struct wl_region *region)
{
    SWL_CORE_REQUEST_LOCK();
    swl_surface_set_input_region_impl(surface, region);
    SWL_CORE_REQUEST_UNLOCK();
}

uint32_t swl_proxy_get_version(void *proxy)
{
    return wl_proxy_get_version((struct wl_proxy *)proxy);
}

uint32_t swl_proxy_get_id(void *proxy)
{
#ifdef SWL_ENABLE_TESTING
    SWL_CORE_REQUEST_LOCK();
    uint32_t id = swl_proxy_get_id_impl(proxy);
    SWL_CORE_REQUEST_UNLOCK();
    return id;
#else
    return wl_proxy_get_id((struct wl_proxy *)proxy);
#endif
}

struct wl_event_queue *swl_proxy_get_queue_raw(void *proxy)
{
#ifdef SWL_ENABLE_TESTING
    SWL_CORE_REQUEST_LOCK();
    struct wl_event_queue *queue = swl_proxy_get_queue_raw_impl(proxy);
    SWL_CORE_REQUEST_UNLOCK();
    return queue;
#elif SWL_HAS_WL_PROXY_GET_QUEUE
    return wl_proxy_get_queue((struct wl_proxy *)proxy);
#else
    (void)proxy;
    return NULL;
#endif
}

void swl_registry_destroy(struct wl_registry *registry)
{
    wl_registry_destroy(registry);
}

void swl_callback_destroy(struct wl_callback *callback)
{
    wl_callback_destroy(callback);
}

void swl_compositor_destroy(struct wl_compositor *compositor)
{
    wl_compositor_destroy(compositor);
}

void swl_shm_destroy(struct wl_shm *shm)
{
    SWL_CORE_REQUEST_LOCK();
    swl_shm_destroy_impl(shm);
    SWL_CORE_REQUEST_UNLOCK();
}

void swl_subcompositor_destroy(struct wl_subcompositor *subcompositor)
{
    SWL_CORE_REQUEST_LOCK();
    swl_subcompositor_destroy_impl(subcompositor);
    SWL_CORE_REQUEST_UNLOCK();
}

struct wl_subsurface *swl_subcompositor_get_subsurface(
    struct wl_subcompositor *subcompositor,
    struct wl_surface *surface,
    struct wl_surface *parent)
{
    SWL_CORE_REQUEST_LOCK();
    struct wl_subsurface *subsurface =
        swl_subcompositor_get_subsurface_impl(subcompositor, surface, parent);
    SWL_CORE_REQUEST_UNLOCK();
    return subsurface;
}

void swl_subsurface_destroy(struct wl_subsurface *subsurface)
{
    SWL_CORE_REQUEST_LOCK();
    swl_subsurface_destroy_impl(subsurface);
    SWL_CORE_REQUEST_UNLOCK();
}

void swl_subsurface_set_position(
    struct wl_subsurface *subsurface,
    int32_t x,
    int32_t y)
{
    SWL_CORE_REQUEST_LOCK();
    swl_subsurface_set_position_impl(subsurface, x, y);
    SWL_CORE_REQUEST_UNLOCK();
}

void swl_subsurface_place_above(
    struct wl_subsurface *subsurface,
    struct wl_surface *sibling)
{
    SWL_CORE_REQUEST_LOCK();
    swl_subsurface_place_above_impl(subsurface, sibling);
    SWL_CORE_REQUEST_UNLOCK();
}

void swl_subsurface_place_below(
    struct wl_subsurface *subsurface,
    struct wl_surface *sibling)
{
    SWL_CORE_REQUEST_LOCK();
    swl_subsurface_place_below_impl(subsurface, sibling);
    SWL_CORE_REQUEST_UNLOCK();
}

void swl_subsurface_set_sync(struct wl_subsurface *subsurface)
{
    SWL_CORE_REQUEST_LOCK();
    swl_subsurface_set_sync_impl(subsurface);
    SWL_CORE_REQUEST_UNLOCK();
}

void swl_subsurface_set_desync(struct wl_subsurface *subsurface)
{
    SWL_CORE_REQUEST_LOCK();
    swl_subsurface_set_desync_impl(subsurface);
    SWL_CORE_REQUEST_UNLOCK();
}

void swl_output_destroy(struct wl_output *output)
{
    wl_output_destroy(output);
}

void swl_buffer_destroy(struct wl_buffer *buffer)
{
    SWL_CORE_REQUEST_LOCK();
    swl_buffer_destroy_impl(buffer);
    SWL_CORE_REQUEST_UNLOCK();
}

void swl_surface_destroy(struct wl_surface *surface)
{
    SWL_CORE_REQUEST_LOCK();
    swl_surface_destroy_impl(surface);
    SWL_CORE_REQUEST_UNLOCK();
}

void swl_shm_pool_destroy(struct wl_shm_pool *pool)
{
    SWL_CORE_REQUEST_LOCK();
    swl_shm_pool_destroy_impl(pool);
    SWL_CORE_REQUEST_UNLOCK();
}

void swl_seat_destroy(struct wl_seat *seat)
{
    wl_seat_destroy(seat);
}

#ifdef SWL_ENABLE_TESTING
static void swl_test_core_request_recording_start(int forwards_requests)
{
    swl_test_core_request_latest = (struct swl_test_core_request_record){0};
    swl_test_core_request_sequence = 0;
    swl_test_core_request_forwards_requests = forwards_requests;
    swl_shm_create_pool_impl = swl_test_shm_create_pool_record;
    swl_shm_pool_create_buffer_impl = swl_test_shm_pool_create_buffer_record;
    swl_surface_attach_impl = swl_test_surface_attach_record;
    swl_surface_commit_impl = swl_test_surface_commit_record;
    swl_surface_damage_impl = swl_test_surface_damage_legacy_record;
    swl_surface_damage_buffer_impl = swl_test_surface_damage_buffer_record;
    swl_surface_set_opaque_region_impl = swl_test_surface_set_opaque_region_record;
    swl_surface_set_input_region_impl = swl_test_surface_set_input_region_record;
    swl_buffer_destroy_impl = swl_test_buffer_destroy_record;
    swl_surface_destroy_impl = swl_test_surface_destroy_record;
    swl_shm_pool_destroy_impl = swl_test_shm_pool_destroy_record;
    swl_shm_destroy_impl = swl_test_shm_destroy_record;
    swl_subcompositor_destroy_impl = swl_test_subcompositor_destroy_record;
    swl_subcompositor_get_subsurface_impl =
        swl_test_subcompositor_get_subsurface_record;
    swl_subsurface_destroy_impl = swl_test_subsurface_destroy_record;
    swl_subsurface_set_position_impl = swl_test_subsurface_set_position_record;
    swl_subsurface_place_above_impl = swl_test_subsurface_place_above_record;
    swl_subsurface_place_below_impl = swl_test_subsurface_place_below_record;
    swl_subsurface_set_sync_impl = swl_test_subsurface_set_sync_record;
    swl_subsurface_set_desync_impl = swl_test_subsurface_set_desync_record;
    swl_proxy_get_queue_raw_impl = swl_test_proxy_get_queue_raw;
    swl_proxy_get_id_impl = swl_test_proxy_get_id;
}

void swl_test_core_request_recording_begin(void)
{
    SWL_CORE_REQUEST_LOCK();
    swl_test_core_request_recording_start(0);
    SWL_CORE_REQUEST_UNLOCK();
}

void swl_test_core_request_recording_begin_forwarding(void)
{
    SWL_CORE_REQUEST_LOCK();
    swl_test_core_request_recording_start(1);
    SWL_CORE_REQUEST_UNLOCK();
}

void swl_test_core_request_recording_end(void)
{
    SWL_CORE_REQUEST_LOCK();
    swl_test_core_request_forwards_requests = 0;
    swl_shm_create_pool_impl = swl_shm_create_pool_default;
    swl_shm_pool_create_buffer_impl = swl_shm_pool_create_buffer_default;
    swl_surface_attach_impl = swl_surface_attach_default;
    swl_surface_commit_impl = swl_surface_commit_default;
    swl_surface_damage_impl = swl_surface_damage_default;
    swl_surface_damage_buffer_impl = swl_surface_damage_buffer_default;
    swl_surface_set_opaque_region_impl = swl_surface_set_opaque_region_default;
    swl_surface_set_input_region_impl = swl_surface_set_input_region_default;
    swl_buffer_destroy_impl = swl_buffer_destroy_default;
    swl_surface_destroy_impl = swl_surface_destroy_default;
    swl_shm_pool_destroy_impl = swl_shm_pool_destroy_default;
    swl_shm_destroy_impl = swl_shm_destroy_default;
    swl_subcompositor_destroy_impl = swl_subcompositor_destroy_default;
    swl_subcompositor_get_subsurface_impl =
        swl_subcompositor_get_subsurface_default;
    swl_subsurface_destroy_impl = swl_subsurface_destroy_default;
    swl_subsurface_set_position_impl = swl_subsurface_set_position_default;
    swl_subsurface_place_above_impl = swl_subsurface_place_above_default;
    swl_subsurface_place_below_impl = swl_subsurface_place_below_default;
    swl_subsurface_set_sync_impl = swl_subsurface_set_sync_default;
    swl_subsurface_set_desync_impl = swl_subsurface_set_desync_default;
    swl_proxy_get_queue_raw_impl = swl_proxy_get_queue_raw_default;
    swl_proxy_get_id_impl = swl_proxy_get_id_default;
    SWL_CORE_REQUEST_UNLOCK();
}

struct swl_test_core_request_record swl_test_core_request_record(void)
{
    SWL_CORE_REQUEST_LOCK();
    struct swl_test_core_request_record record = swl_test_core_request_latest;
    SWL_CORE_REQUEST_UNLOCK();
    return record;
}
#endif
