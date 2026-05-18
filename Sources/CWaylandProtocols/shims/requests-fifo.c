#include "swift-wayland-shims.h"
#include "generated/staging/fifo/fifo-v1-client-protocol.h"

#ifdef SWL_ENABLE_TESTING
static struct swl_test_fifo_request_record swl_test_fifo_request_latest;
static struct swl_test_fifo_destroy_record swl_test_fifo_destroy_latest;

static struct wp_fifo_v1 *swl_fifo_get_fifo_default(
    struct wp_fifo_manager_v1 *manager,
    struct wl_surface *surface)
{
    return wp_fifo_manager_v1_get_fifo(manager, surface);
}

static void swl_fifo_set_barrier_default(struct wp_fifo_v1 *fifo)
{
    wp_fifo_v1_set_barrier(fifo);
}

static void swl_fifo_wait_barrier_default(struct wp_fifo_v1 *fifo)
{
    wp_fifo_v1_wait_barrier(fifo);
}

static void swl_fifo_destroy_default(struct wp_fifo_v1 *fifo)
{
    wp_fifo_v1_destroy(fifo);
}

static void swl_fifo_manager_destroy_default(struct wp_fifo_manager_v1 *manager)
{
    wp_fifo_manager_v1_destroy(manager);
}

static struct wp_fifo_v1 *(*swl_fifo_get_fifo_impl)(
    struct wp_fifo_manager_v1 *manager,
    struct wl_surface *surface) =
        swl_fifo_get_fifo_default;
static void (*swl_fifo_set_barrier_impl)(struct wp_fifo_v1 *fifo) =
    swl_fifo_set_barrier_default;
static void (*swl_fifo_wait_barrier_impl)(struct wp_fifo_v1 *fifo) =
    swl_fifo_wait_barrier_default;
static void (*swl_fifo_destroy_impl)(struct wp_fifo_v1 *fifo) =
    swl_fifo_destroy_default;
static void (*swl_fifo_manager_destroy_impl)(struct wp_fifo_manager_v1 *manager) =
    swl_fifo_manager_destroy_default;

static void swl_test_record_fifo_request(
    enum swl_test_fifo_request_kind kind,
    void *object,
    void *surface)
{
    swl_test_fifo_request_latest.call_count += 1;
    swl_test_fifo_request_latest.kind = kind;
    swl_test_fifo_request_latest.object = object;
    swl_test_fifo_request_latest.surface = surface;
}

static struct wp_fifo_v1 *swl_test_fifo_get_fifo_record(
    struct wp_fifo_manager_v1 *manager,
    struct wl_surface *surface)
{
    swl_test_record_fifo_request(SWL_TEST_FIFO_GET_FIFO, manager, surface);
    return (struct wp_fifo_v1 *)0xF501;
}

static void swl_test_fifo_set_barrier_record(struct wp_fifo_v1 *fifo)
{
    swl_test_record_fifo_request(SWL_TEST_FIFO_SET_BARRIER, fifo, NULL);
}

static void swl_test_fifo_wait_barrier_record(struct wp_fifo_v1 *fifo)
{
    swl_test_record_fifo_request(SWL_TEST_FIFO_WAIT_BARRIER, fifo, NULL);
}

static void swl_test_fifo_destroy_fifo_record(struct wp_fifo_v1 *fifo)
{
    swl_test_fifo_destroy_latest.call_count += 1;
    swl_test_fifo_destroy_latest.kind = SWL_TEST_FIFO_DESTROY_FIFO;
    swl_test_fifo_destroy_latest.object = fifo;
}

static void swl_test_fifo_manager_destroy_record(struct wp_fifo_manager_v1 *manager)
{
    swl_test_fifo_destroy_latest.call_count += 1;
    swl_test_fifo_destroy_latest.kind = SWL_TEST_FIFO_DESTROY_MANAGER;
    swl_test_fifo_destroy_latest.object = manager;
}
#else
#define swl_fifo_get_fifo_impl wp_fifo_manager_v1_get_fifo
#define swl_fifo_set_barrier_impl wp_fifo_v1_set_barrier
#define swl_fifo_wait_barrier_impl wp_fifo_v1_wait_barrier
#define swl_fifo_destroy_impl wp_fifo_v1_destroy
#define swl_fifo_manager_destroy_impl wp_fifo_manager_v1_destroy
#endif

struct wp_fifo_v1 *swl_wp_fifo_manager_v1_get_fifo(
    struct wp_fifo_manager_v1 *manager,
    struct wl_surface *surface)
{
    return swl_fifo_get_fifo_impl(manager, surface);
}

void swl_wp_fifo_v1_set_barrier(struct wp_fifo_v1 *fifo)
{
    swl_fifo_set_barrier_impl(fifo);
}

void swl_wp_fifo_v1_wait_barrier(struct wp_fifo_v1 *fifo)
{
    swl_fifo_wait_barrier_impl(fifo);
}

void swl_wp_fifo_v1_destroy(struct wp_fifo_v1 *fifo)
{
    swl_fifo_destroy_impl(fifo);
}

void swl_wp_fifo_manager_v1_destroy(struct wp_fifo_manager_v1 *manager)
{
    swl_fifo_manager_destroy_impl(manager);
}

#ifdef SWL_ENABLE_TESTING
void swl_test_fifo_request_recording_begin(void)
{
    swl_test_fifo_request_latest =
        (struct swl_test_fifo_request_record){
            .kind = SWL_TEST_FIFO_REQUEST_NONE,
        };
    swl_test_fifo_destroy_latest = (struct swl_test_fifo_destroy_record){0};
    swl_fifo_get_fifo_impl = swl_test_fifo_get_fifo_record;
    swl_fifo_set_barrier_impl = swl_test_fifo_set_barrier_record;
    swl_fifo_wait_barrier_impl = swl_test_fifo_wait_barrier_record;
    swl_fifo_destroy_impl = swl_test_fifo_destroy_fifo_record;
    swl_fifo_manager_destroy_impl = swl_test_fifo_manager_destroy_record;
}

void swl_test_fifo_request_recording_end(void)
{
    swl_fifo_get_fifo_impl = swl_fifo_get_fifo_default;
    swl_fifo_set_barrier_impl = swl_fifo_set_barrier_default;
    swl_fifo_wait_barrier_impl = swl_fifo_wait_barrier_default;
    swl_fifo_destroy_impl = swl_fifo_destroy_default;
    swl_fifo_manager_destroy_impl = swl_fifo_manager_destroy_default;
}

struct swl_test_fifo_request_record swl_test_fifo_request_record(void)
{
    return swl_test_fifo_request_latest;
}

struct swl_test_fifo_destroy_record swl_test_fifo_destroy_record(void)
{
    return swl_test_fifo_destroy_latest;
}
#endif
