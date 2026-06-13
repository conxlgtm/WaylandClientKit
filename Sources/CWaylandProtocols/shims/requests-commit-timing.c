#include "wayland-client-kit-shims.h"
#include "generated/staging/commit-timing/commit-timing-v1-client-protocol.h"

#ifdef SWL_ENABLE_TESTING
static struct swl_test_commit_timing_request_record
    swl_test_commit_timing_request_latest;
static struct swl_test_commit_timing_destroy_record
    swl_test_commit_timing_destroy_latest;

static struct wp_commit_timer_v1 *swl_commit_timing_get_timer_default(
    struct wp_commit_timing_manager_v1 *manager,
    struct wl_surface *surface)
{
    return wp_commit_timing_manager_v1_get_timer(manager, surface);
}

static void swl_commit_timing_set_timestamp_default(
    struct wp_commit_timer_v1 *timer,
    uint32_t tv_sec_hi,
    uint32_t tv_sec_lo,
    uint32_t tv_nsec)
{
    wp_commit_timer_v1_set_timestamp(timer, tv_sec_hi, tv_sec_lo, tv_nsec);
}

static void swl_commit_timer_destroy_default(struct wp_commit_timer_v1 *timer)
{
    wp_commit_timer_v1_destroy(timer);
}

static void swl_commit_timing_manager_destroy_default(
    struct wp_commit_timing_manager_v1 *manager)
{
    wp_commit_timing_manager_v1_destroy(manager);
}

static struct wp_commit_timer_v1 *(*swl_commit_timing_get_timer_impl)(
    struct wp_commit_timing_manager_v1 *manager,
    struct wl_surface *surface) =
        swl_commit_timing_get_timer_default;
static void (*swl_commit_timing_set_timestamp_impl)(
    struct wp_commit_timer_v1 *timer,
    uint32_t tv_sec_hi,
    uint32_t tv_sec_lo,
    uint32_t tv_nsec) =
        swl_commit_timing_set_timestamp_default;
static void (*swl_commit_timer_destroy_impl)(struct wp_commit_timer_v1 *timer) =
    swl_commit_timer_destroy_default;
static void (*swl_commit_timing_manager_destroy_impl)(
    struct wp_commit_timing_manager_v1 *manager) =
        swl_commit_timing_manager_destroy_default;

static void swl_test_record_commit_timing_request(
    enum swl_test_commit_timing_request_kind kind,
    void *object,
    void *surface,
    uint32_t tv_sec_hi,
    uint32_t tv_sec_lo,
    uint32_t tv_nsec)
{
    swl_test_commit_timing_request_latest.call_count += 1;
    swl_test_commit_timing_request_latest.kind = kind;
    swl_test_commit_timing_request_latest.object = object;
    swl_test_commit_timing_request_latest.surface = surface;
    swl_test_commit_timing_request_latest.tv_sec_hi = tv_sec_hi;
    swl_test_commit_timing_request_latest.tv_sec_lo = tv_sec_lo;
    swl_test_commit_timing_request_latest.tv_nsec = tv_nsec;
}

static struct wp_commit_timer_v1 *swl_test_commit_timing_get_timer_record(
    struct wp_commit_timing_manager_v1 *manager,
    struct wl_surface *surface)
{
    swl_test_record_commit_timing_request(
        SWL_TEST_COMMIT_TIMING_GET_TIMER, manager, surface, 0, 0, 0);
    return (struct wp_commit_timer_v1 *)0xC701;
}

static void swl_test_commit_timing_set_timestamp_record(
    struct wp_commit_timer_v1 *timer,
    uint32_t tv_sec_hi,
    uint32_t tv_sec_lo,
    uint32_t tv_nsec)
{
    swl_test_record_commit_timing_request(
        SWL_TEST_COMMIT_TIMING_SET_TIMESTAMP, timer, NULL,
        tv_sec_hi, tv_sec_lo, tv_nsec);
}

static void swl_test_commit_timer_destroy_record(struct wp_commit_timer_v1 *timer)
{
    swl_test_commit_timing_destroy_latest.call_count += 1;
    swl_test_commit_timing_destroy_latest.kind =
        SWL_TEST_COMMIT_TIMING_DESTROY_TIMER;
    swl_test_commit_timing_destroy_latest.object = timer;
}

static void swl_test_commit_timing_manager_destroy_record(
    struct wp_commit_timing_manager_v1 *manager)
{
    swl_test_commit_timing_destroy_latest.call_count += 1;
    swl_test_commit_timing_destroy_latest.kind =
        SWL_TEST_COMMIT_TIMING_DESTROY_MANAGER;
    swl_test_commit_timing_destroy_latest.object = manager;
}
#else
#define swl_commit_timing_get_timer_impl wp_commit_timing_manager_v1_get_timer
#define swl_commit_timing_set_timestamp_impl wp_commit_timer_v1_set_timestamp
#define swl_commit_timer_destroy_impl wp_commit_timer_v1_destroy
#define swl_commit_timing_manager_destroy_impl wp_commit_timing_manager_v1_destroy
#endif

struct wp_commit_timer_v1 *swl_wp_commit_timing_manager_v1_get_timer(
    struct wp_commit_timing_manager_v1 *manager,
    struct wl_surface *surface)
{
    return swl_commit_timing_get_timer_impl(manager, surface);
}

void swl_wp_commit_timer_v1_set_timestamp(
    struct wp_commit_timer_v1 *timer,
    uint32_t tv_sec_hi,
    uint32_t tv_sec_lo,
    uint32_t tv_nsec)
{
    swl_commit_timing_set_timestamp_impl(
        timer, tv_sec_hi, tv_sec_lo, tv_nsec);
}

void swl_wp_commit_timer_v1_destroy(struct wp_commit_timer_v1 *timer)
{
    swl_commit_timer_destroy_impl(timer);
}

void swl_wp_commit_timing_manager_v1_destroy(
    struct wp_commit_timing_manager_v1 *manager)
{
    swl_commit_timing_manager_destroy_impl(manager);
}

#ifdef SWL_ENABLE_TESTING
void swl_test_commit_timing_request_recording_begin(void)
{
    swl_test_commit_timing_request_latest =
        (struct swl_test_commit_timing_request_record){
            .kind = SWL_TEST_COMMIT_TIMING_REQUEST_NONE,
        };
    swl_test_commit_timing_destroy_latest =
        (struct swl_test_commit_timing_destroy_record){0};
    swl_commit_timing_get_timer_impl =
        swl_test_commit_timing_get_timer_record;
    swl_commit_timing_set_timestamp_impl =
        swl_test_commit_timing_set_timestamp_record;
    swl_commit_timer_destroy_impl = swl_test_commit_timer_destroy_record;
    swl_commit_timing_manager_destroy_impl =
        swl_test_commit_timing_manager_destroy_record;
}

void swl_test_commit_timing_request_recording_end(void)
{
    swl_commit_timing_get_timer_impl = swl_commit_timing_get_timer_default;
    swl_commit_timing_set_timestamp_impl =
        swl_commit_timing_set_timestamp_default;
    swl_commit_timer_destroy_impl = swl_commit_timer_destroy_default;
    swl_commit_timing_manager_destroy_impl =
        swl_commit_timing_manager_destroy_default;
}

struct swl_test_commit_timing_request_record
swl_test_commit_timing_request_record(void)
{
    return swl_test_commit_timing_request_latest;
}

struct swl_test_commit_timing_destroy_record
swl_test_commit_timing_destroy_record(void)
{
    return swl_test_commit_timing_destroy_latest;
}
#endif

