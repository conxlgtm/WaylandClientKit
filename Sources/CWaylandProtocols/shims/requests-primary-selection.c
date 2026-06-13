#include "wayland-client-kit-shims.h"
#include "generated/legacy-unstable/primary-selection/primary-selection-unstable-v1-client-protocol.h"

#ifdef SWL_ENABLE_TESTING
static struct swl_test_primary_selection_request_record
    swl_test_primary_selection_request_latest;
static struct swl_test_primary_selection_destroy_record
    swl_test_primary_selection_destroy_latest;

static void swl_primary_selection_source_offer_default(
    struct zwp_primary_selection_source_v1 *source,
    const char *mime_type)
{
    zwp_primary_selection_source_v1_offer(source, mime_type);
}

static void swl_primary_selection_offer_receive_default(
    struct zwp_primary_selection_offer_v1 *offer,
    const char *mime_type,
    int32_t fd)
{
    zwp_primary_selection_offer_v1_receive(offer, mime_type, fd);
}

static void swl_primary_selection_device_set_selection_default(
    struct zwp_primary_selection_device_v1 *device,
    struct zwp_primary_selection_source_v1 *source,
    uint32_t serial)
{
    zwp_primary_selection_device_v1_set_selection(device, source, serial);
}

static void swl_primary_selection_offer_destroy_default(
    struct zwp_primary_selection_offer_v1 *offer)
{
    zwp_primary_selection_offer_v1_destroy(offer);
}

static void swl_primary_selection_source_destroy_default(
    struct zwp_primary_selection_source_v1 *source)
{
    zwp_primary_selection_source_v1_destroy(source);
}

static void swl_primary_selection_device_destroy_default(
    struct zwp_primary_selection_device_v1 *device)
{
    zwp_primary_selection_device_v1_destroy(device);
}

static void swl_primary_selection_device_manager_destroy_default(
    struct zwp_primary_selection_device_manager_v1 *manager)
{
    zwp_primary_selection_device_manager_v1_destroy(manager);
}

static void (*swl_primary_selection_source_offer_impl)(
    struct zwp_primary_selection_source_v1 *source,
    const char *mime_type) = swl_primary_selection_source_offer_default;
static void (*swl_primary_selection_offer_receive_impl)(
    struct zwp_primary_selection_offer_v1 *offer,
    const char *mime_type,
    int32_t fd) = swl_primary_selection_offer_receive_default;
static void (*swl_primary_selection_device_set_selection_impl)(
    struct zwp_primary_selection_device_v1 *device,
    struct zwp_primary_selection_source_v1 *source,
    uint32_t serial) = swl_primary_selection_device_set_selection_default;
static void (*swl_primary_selection_offer_destroy_impl)(
    struct zwp_primary_selection_offer_v1 *offer) =
        swl_primary_selection_offer_destroy_default;
static void (*swl_primary_selection_source_destroy_impl)(
    struct zwp_primary_selection_source_v1 *source) =
        swl_primary_selection_source_destroy_default;
static void (*swl_primary_selection_device_destroy_impl)(
    struct zwp_primary_selection_device_v1 *device) =
        swl_primary_selection_device_destroy_default;
static void (*swl_primary_selection_device_manager_destroy_impl)(
    struct zwp_primary_selection_device_manager_v1 *manager) =
        swl_primary_selection_device_manager_destroy_default;

static void swl_test_record_primary_selection_request(
    enum swl_test_primary_selection_request_kind kind,
    void *object,
    void *source,
    const char *mime_type,
    uint32_t serial,
    int32_t fd)
{
    swl_test_primary_selection_request_latest.call_count += 1;
    swl_test_primary_selection_request_latest.kind = kind;
    swl_test_primary_selection_request_latest.object = object;
    swl_test_primary_selection_request_latest.source = source;
    swl_test_primary_selection_request_latest.mime_type = mime_type;
    swl_test_primary_selection_request_latest.serial = serial;
    swl_test_primary_selection_request_latest.fd = fd;
}

static void swl_test_primary_selection_source_offer_record(
    struct zwp_primary_selection_source_v1 *source,
    const char *mime_type)
{
    swl_test_record_primary_selection_request(
        SWL_TEST_PRIMARY_SELECTION_SOURCE_OFFER,
        source,
        NULL,
        mime_type,
        0,
        -1);
}

static void swl_test_primary_selection_offer_receive_record(
    struct zwp_primary_selection_offer_v1 *offer,
    const char *mime_type,
    int32_t fd)
{
    swl_test_record_primary_selection_request(
        SWL_TEST_PRIMARY_SELECTION_OFFER_RECEIVE,
        offer,
        NULL,
        mime_type,
        0,
        fd);
}

static void swl_test_primary_selection_device_set_selection_record(
    struct zwp_primary_selection_device_v1 *device,
    struct zwp_primary_selection_source_v1 *source,
    uint32_t serial)
{
    swl_test_record_primary_selection_request(
        SWL_TEST_PRIMARY_SELECTION_DEVICE_SET_SELECTION,
        device,
        source,
        NULL,
        serial,
        -1);
}

static void swl_test_record_primary_selection_destroy(
    enum swl_test_primary_selection_destroy_kind kind,
    void *object)
{
    swl_test_primary_selection_destroy_latest.call_count += 1;
    swl_test_primary_selection_destroy_latest.kind = kind;
    swl_test_primary_selection_destroy_latest.object = object;
}

static void swl_test_primary_selection_offer_destroy_record(
    struct zwp_primary_selection_offer_v1 *offer)
{
    swl_test_record_primary_selection_destroy(
        SWL_TEST_PRIMARY_SELECTION_DESTROY_OFFER,
        offer);
}

static void swl_test_primary_selection_source_destroy_record(
    struct zwp_primary_selection_source_v1 *source)
{
    swl_test_record_primary_selection_destroy(
        SWL_TEST_PRIMARY_SELECTION_DESTROY_SOURCE,
        source);
}

static void swl_test_primary_selection_device_destroy_record(
    struct zwp_primary_selection_device_v1 *device)
{
    swl_test_record_primary_selection_destroy(
        SWL_TEST_PRIMARY_SELECTION_DESTROY_DEVICE,
        device);
}

static void swl_test_primary_selection_device_manager_destroy_record(
    struct zwp_primary_selection_device_manager_v1 *manager)
{
    swl_test_record_primary_selection_destroy(
        SWL_TEST_PRIMARY_SELECTION_DESTROY_MANAGER,
        manager);
}
#else
#define swl_primary_selection_source_offer_impl \
    zwp_primary_selection_source_v1_offer
#define swl_primary_selection_offer_receive_impl \
    zwp_primary_selection_offer_v1_receive
#define swl_primary_selection_device_set_selection_impl \
    zwp_primary_selection_device_v1_set_selection
#define swl_primary_selection_offer_destroy_impl \
    zwp_primary_selection_offer_v1_destroy
#define swl_primary_selection_source_destroy_impl \
    zwp_primary_selection_source_v1_destroy
#define swl_primary_selection_device_destroy_impl \
    zwp_primary_selection_device_v1_destroy
#define swl_primary_selection_device_manager_destroy_impl \
    zwp_primary_selection_device_manager_v1_destroy
#endif

struct zwp_primary_selection_source_v1 *
swl_primary_selection_device_manager_create_source(
    struct zwp_primary_selection_device_manager_v1 *manager)
{
    return zwp_primary_selection_device_manager_v1_create_source(manager);
}

struct zwp_primary_selection_device_v1 *
swl_primary_selection_device_manager_get_device(
    struct zwp_primary_selection_device_manager_v1 *manager,
    struct wl_seat *seat)
{
    return zwp_primary_selection_device_manager_v1_get_device(manager, seat);
}

void swl_primary_selection_source_offer(
    struct zwp_primary_selection_source_v1 *source,
    const char *mime_type)
{
    swl_primary_selection_source_offer_impl(source, mime_type);
}

void swl_primary_selection_offer_receive(
    struct zwp_primary_selection_offer_v1 *offer,
    const char *mime_type,
    int32_t fd)
{
    swl_primary_selection_offer_receive_impl(offer, mime_type, fd);
}

void swl_primary_selection_device_set_selection(
    struct zwp_primary_selection_device_v1 *device,
    struct zwp_primary_selection_source_v1 *source,
    uint32_t serial)
{
    swl_primary_selection_device_set_selection_impl(device, source, serial);
}

void swl_primary_selection_offer_destroy(
    struct zwp_primary_selection_offer_v1 *offer)
{
    swl_primary_selection_offer_destroy_impl(offer);
}

void swl_primary_selection_source_destroy(
    struct zwp_primary_selection_source_v1 *source)
{
    swl_primary_selection_source_destroy_impl(source);
}

void swl_primary_selection_device_destroy(
    struct zwp_primary_selection_device_v1 *device)
{
    swl_primary_selection_device_destroy_impl(device);
}

void swl_primary_selection_device_manager_destroy(
    struct zwp_primary_selection_device_manager_v1 *manager)
{
    swl_primary_selection_device_manager_destroy_impl(manager);
}

#ifdef SWL_ENABLE_TESTING
void swl_test_primary_selection_request_recording_begin(void)
{
    swl_test_primary_selection_request_latest =
        (struct swl_test_primary_selection_request_record){
            .kind = SWL_TEST_PRIMARY_SELECTION_REQUEST_NONE,
            .fd = -1,
        };
    swl_test_primary_selection_destroy_latest =
        (struct swl_test_primary_selection_destroy_record){
            .kind = SWL_TEST_PRIMARY_SELECTION_DESTROY_NONE,
        };

    swl_primary_selection_source_offer_impl =
        swl_test_primary_selection_source_offer_record;
    swl_primary_selection_offer_receive_impl =
        swl_test_primary_selection_offer_receive_record;
    swl_primary_selection_device_set_selection_impl =
        swl_test_primary_selection_device_set_selection_record;
    swl_primary_selection_offer_destroy_impl =
        swl_test_primary_selection_offer_destroy_record;
    swl_primary_selection_source_destroy_impl =
        swl_test_primary_selection_source_destroy_record;
    swl_primary_selection_device_destroy_impl =
        swl_test_primary_selection_device_destroy_record;
    swl_primary_selection_device_manager_destroy_impl =
        swl_test_primary_selection_device_manager_destroy_record;
}

void swl_test_primary_selection_request_recording_end(void)
{
    swl_primary_selection_source_offer_impl =
        swl_primary_selection_source_offer_default;
    swl_primary_selection_offer_receive_impl =
        swl_primary_selection_offer_receive_default;
    swl_primary_selection_device_set_selection_impl =
        swl_primary_selection_device_set_selection_default;
    swl_primary_selection_offer_destroy_impl =
        swl_primary_selection_offer_destroy_default;
    swl_primary_selection_source_destroy_impl =
        swl_primary_selection_source_destroy_default;
    swl_primary_selection_device_destroy_impl =
        swl_primary_selection_device_destroy_default;
    swl_primary_selection_device_manager_destroy_impl =
        swl_primary_selection_device_manager_destroy_default;
}

struct swl_test_primary_selection_request_record
swl_test_primary_selection_request_record(void)
{
    return swl_test_primary_selection_request_latest;
}

struct swl_test_primary_selection_destroy_record
swl_test_primary_selection_destroy_record(void)
{
    return swl_test_primary_selection_destroy_latest;
}
#endif
