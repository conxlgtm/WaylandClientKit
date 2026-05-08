#include "swift-wayland-shims.h"
#include "generated/core/wayland-client-protocol.h"

#ifdef SWL_ENABLE_TESTING
static struct swl_test_data_request_record swl_test_data_request_latest;
static struct swl_test_data_destroy_record swl_test_data_destroy_latest;

static void swl_data_source_offer_default(
    struct wl_data_source *source,
    const char *mime_type)
{
    wl_data_source_offer(source, mime_type);
}

static void swl_data_source_set_actions_default(
    struct wl_data_source *source,
    uint32_t dnd_actions)
{
    wl_data_source_set_actions(source, dnd_actions);
}

static void swl_data_offer_accept_default(
    struct wl_data_offer *offer,
    uint32_t serial,
    const char *mime_type)
{
    wl_data_offer_accept(offer, serial, mime_type);
}

static void swl_data_offer_receive_default(
    struct wl_data_offer *offer,
    const char *mime_type,
    int32_t fd)
{
    wl_data_offer_receive(offer, mime_type, fd);
}

static void swl_data_offer_finish_default(struct wl_data_offer *offer)
{
    wl_data_offer_finish(offer);
}

static void swl_data_offer_set_actions_default(
    struct wl_data_offer *offer,
    uint32_t dnd_actions,
    uint32_t preferred_action)
{
    wl_data_offer_set_actions(offer, dnd_actions, preferred_action);
}

static void swl_data_device_set_selection_default(
    struct wl_data_device *device,
    struct wl_data_source *source,
    uint32_t serial)
{
    wl_data_device_set_selection(device, source, serial);
}

static void swl_data_device_start_drag_default(
    struct wl_data_device *device,
    struct wl_data_source *source,
    struct wl_surface *origin,
    struct wl_surface *icon,
    uint32_t serial)
{
    wl_data_device_start_drag(device, source, origin, icon, serial);
}

static void swl_data_offer_destroy_default(struct wl_data_offer *offer)
{
    wl_data_offer_destroy(offer);
}

static void swl_data_source_destroy_default(struct wl_data_source *source)
{
    wl_data_source_destroy(source);
}

static void swl_data_device_destroy_default(struct wl_data_device *device)
{
    wl_data_device_destroy(device);
}

static void swl_data_device_release_default(struct wl_data_device *device)
{
    wl_data_device_release(device);
}

static void swl_data_device_manager_destroy_default(
    struct wl_data_device_manager *manager)
{
    wl_data_device_manager_destroy(manager);
}

static void (*swl_data_source_offer_impl)(
    struct wl_data_source *source,
    const char *mime_type) = swl_data_source_offer_default;
static void (*swl_data_source_set_actions_impl)(
    struct wl_data_source *source,
    uint32_t dnd_actions) = swl_data_source_set_actions_default;
static void (*swl_data_offer_accept_impl)(
    struct wl_data_offer *offer,
    uint32_t serial,
    const char *mime_type) = swl_data_offer_accept_default;
static void (*swl_data_offer_receive_impl)(
    struct wl_data_offer *offer,
    const char *mime_type,
    int32_t fd) = swl_data_offer_receive_default;
static void (*swl_data_offer_finish_impl)(struct wl_data_offer *offer) =
    swl_data_offer_finish_default;
static void (*swl_data_offer_set_actions_impl)(
    struct wl_data_offer *offer,
    uint32_t dnd_actions,
    uint32_t preferred_action) = swl_data_offer_set_actions_default;
static void (*swl_data_device_set_selection_impl)(
    struct wl_data_device *device,
    struct wl_data_source *source,
    uint32_t serial) = swl_data_device_set_selection_default;
static void (*swl_data_device_start_drag_impl)(
    struct wl_data_device *device,
    struct wl_data_source *source,
    struct wl_surface *origin,
    struct wl_surface *icon,
    uint32_t serial) = swl_data_device_start_drag_default;
static void (*swl_data_offer_destroy_impl)(struct wl_data_offer *offer) =
    swl_data_offer_destroy_default;
static void (*swl_data_source_destroy_impl)(struct wl_data_source *source) =
    swl_data_source_destroy_default;
static void (*swl_data_device_destroy_impl)(struct wl_data_device *device) =
    swl_data_device_destroy_default;
static void (*swl_data_device_release_impl)(struct wl_data_device *device) =
    swl_data_device_release_default;
static void (*swl_data_device_manager_destroy_impl)(
    struct wl_data_device_manager *manager) =
        swl_data_device_manager_destroy_default;

static void swl_test_record_data_request(
    enum swl_test_data_request_kind kind,
    void *object,
    void *source,
    void *origin,
    void *icon,
    const char *mime_type,
    uint32_t serial,
    uint32_t actions,
    uint32_t preferred_action,
    int32_t fd)
{
    swl_test_data_request_latest.call_count += 1;
    swl_test_data_request_latest.kind = kind;
    swl_test_data_request_latest.object = object;
    swl_test_data_request_latest.source = source;
    swl_test_data_request_latest.origin = origin;
    swl_test_data_request_latest.icon = icon;
    swl_test_data_request_latest.mime_type = mime_type;
    swl_test_data_request_latest.serial = serial;
    swl_test_data_request_latest.actions = actions;
    swl_test_data_request_latest.preferred_action = preferred_action;
    swl_test_data_request_latest.fd = fd;
}

static void swl_test_data_source_offer_record(
    struct wl_data_source *source,
    const char *mime_type)
{
    swl_test_record_data_request(
        SWL_TEST_DATA_SOURCE_OFFER, source, NULL, NULL, NULL, mime_type,
        0, 0, 0, -1);
}

static void swl_test_data_source_set_actions_record(
    struct wl_data_source *source,
    uint32_t dnd_actions)
{
    swl_test_record_data_request(
        SWL_TEST_DATA_SOURCE_SET_ACTIONS, source, NULL, NULL, NULL, NULL,
        0, dnd_actions, 0, -1);
}

static void swl_test_data_offer_accept_record(
    struct wl_data_offer *offer,
    uint32_t serial,
    const char *mime_type)
{
    swl_test_record_data_request(
        SWL_TEST_DATA_OFFER_ACCEPT, offer, NULL, NULL, NULL, mime_type,
        serial, 0, 0, -1);
}

static void swl_test_data_offer_receive_record(
    struct wl_data_offer *offer,
    const char *mime_type,
    int32_t fd)
{
    swl_test_record_data_request(
        SWL_TEST_DATA_OFFER_RECEIVE, offer, NULL, NULL, NULL, mime_type,
        0, 0, 0, fd);
}

static void swl_test_data_offer_finish_record(struct wl_data_offer *offer)
{
    swl_test_record_data_request(
        SWL_TEST_DATA_OFFER_FINISH, offer, NULL, NULL, NULL, NULL,
        0, 0, 0, -1);
}

static void swl_test_data_offer_set_actions_record(
    struct wl_data_offer *offer,
    uint32_t dnd_actions,
    uint32_t preferred_action)
{
    swl_test_record_data_request(
        SWL_TEST_DATA_OFFER_SET_ACTIONS, offer, NULL, NULL, NULL, NULL,
        0, dnd_actions, preferred_action, -1);
}

static void swl_test_data_device_set_selection_record(
    struct wl_data_device *device,
    struct wl_data_source *source,
    uint32_t serial)
{
    swl_test_record_data_request(
        SWL_TEST_DATA_DEVICE_SET_SELECTION, device, source, NULL, NULL, NULL,
        serial, 0, 0, -1);
}

static void swl_test_data_device_start_drag_record(
    struct wl_data_device *device,
    struct wl_data_source *source,
    struct wl_surface *origin,
    struct wl_surface *icon,
    uint32_t serial)
{
    swl_test_record_data_request(
        SWL_TEST_DATA_DEVICE_START_DRAG, device, source, origin, icon, NULL,
        serial, 0, 0, -1);
}

static void swl_test_record_data_destroy(
    enum swl_test_data_destroy_kind kind,
    void *object)
{
    swl_test_data_destroy_latest.call_count += 1;
    swl_test_data_destroy_latest.kind = kind;
    swl_test_data_destroy_latest.object = object;
}

static void swl_test_data_offer_destroy_record(struct wl_data_offer *offer)
{
    swl_test_record_data_destroy(SWL_TEST_DATA_DESTROY_OFFER, offer);
}

static void swl_test_data_source_destroy_record(struct wl_data_source *source)
{
    swl_test_record_data_destroy(SWL_TEST_DATA_DESTROY_SOURCE, source);
}

static void swl_test_data_device_release_record(struct wl_data_device *device)
{
    swl_test_record_data_destroy(SWL_TEST_DATA_DESTROY_DEVICE, device);
}

static void swl_test_data_device_destroy_record(struct wl_data_device *device)
{
    swl_test_record_data_destroy(SWL_TEST_DATA_DESTROY_DEVICE_LEGACY, device);
}

static void swl_test_data_device_manager_destroy_record(
    struct wl_data_device_manager *manager)
{
    swl_test_record_data_destroy(SWL_TEST_DATA_DESTROY_MANAGER, manager);
}
#else
#define swl_data_source_offer_impl wl_data_source_offer
#define swl_data_source_set_actions_impl wl_data_source_set_actions
#define swl_data_offer_accept_impl wl_data_offer_accept
#define swl_data_offer_receive_impl wl_data_offer_receive
#define swl_data_offer_finish_impl wl_data_offer_finish
#define swl_data_offer_set_actions_impl wl_data_offer_set_actions
#define swl_data_device_set_selection_impl wl_data_device_set_selection
#define swl_data_device_start_drag_impl wl_data_device_start_drag
#define swl_data_offer_destroy_impl wl_data_offer_destroy
#define swl_data_source_destroy_impl wl_data_source_destroy
#define swl_data_device_destroy_impl wl_data_device_destroy
#define swl_data_device_release_impl wl_data_device_release
#define swl_data_device_manager_destroy_impl wl_data_device_manager_destroy
#endif

struct wl_data_source *swl_data_device_manager_create_data_source(
    struct wl_data_device_manager *manager)
{
    return wl_data_device_manager_create_data_source(manager);
}

struct wl_data_device *swl_data_device_manager_get_data_device(
    struct wl_data_device_manager *manager, struct wl_seat *seat)
{
    return wl_data_device_manager_get_data_device(manager, seat);
}

void swl_data_source_offer(struct wl_data_source *source, const char *mime_type)
{
    swl_data_source_offer_impl(source, mime_type);
}

void swl_data_source_set_actions(struct wl_data_source *source, uint32_t dnd_actions)
{
    swl_data_source_set_actions_impl(source, dnd_actions);
}

void swl_data_offer_accept(
    struct wl_data_offer *offer, uint32_t serial, const char *mime_type)
{
    swl_data_offer_accept_impl(offer, serial, mime_type);
}

void swl_data_offer_receive(
    struct wl_data_offer *offer, const char *mime_type, int32_t fd)
{
    swl_data_offer_receive_impl(offer, mime_type, fd);
}

void swl_data_offer_finish(struct wl_data_offer *offer)
{
    swl_data_offer_finish_impl(offer);
}

void swl_data_offer_set_actions(
    struct wl_data_offer *offer, uint32_t dnd_actions, uint32_t preferred_action)
{
    swl_data_offer_set_actions_impl(offer, dnd_actions, preferred_action);
}

void swl_data_device_set_selection(
    struct wl_data_device *device, struct wl_data_source *source, uint32_t serial)
{
    swl_data_device_set_selection_impl(device, source, serial);
}

void swl_data_device_start_drag(
    struct wl_data_device *device,
    struct wl_data_source *source,
    struct wl_surface *origin,
    struct wl_surface *icon,
    uint32_t serial)
{
    swl_data_device_start_drag_impl(device, source, origin, icon, serial);
}

uint32_t swl_data_device_manager_dnd_action_none(void)
{
    return WL_DATA_DEVICE_MANAGER_DND_ACTION_NONE;
}

uint32_t swl_data_device_manager_dnd_action_copy(void)
{
    return WL_DATA_DEVICE_MANAGER_DND_ACTION_COPY;
}

uint32_t swl_data_device_manager_dnd_action_move(void)
{
    return WL_DATA_DEVICE_MANAGER_DND_ACTION_MOVE;
}

uint32_t swl_data_device_manager_dnd_action_ask(void)
{
    return WL_DATA_DEVICE_MANAGER_DND_ACTION_ASK;
}

void swl_data_offer_destroy(struct wl_data_offer *offer)
{
    swl_data_offer_destroy_impl(offer);
}

void swl_data_source_destroy(struct wl_data_source *source)
{
    swl_data_source_destroy_impl(source);
}

void swl_data_device_destroy(struct wl_data_device *device)
{
    swl_data_device_destroy_impl(device);
}

void swl_data_device_release(struct wl_data_device *device)
{
    swl_data_device_release_impl(device);
}

void swl_data_device_manager_destroy(struct wl_data_device_manager *manager)
{
    swl_data_device_manager_destroy_impl(manager);
}

#ifdef SWL_ENABLE_TESTING
void swl_test_data_request_recording_begin(void)
{
    swl_test_data_request_latest =
        (struct swl_test_data_request_record){
            .kind = SWL_TEST_DATA_REQUEST_NONE,
            .fd = -1,
        };
    swl_test_data_destroy_latest =
        (struct swl_test_data_destroy_record){
            .kind = SWL_TEST_DATA_DESTROY_NONE,
        };

    swl_data_source_offer_impl = swl_test_data_source_offer_record;
    swl_data_source_set_actions_impl = swl_test_data_source_set_actions_record;
    swl_data_offer_accept_impl = swl_test_data_offer_accept_record;
    swl_data_offer_receive_impl = swl_test_data_offer_receive_record;
    swl_data_offer_finish_impl = swl_test_data_offer_finish_record;
    swl_data_offer_set_actions_impl = swl_test_data_offer_set_actions_record;
    swl_data_device_set_selection_impl = swl_test_data_device_set_selection_record;
    swl_data_device_start_drag_impl = swl_test_data_device_start_drag_record;
    swl_data_offer_destroy_impl = swl_test_data_offer_destroy_record;
    swl_data_source_destroy_impl = swl_test_data_source_destroy_record;
    swl_data_device_destroy_impl = swl_test_data_device_destroy_record;
    swl_data_device_release_impl = swl_test_data_device_release_record;
    swl_data_device_manager_destroy_impl =
        swl_test_data_device_manager_destroy_record;
}

void swl_test_data_request_recording_end(void)
{
    swl_data_source_offer_impl = swl_data_source_offer_default;
    swl_data_source_set_actions_impl = swl_data_source_set_actions_default;
    swl_data_offer_accept_impl = swl_data_offer_accept_default;
    swl_data_offer_receive_impl = swl_data_offer_receive_default;
    swl_data_offer_finish_impl = swl_data_offer_finish_default;
    swl_data_offer_set_actions_impl = swl_data_offer_set_actions_default;
    swl_data_device_set_selection_impl = swl_data_device_set_selection_default;
    swl_data_device_start_drag_impl = swl_data_device_start_drag_default;
    swl_data_offer_destroy_impl = swl_data_offer_destroy_default;
    swl_data_source_destroy_impl = swl_data_source_destroy_default;
    swl_data_device_destroy_impl = swl_data_device_destroy_default;
    swl_data_device_release_impl = swl_data_device_release_default;
    swl_data_device_manager_destroy_impl =
        swl_data_device_manager_destroy_default;
}

struct swl_test_data_request_record swl_test_data_request_record(void)
{
    return swl_test_data_request_latest;
}

struct swl_test_data_destroy_record swl_test_data_destroy_record(void)
{
    return swl_test_data_destroy_latest;
}
#endif
