#include "wayland-client-kit-shims.h"
#include "generated/legacy-unstable/text-input/text-input-unstable-v3-client-protocol.h"

#ifdef SWL_ENABLE_TESTING
static struct swl_test_text_input_listener_record
    swl_test_text_input_listener_latest;

static void swl_test_record_text_input_enter(
    void *data,
    struct zwp_text_input_v3 *text_input,
    struct wl_surface *surface)
{
    swl_test_text_input_listener_latest.call_count += 1;
    swl_test_text_input_listener_latest.kind =
        SWL_TEST_TEXT_INPUT_LISTENER_ENTER;
    swl_test_text_input_listener_latest.data = data;
    swl_test_text_input_listener_latest.text_input = text_input;
    swl_test_text_input_listener_latest.surface = surface;
}

static void swl_test_record_text_input_leave(
    void *data,
    struct zwp_text_input_v3 *text_input,
    struct wl_surface *surface)
{
    swl_test_text_input_listener_latest.call_count += 1;
    swl_test_text_input_listener_latest.kind =
        SWL_TEST_TEXT_INPUT_LISTENER_LEAVE;
    swl_test_text_input_listener_latest.data = data;
    swl_test_text_input_listener_latest.text_input = text_input;
    swl_test_text_input_listener_latest.surface = surface;
}

static void swl_test_record_text_input_preedit_string(
    void *data,
    struct zwp_text_input_v3 *text_input,
    const char *text,
    int32_t cursor_begin,
    int32_t cursor_end)
{
    swl_test_text_input_listener_latest.call_count += 1;
    swl_test_text_input_listener_latest.kind =
        SWL_TEST_TEXT_INPUT_LISTENER_PREEDIT_STRING;
    swl_test_text_input_listener_latest.data = data;
    swl_test_text_input_listener_latest.text_input = text_input;
    swl_test_text_input_listener_latest.text = text;
    swl_test_text_input_listener_latest.cursor_begin = cursor_begin;
    swl_test_text_input_listener_latest.cursor_end = cursor_end;
}

static void swl_test_record_text_input_commit_string(
    void *data,
    struct zwp_text_input_v3 *text_input,
    const char *text)
{
    swl_test_text_input_listener_latest.call_count += 1;
    swl_test_text_input_listener_latest.kind =
        SWL_TEST_TEXT_INPUT_LISTENER_COMMIT_STRING;
    swl_test_text_input_listener_latest.data = data;
    swl_test_text_input_listener_latest.text_input = text_input;
    swl_test_text_input_listener_latest.text = text;
}

static void swl_test_record_text_input_delete_surrounding_text(
    void *data,
    struct zwp_text_input_v3 *text_input,
    uint32_t before_length,
    uint32_t after_length)
{
    swl_test_text_input_listener_latest.call_count += 1;
    swl_test_text_input_listener_latest.kind =
        SWL_TEST_TEXT_INPUT_LISTENER_DELETE_SURROUNDING_TEXT;
    swl_test_text_input_listener_latest.data = data;
    swl_test_text_input_listener_latest.text_input = text_input;
    swl_test_text_input_listener_latest.before_length = before_length;
    swl_test_text_input_listener_latest.after_length = after_length;
}

static void swl_test_record_text_input_done(
    void *data,
    struct zwp_text_input_v3 *text_input,
    uint32_t serial)
{
    swl_test_text_input_listener_latest.call_count += 1;
    swl_test_text_input_listener_latest.kind =
        SWL_TEST_TEXT_INPUT_LISTENER_DONE;
    swl_test_text_input_listener_latest.data = data;
    swl_test_text_input_listener_latest.text_input = text_input;
    swl_test_text_input_listener_latest.serial = serial;
}

static void swl_test_record_text_input_action(
    void *data,
    struct zwp_text_input_v3 *text_input,
    uint32_t action,
    uint32_t serial)
{
    swl_test_text_input_listener_latest.call_count += 1;
    swl_test_text_input_listener_latest.kind =
        SWL_TEST_TEXT_INPUT_LISTENER_ACTION;
    swl_test_text_input_listener_latest.data = data;
    swl_test_text_input_listener_latest.text_input = text_input;
    swl_test_text_input_listener_latest.action = action;
    swl_test_text_input_listener_latest.serial = serial;
}

static void swl_test_record_text_input_language(
    void *data,
    struct zwp_text_input_v3 *text_input,
    const char *language)
{
    swl_test_text_input_listener_latest.call_count += 1;
    swl_test_text_input_listener_latest.kind =
        SWL_TEST_TEXT_INPUT_LISTENER_LANGUAGE;
    swl_test_text_input_listener_latest.data = data;
    swl_test_text_input_listener_latest.text_input = text_input;
    swl_test_text_input_listener_latest.text = language;
}

static void swl_test_record_text_input_preedit_hint(
    void *data,
    struct zwp_text_input_v3 *text_input,
    uint32_t start,
    uint32_t end,
    uint32_t hint)
{
    swl_test_text_input_listener_latest.call_count += 1;
    swl_test_text_input_listener_latest.kind =
        SWL_TEST_TEXT_INPUT_LISTENER_PREEDIT_HINT;
    swl_test_text_input_listener_latest.data = data;
    swl_test_text_input_listener_latest.text_input = text_input;
    swl_test_text_input_listener_latest.start = start;
    swl_test_text_input_listener_latest.end = end;
    swl_test_text_input_listener_latest.hint = hint;
}

static struct swl_text_input_v3_listener_callbacks
swl_test_text_input_listener_callbacks(void *data)
{
    return (struct swl_text_input_v3_listener_callbacks){
        .enter                   = swl_test_record_text_input_enter,
        .leave                   = swl_test_record_text_input_leave,
        .preedit_string          = swl_test_record_text_input_preedit_string,
        .commit_string           = swl_test_record_text_input_commit_string,
        .delete_surrounding_text =
            swl_test_record_text_input_delete_surrounding_text,
        .done                    = swl_test_record_text_input_done,
        .action                  = swl_test_record_text_input_action,
        .language                = swl_test_record_text_input_language,
        .preedit_hint            = swl_test_record_text_input_preedit_hint,
        .data                    = data,
    };
}

void swl_test_text_input_listener_emit_enter(
    void *data,
    struct zwp_text_input_v3 *text_input,
    struct wl_surface *surface,
    struct swl_test_text_input_listener_record *record)
{
    swl_test_text_input_listener_latest =
        (struct swl_test_text_input_listener_record){0};
    struct swl_text_input_v3_listener_callbacks callbacks =
        swl_test_text_input_listener_callbacks(data);
    callbacks.enter(callbacks.data, text_input, surface);
    if (record)
        *record = swl_test_text_input_listener_latest;
}

void swl_test_text_input_listener_emit_leave(
    void *data,
    struct zwp_text_input_v3 *text_input,
    struct wl_surface *surface,
    struct swl_test_text_input_listener_record *record)
{
    swl_test_text_input_listener_latest =
        (struct swl_test_text_input_listener_record){0};
    struct swl_text_input_v3_listener_callbacks callbacks =
        swl_test_text_input_listener_callbacks(data);
    callbacks.leave(callbacks.data, text_input, surface);
    if (record)
        *record = swl_test_text_input_listener_latest;
}

void swl_test_text_input_listener_emit_preedit_string(
    void *data,
    struct zwp_text_input_v3 *text_input,
    const char *text,
    int32_t cursor_begin,
    int32_t cursor_end,
    struct swl_test_text_input_listener_record *record)
{
    swl_test_text_input_listener_latest =
        (struct swl_test_text_input_listener_record){0};
    struct swl_text_input_v3_listener_callbacks callbacks =
        swl_test_text_input_listener_callbacks(data);
    callbacks.preedit_string(
        callbacks.data, text_input, text, cursor_begin, cursor_end);
    if (record)
        *record = swl_test_text_input_listener_latest;
}

void swl_test_text_input_listener_emit_commit_string(
    void *data,
    struct zwp_text_input_v3 *text_input,
    const char *text,
    struct swl_test_text_input_listener_record *record)
{
    swl_test_text_input_listener_latest =
        (struct swl_test_text_input_listener_record){0};
    struct swl_text_input_v3_listener_callbacks callbacks =
        swl_test_text_input_listener_callbacks(data);
    callbacks.commit_string(callbacks.data, text_input, text);
    if (record)
        *record = swl_test_text_input_listener_latest;
}

void swl_test_text_input_listener_emit_delete_surrounding_text(
    void *data,
    struct zwp_text_input_v3 *text_input,
    uint32_t before_length,
    uint32_t after_length,
    struct swl_test_text_input_listener_record *record)
{
    swl_test_text_input_listener_latest =
        (struct swl_test_text_input_listener_record){0};
    struct swl_text_input_v3_listener_callbacks callbacks =
        swl_test_text_input_listener_callbacks(data);
    callbacks.delete_surrounding_text(
        callbacks.data, text_input, before_length, after_length);
    if (record)
        *record = swl_test_text_input_listener_latest;
}

void swl_test_text_input_listener_emit_done(
    void *data,
    struct zwp_text_input_v3 *text_input,
    uint32_t serial,
    struct swl_test_text_input_listener_record *record)
{
    swl_test_text_input_listener_latest =
        (struct swl_test_text_input_listener_record){0};
    struct swl_text_input_v3_listener_callbacks callbacks =
        swl_test_text_input_listener_callbacks(data);
    callbacks.done(callbacks.data, text_input, serial);
    if (record)
        *record = swl_test_text_input_listener_latest;
}

void swl_test_text_input_listener_emit_action(
    void *data,
    struct zwp_text_input_v3 *text_input,
    uint32_t action,
    uint32_t serial,
    struct swl_test_text_input_listener_record *record)
{
    swl_test_text_input_listener_latest =
        (struct swl_test_text_input_listener_record){0};
    struct swl_text_input_v3_listener_callbacks callbacks =
        swl_test_text_input_listener_callbacks(data);
    callbacks.action(callbacks.data, text_input, action, serial);
    if (record)
        *record = swl_test_text_input_listener_latest;
}

void swl_test_text_input_listener_emit_language(
    void *data,
    struct zwp_text_input_v3 *text_input,
    const char *language,
    struct swl_test_text_input_listener_record *record)
{
    swl_test_text_input_listener_latest =
        (struct swl_test_text_input_listener_record){0};
    struct swl_text_input_v3_listener_callbacks callbacks =
        swl_test_text_input_listener_callbacks(data);
    callbacks.language(callbacks.data, text_input, language);
    if (record)
        *record = swl_test_text_input_listener_latest;
}

void swl_test_text_input_listener_emit_preedit_hint(
    void *data,
    struct zwp_text_input_v3 *text_input,
    uint32_t start,
    uint32_t end,
    uint32_t hint,
    struct swl_test_text_input_listener_record *record)
{
    swl_test_text_input_listener_latest =
        (struct swl_test_text_input_listener_record){0};
    struct swl_text_input_v3_listener_callbacks callbacks =
        swl_test_text_input_listener_callbacks(data);
    callbacks.preedit_hint(callbacks.data, text_input, start, end, hint);
    if (record)
        *record = swl_test_text_input_listener_latest;
}
#endif
