#include "swift-wayland-shims.h"
#include "generated/staging/xdg-activation/xdg-activation-v1-client-protocol.h"

#ifdef SWL_ENABLE_TESTING
static struct swl_test_activation_request_record swl_test_activation_request_latest;
static struct swl_test_activation_destroy_record swl_test_activation_destroy_latest;
static char swl_test_activation_request_text[256];

static struct xdg_activation_token_v1 *
swl_xdg_activation_v1_get_activation_token_default(
    struct xdg_activation_v1 *activation)
{
    return xdg_activation_v1_get_activation_token(activation);
}

static void swl_xdg_activation_v1_activate_default(
    struct xdg_activation_v1 *activation,
    const char *token,
    struct wl_surface *surface)
{
    xdg_activation_v1_activate(activation, token, surface);
}

static void swl_xdg_activation_v1_destroy_default(
    struct xdg_activation_v1 *activation)
{
    xdg_activation_v1_destroy(activation);
}

static void swl_xdg_activation_token_v1_set_serial_default(
    struct xdg_activation_token_v1 *token,
    uint32_t serial,
    struct wl_seat *seat)
{
    xdg_activation_token_v1_set_serial(token, serial, seat);
}

static void swl_xdg_activation_token_v1_set_app_id_default(
    struct xdg_activation_token_v1 *token,
    const char *app_id)
{
    xdg_activation_token_v1_set_app_id(token, app_id);
}

static void swl_xdg_activation_token_v1_set_surface_default(
    struct xdg_activation_token_v1 *token,
    struct wl_surface *surface)
{
    xdg_activation_token_v1_set_surface(token, surface);
}

static void swl_xdg_activation_token_v1_commit_default(
    struct xdg_activation_token_v1 *token)
{
    xdg_activation_token_v1_commit(token);
}

static void swl_xdg_activation_token_v1_destroy_default(
    struct xdg_activation_token_v1 *token)
{
    xdg_activation_token_v1_destroy(token);
}

static struct xdg_activation_token_v1 *(*swl_xdg_activation_get_token_impl)(
    struct xdg_activation_v1 *activation) =
        swl_xdg_activation_v1_get_activation_token_default;
static void (*swl_xdg_activation_activate_impl)(
    struct xdg_activation_v1 *activation,
    const char *token,
    struct wl_surface *surface) =
        swl_xdg_activation_v1_activate_default;
static void (*swl_xdg_activation_destroy_impl)(
    struct xdg_activation_v1 *activation) =
        swl_xdg_activation_v1_destroy_default;
static void (*swl_xdg_activation_token_set_serial_impl)(
    struct xdg_activation_token_v1 *token,
    uint32_t serial,
    struct wl_seat *seat) =
        swl_xdg_activation_token_v1_set_serial_default;
static void (*swl_xdg_activation_token_set_app_id_impl)(
    struct xdg_activation_token_v1 *token,
    const char *app_id) =
        swl_xdg_activation_token_v1_set_app_id_default;
static void (*swl_xdg_activation_token_set_surface_impl)(
    struct xdg_activation_token_v1 *token,
    struct wl_surface *surface) =
        swl_xdg_activation_token_v1_set_surface_default;
static void (*swl_xdg_activation_token_commit_impl)(
    struct xdg_activation_token_v1 *token) =
        swl_xdg_activation_token_v1_commit_default;
static void (*swl_xdg_activation_token_destroy_impl)(
    struct xdg_activation_token_v1 *token) =
        swl_xdg_activation_token_v1_destroy_default;

static void swl_test_copy_activation_text(const char *text)
{
    if (!text) {
        swl_test_activation_request_text[0] = '\0';
        swl_test_activation_request_latest.text = NULL;
        return;
    }

    size_t index = 0;
    while (index < sizeof(swl_test_activation_request_text) - 1
           && text[index] != '\0') {
        swl_test_activation_request_text[index] = text[index];
        index += 1;
    }
    swl_test_activation_request_text[index] = '\0';
    swl_test_activation_request_latest.text = swl_test_activation_request_text;
}

static void swl_test_record_activation_request(
    enum swl_test_activation_request_kind kind,
    void *object)
{
    swl_test_activation_request_latest.call_count += 1;
    swl_test_activation_request_latest.kind = kind;
    swl_test_activation_request_latest.object = object;
}

static struct xdg_activation_token_v1 *
swl_test_activation_get_token_record(struct xdg_activation_v1 *activation)
{
    swl_test_record_activation_request(SWL_TEST_ACTIVATION_GET_TOKEN, activation);
    return (struct xdg_activation_token_v1 *)0xAC710;
}

static void swl_test_activation_activate_record(
    struct xdg_activation_v1 *activation,
    const char *token,
    struct wl_surface *surface)
{
    swl_test_record_activation_request(SWL_TEST_ACTIVATION_ACTIVATE, activation);
    swl_test_activation_request_latest.surface = surface;
    swl_test_copy_activation_text(token);
}

static void swl_test_activation_token_set_serial_record(
    struct xdg_activation_token_v1 *token,
    uint32_t serial,
    struct wl_seat *seat)
{
    swl_test_record_activation_request(
        SWL_TEST_ACTIVATION_TOKEN_SET_SERIAL, token);
    swl_test_activation_request_latest.serial = serial;
    swl_test_activation_request_latest.seat = seat;
}

static void swl_test_activation_token_set_app_id_record(
    struct xdg_activation_token_v1 *token,
    const char *app_id)
{
    swl_test_record_activation_request(
        SWL_TEST_ACTIVATION_TOKEN_SET_APP_ID, token);
    swl_test_copy_activation_text(app_id);
}

static void swl_test_activation_token_set_surface_record(
    struct xdg_activation_token_v1 *token,
    struct wl_surface *surface)
{
    swl_test_record_activation_request(
        SWL_TEST_ACTIVATION_TOKEN_SET_SURFACE, token);
    swl_test_activation_request_latest.surface = surface;
}

static void swl_test_activation_token_commit_record(
    struct xdg_activation_token_v1 *token)
{
    swl_test_record_activation_request(SWL_TEST_ACTIVATION_TOKEN_COMMIT, token);
}

static void swl_test_record_activation_destroy(
    enum swl_test_activation_destroy_kind kind,
    void *object)
{
    swl_test_activation_destroy_latest.call_count += 1;
    swl_test_activation_destroy_latest.kind = kind;
    swl_test_activation_destroy_latest.object = object;
}

static void swl_test_activation_manager_destroy_record(
    struct xdg_activation_v1 *activation)
{
    swl_test_record_activation_destroy(
        SWL_TEST_ACTIVATION_DESTROY_MANAGER, activation);
}

static void swl_test_activation_token_destroy_record(
    struct xdg_activation_token_v1 *token)
{
    swl_test_record_activation_destroy(SWL_TEST_ACTIVATION_DESTROY_TOKEN, token);
}
#else
#define swl_xdg_activation_get_token_impl xdg_activation_v1_get_activation_token
#define swl_xdg_activation_activate_impl xdg_activation_v1_activate
#define swl_xdg_activation_destroy_impl xdg_activation_v1_destroy
#define swl_xdg_activation_token_set_serial_impl \
    xdg_activation_token_v1_set_serial
#define swl_xdg_activation_token_set_app_id_impl \
    xdg_activation_token_v1_set_app_id
#define swl_xdg_activation_token_set_surface_impl \
    xdg_activation_token_v1_set_surface
#define swl_xdg_activation_token_commit_impl xdg_activation_token_v1_commit
#define swl_xdg_activation_token_destroy_impl xdg_activation_token_v1_destroy
#endif

struct xdg_activation_token_v1 *swl_xdg_activation_v1_get_activation_token(
    struct xdg_activation_v1 *activation)
{
    return swl_xdg_activation_get_token_impl(activation);
}

void swl_xdg_activation_v1_activate(
    struct xdg_activation_v1 *activation,
    const char *token,
    struct wl_surface *surface)
{
    swl_xdg_activation_activate_impl(activation, token, surface);
}

void swl_xdg_activation_v1_destroy(struct xdg_activation_v1 *activation)
{
    swl_xdg_activation_destroy_impl(activation);
}

void swl_xdg_activation_token_v1_set_serial(
    struct xdg_activation_token_v1 *token,
    uint32_t serial,
    struct wl_seat *seat)
{
    swl_xdg_activation_token_set_serial_impl(token, serial, seat);
}

void swl_xdg_activation_token_v1_set_app_id(
    struct xdg_activation_token_v1 *token,
    const char *app_id)
{
    swl_xdg_activation_token_set_app_id_impl(token, app_id);
}

void swl_xdg_activation_token_v1_set_surface(
    struct xdg_activation_token_v1 *token,
    struct wl_surface *surface)
{
    swl_xdg_activation_token_set_surface_impl(token, surface);
}

void swl_xdg_activation_token_v1_commit(
    struct xdg_activation_token_v1 *token)
{
    swl_xdg_activation_token_commit_impl(token);
}

void swl_xdg_activation_token_v1_destroy(
    struct xdg_activation_token_v1 *token)
{
    swl_xdg_activation_token_destroy_impl(token);
}

#ifdef SWL_ENABLE_TESTING
void swl_test_activation_request_recording_begin(void)
{
    swl_test_activation_request_latest =
        (struct swl_test_activation_request_record){0};
    swl_test_activation_destroy_latest =
        (struct swl_test_activation_destroy_record){0};
    swl_test_activation_request_text[0] = '\0';
    swl_xdg_activation_get_token_impl = swl_test_activation_get_token_record;
    swl_xdg_activation_activate_impl = swl_test_activation_activate_record;
    swl_xdg_activation_destroy_impl = swl_test_activation_manager_destroy_record;
    swl_xdg_activation_token_set_serial_impl =
        swl_test_activation_token_set_serial_record;
    swl_xdg_activation_token_set_app_id_impl =
        swl_test_activation_token_set_app_id_record;
    swl_xdg_activation_token_set_surface_impl =
        swl_test_activation_token_set_surface_record;
    swl_xdg_activation_token_commit_impl =
        swl_test_activation_token_commit_record;
    swl_xdg_activation_token_destroy_impl =
        swl_test_activation_token_destroy_record;
}

void swl_test_activation_request_recording_end(void)
{
    swl_xdg_activation_get_token_impl =
        swl_xdg_activation_v1_get_activation_token_default;
    swl_xdg_activation_activate_impl = swl_xdg_activation_v1_activate_default;
    swl_xdg_activation_destroy_impl = swl_xdg_activation_v1_destroy_default;
    swl_xdg_activation_token_set_serial_impl =
        swl_xdg_activation_token_v1_set_serial_default;
    swl_xdg_activation_token_set_app_id_impl =
        swl_xdg_activation_token_v1_set_app_id_default;
    swl_xdg_activation_token_set_surface_impl =
        swl_xdg_activation_token_v1_set_surface_default;
    swl_xdg_activation_token_commit_impl =
        swl_xdg_activation_token_v1_commit_default;
    swl_xdg_activation_token_destroy_impl =
        swl_xdg_activation_token_v1_destroy_default;
}

struct swl_test_activation_request_record swl_test_activation_request_record(void)
{
    return swl_test_activation_request_latest;
}

struct swl_test_activation_destroy_record swl_test_activation_destroy_record(void)
{
    return swl_test_activation_destroy_latest;
}
#endif
