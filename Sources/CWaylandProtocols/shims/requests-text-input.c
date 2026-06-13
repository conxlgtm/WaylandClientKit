#include "wayland-client-kit-shims.h"
#include "generated/legacy-unstable/text-input/text-input-unstable-v3-client-protocol.h"

#ifdef SWL_ENABLE_TESTING
static struct swl_test_text_input_request_record
    swl_test_text_input_request_latest;
static struct swl_test_text_input_destroy_record swl_test_text_input_destroy_latest;
static char swl_test_text_input_request_text[256];

static struct zwp_text_input_v3 *swl_text_input_manager_v3_get_text_input_default(
    struct zwp_text_input_manager_v3 *manager,
    struct wl_seat *seat)
{
    return zwp_text_input_manager_v3_get_text_input(manager, seat);
}

static void swl_text_input_v3_enable_default(struct zwp_text_input_v3 *text_input)
{
    zwp_text_input_v3_enable(text_input);
}

static void swl_text_input_v3_disable_default(struct zwp_text_input_v3 *text_input)
{
    zwp_text_input_v3_disable(text_input);
}

static void swl_text_input_v3_set_surrounding_text_default(
    struct zwp_text_input_v3 *text_input,
    const char *text,
    int32_t cursor,
    int32_t anchor)
{
    zwp_text_input_v3_set_surrounding_text(text_input, text, cursor, anchor);
}

static void swl_text_input_v3_set_text_change_cause_default(
    struct zwp_text_input_v3 *text_input,
    uint32_t cause)
{
    zwp_text_input_v3_set_text_change_cause(text_input, cause);
}

static void swl_text_input_v3_set_content_type_default(
    struct zwp_text_input_v3 *text_input,
    uint32_t hint,
    uint32_t purpose)
{
    zwp_text_input_v3_set_content_type(text_input, hint, purpose);
}

static void swl_text_input_v3_set_cursor_rectangle_default(
    struct zwp_text_input_v3 *text_input,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height)
{
    zwp_text_input_v3_set_cursor_rectangle(text_input, x, y, width, height);
}

static void swl_text_input_v3_commit_default(struct zwp_text_input_v3 *text_input)
{
    zwp_text_input_v3_commit(text_input);
}

static void swl_text_input_v3_destroy_default(struct zwp_text_input_v3 *text_input)
{
    zwp_text_input_v3_destroy(text_input);
}

static void swl_text_input_manager_v3_destroy_default(
    struct zwp_text_input_manager_v3 *manager)
{
    zwp_text_input_manager_v3_destroy(manager);
}

static struct zwp_text_input_v3 *(*swl_text_input_manager_v3_get_text_input_impl)(
    struct zwp_text_input_manager_v3 *manager,
    struct wl_seat *seat) = swl_text_input_manager_v3_get_text_input_default;
static void (*swl_text_input_v3_enable_impl)(
    struct zwp_text_input_v3 *text_input) =
        swl_text_input_v3_enable_default;
static void (*swl_text_input_v3_disable_impl)(
    struct zwp_text_input_v3 *text_input) =
        swl_text_input_v3_disable_default;
static void (*swl_text_input_v3_set_surrounding_text_impl)(
    struct zwp_text_input_v3 *text_input,
    const char *text,
    int32_t cursor,
    int32_t anchor) = swl_text_input_v3_set_surrounding_text_default;
static void (*swl_text_input_v3_set_text_change_cause_impl)(
    struct zwp_text_input_v3 *text_input,
    uint32_t cause) = swl_text_input_v3_set_text_change_cause_default;
static void (*swl_text_input_v3_set_content_type_impl)(
    struct zwp_text_input_v3 *text_input,
    uint32_t hint,
    uint32_t purpose) = swl_text_input_v3_set_content_type_default;
static void (*swl_text_input_v3_set_cursor_rectangle_impl)(
    struct zwp_text_input_v3 *text_input,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height) = swl_text_input_v3_set_cursor_rectangle_default;
static void (*swl_text_input_v3_commit_impl)(
    struct zwp_text_input_v3 *text_input) =
        swl_text_input_v3_commit_default;
static void (*swl_text_input_v3_destroy_impl)(
    struct zwp_text_input_v3 *text_input) =
        swl_text_input_v3_destroy_default;
static void (*swl_text_input_manager_v3_destroy_impl)(
    struct zwp_text_input_manager_v3 *manager) =
        swl_text_input_manager_v3_destroy_default;

static void swl_test_copy_text_input_text(const char *text)
{
    if (!text) {
        swl_test_text_input_request_text[0] = '\0';
        swl_test_text_input_request_latest.text = NULL;
        return;
    }

    size_t index = 0;
    while (index < sizeof(swl_test_text_input_request_text) - 1
           && text[index] != '\0') {
        swl_test_text_input_request_text[index] = text[index];
        index += 1;
    }
    swl_test_text_input_request_text[index] = '\0';
    swl_test_text_input_request_latest.text =
        swl_test_text_input_request_text;
}

static void swl_test_record_text_input_request(
    enum swl_test_text_input_request_kind kind,
    void *object)
{
    swl_test_text_input_request_latest.call_count += 1;
    swl_test_text_input_request_latest.kind = kind;
    swl_test_text_input_request_latest.object = object;
}

static struct zwp_text_input_v3 *swl_test_get_text_input_record(
    struct zwp_text_input_manager_v3 *manager,
    struct wl_seat *seat)
{
    swl_test_record_text_input_request(
        SWL_TEST_TEXT_INPUT_MANAGER_GET_TEXT_INPUT, manager);
    swl_test_text_input_request_latest.seat = seat;
    return (struct zwp_text_input_v3 *)0x7107;
}

static void swl_test_text_input_enable_record(
    struct zwp_text_input_v3 *text_input)
{
    swl_test_record_text_input_request(
        SWL_TEST_TEXT_INPUT_ENABLE, text_input);
}

static void swl_test_text_input_disable_record(
    struct zwp_text_input_v3 *text_input)
{
    swl_test_record_text_input_request(
        SWL_TEST_TEXT_INPUT_DISABLE, text_input);
}

static void swl_test_text_input_set_surrounding_text_record(
    struct zwp_text_input_v3 *text_input,
    const char *text,
    int32_t cursor,
    int32_t anchor)
{
    swl_test_record_text_input_request(
        SWL_TEST_TEXT_INPUT_SET_SURROUNDING_TEXT, text_input);
    swl_test_copy_text_input_text(text);
    swl_test_text_input_request_latest.cursor = cursor;
    swl_test_text_input_request_latest.anchor = anchor;
}

static void swl_test_text_input_set_text_change_cause_record(
    struct zwp_text_input_v3 *text_input,
    uint32_t cause)
{
    swl_test_record_text_input_request(
        SWL_TEST_TEXT_INPUT_SET_TEXT_CHANGE_CAUSE, text_input);
    swl_test_text_input_request_latest.cause = cause;
}

static void swl_test_text_input_set_content_type_record(
    struct zwp_text_input_v3 *text_input,
    uint32_t hint,
    uint32_t purpose)
{
    swl_test_record_text_input_request(
        SWL_TEST_TEXT_INPUT_SET_CONTENT_TYPE, text_input);
    swl_test_text_input_request_latest.hint = hint;
    swl_test_text_input_request_latest.purpose = purpose;
}

static void swl_test_text_input_set_cursor_rectangle_record(
    struct zwp_text_input_v3 *text_input,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height)
{
    swl_test_record_text_input_request(
        SWL_TEST_TEXT_INPUT_SET_CURSOR_RECTANGLE, text_input);
    swl_test_text_input_request_latest.x = x;
    swl_test_text_input_request_latest.y = y;
    swl_test_text_input_request_latest.width = width;
    swl_test_text_input_request_latest.height = height;
}

static void swl_test_text_input_commit_record(
    struct zwp_text_input_v3 *text_input)
{
    swl_test_record_text_input_request(
        SWL_TEST_TEXT_INPUT_COMMIT, text_input);
}

static void swl_test_record_text_input_destroy(
    enum swl_test_text_input_destroy_kind kind,
    void *object)
{
    swl_test_text_input_destroy_latest.call_count += 1;
    swl_test_text_input_destroy_latest.kind = kind;
    swl_test_text_input_destroy_latest.object = object;
}

static void swl_test_text_input_destroy_proxy_record(
    struct zwp_text_input_v3 *text_input)
{
    swl_test_record_text_input_destroy(
        SWL_TEST_TEXT_INPUT_DESTROY_TEXT_INPUT, text_input);
}

static void swl_test_text_input_manager_destroy_record(
    struct zwp_text_input_manager_v3 *manager)
{
    swl_test_record_text_input_destroy(
        SWL_TEST_TEXT_INPUT_DESTROY_MANAGER, manager);
}
#else
#define swl_text_input_manager_v3_get_text_input_impl \
    zwp_text_input_manager_v3_get_text_input
#define swl_text_input_v3_enable_impl zwp_text_input_v3_enable
#define swl_text_input_v3_disable_impl zwp_text_input_v3_disable
#define swl_text_input_v3_set_surrounding_text_impl \
    zwp_text_input_v3_set_surrounding_text
#define swl_text_input_v3_set_text_change_cause_impl \
    zwp_text_input_v3_set_text_change_cause
#define swl_text_input_v3_set_content_type_impl \
    zwp_text_input_v3_set_content_type
#define swl_text_input_v3_set_cursor_rectangle_impl \
    zwp_text_input_v3_set_cursor_rectangle
#define swl_text_input_v3_commit_impl zwp_text_input_v3_commit
#define swl_text_input_v3_destroy_impl zwp_text_input_v3_destroy
#define swl_text_input_manager_v3_destroy_impl \
    zwp_text_input_manager_v3_destroy
#endif

struct zwp_text_input_v3 *swl_text_input_manager_v3_get_text_input(
    struct zwp_text_input_manager_v3 *manager,
    struct wl_seat *seat)
{
    return swl_text_input_manager_v3_get_text_input_impl(manager, seat);
}

void swl_text_input_v3_enable(struct zwp_text_input_v3 *text_input)
{
    swl_text_input_v3_enable_impl(text_input);
}

void swl_text_input_v3_disable(struct zwp_text_input_v3 *text_input)
{
    swl_text_input_v3_disable_impl(text_input);
}

void swl_text_input_v3_set_surrounding_text(
    struct zwp_text_input_v3 *text_input,
    const char *text,
    int32_t cursor,
    int32_t anchor)
{
    swl_text_input_v3_set_surrounding_text_impl(
        text_input, text, cursor, anchor);
}

void swl_text_input_v3_set_text_change_cause(
    struct zwp_text_input_v3 *text_input,
    uint32_t cause)
{
    swl_text_input_v3_set_text_change_cause_impl(text_input, cause);
}

void swl_text_input_v3_set_content_type(
    struct zwp_text_input_v3 *text_input,
    uint32_t hint,
    uint32_t purpose)
{
    swl_text_input_v3_set_content_type_impl(text_input, hint, purpose);
}

void swl_text_input_v3_set_cursor_rectangle(
    struct zwp_text_input_v3 *text_input,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height)
{
    swl_text_input_v3_set_cursor_rectangle_impl(
        text_input, x, y, width, height);
}

void swl_text_input_v3_commit(struct zwp_text_input_v3 *text_input)
{
    swl_text_input_v3_commit_impl(text_input);
}

void swl_text_input_v3_destroy(struct zwp_text_input_v3 *text_input)
{
    swl_text_input_v3_destroy_impl(text_input);
}

void swl_text_input_manager_v3_destroy(
    struct zwp_text_input_manager_v3 *manager)
{
    swl_text_input_manager_v3_destroy_impl(manager);
}

#ifdef SWL_ENABLE_TESTING
void swl_test_text_input_request_recording_begin(void)
{
    swl_test_text_input_request_latest =
        (struct swl_test_text_input_request_record){0};
    swl_test_text_input_destroy_latest =
        (struct swl_test_text_input_destroy_record){0};
    swl_test_text_input_request_text[0] = '\0';
    swl_text_input_manager_v3_get_text_input_impl =
        swl_test_get_text_input_record;
    swl_text_input_v3_enable_impl = swl_test_text_input_enable_record;
    swl_text_input_v3_disable_impl = swl_test_text_input_disable_record;
    swl_text_input_v3_set_surrounding_text_impl =
        swl_test_text_input_set_surrounding_text_record;
    swl_text_input_v3_set_text_change_cause_impl =
        swl_test_text_input_set_text_change_cause_record;
    swl_text_input_v3_set_content_type_impl =
        swl_test_text_input_set_content_type_record;
    swl_text_input_v3_set_cursor_rectangle_impl =
        swl_test_text_input_set_cursor_rectangle_record;
    swl_text_input_v3_commit_impl = swl_test_text_input_commit_record;
    swl_text_input_v3_destroy_impl = swl_test_text_input_destroy_proxy_record;
    swl_text_input_manager_v3_destroy_impl =
        swl_test_text_input_manager_destroy_record;
}

void swl_test_text_input_request_recording_end(void)
{
    swl_text_input_manager_v3_get_text_input_impl =
        swl_text_input_manager_v3_get_text_input_default;
    swl_text_input_v3_enable_impl = swl_text_input_v3_enable_default;
    swl_text_input_v3_disable_impl = swl_text_input_v3_disable_default;
    swl_text_input_v3_set_surrounding_text_impl =
        swl_text_input_v3_set_surrounding_text_default;
    swl_text_input_v3_set_text_change_cause_impl =
        swl_text_input_v3_set_text_change_cause_default;
    swl_text_input_v3_set_content_type_impl =
        swl_text_input_v3_set_content_type_default;
    swl_text_input_v3_set_cursor_rectangle_impl =
        swl_text_input_v3_set_cursor_rectangle_default;
    swl_text_input_v3_commit_impl = swl_text_input_v3_commit_default;
    swl_text_input_v3_destroy_impl = swl_text_input_v3_destroy_default;
    swl_text_input_manager_v3_destroy_impl =
        swl_text_input_manager_v3_destroy_default;
}

struct swl_test_text_input_request_record
swl_test_text_input_request_record(void)
{
    return swl_test_text_input_request_latest;
}

struct swl_test_text_input_destroy_record
swl_test_text_input_destroy_record(void)
{
    return swl_test_text_input_destroy_latest;
}
#endif
