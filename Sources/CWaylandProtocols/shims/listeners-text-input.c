#include "wayland-client-kit-shims.h"
#include "generated/legacy-unstable/text-input/text-input-unstable-v3-client-protocol.h"

static void swl_text_input_v3_handle_enter(
    void *data,
    struct zwp_text_input_v3 *text_input,
    struct wl_surface *surface)
{
    const struct swl_text_input_v3_listener_callbacks *cb = data;
    if (cb && cb->enter)
        cb->enter(cb->data, text_input, surface);
}

static void swl_text_input_v3_handle_leave(
    void *data,
    struct zwp_text_input_v3 *text_input,
    struct wl_surface *surface)
{
    const struct swl_text_input_v3_listener_callbacks *cb = data;
    if (cb && cb->leave)
        cb->leave(cb->data, text_input, surface);
}

static void swl_text_input_v3_handle_preedit_string(
    void *data,
    struct zwp_text_input_v3 *text_input,
    const char *text,
    int32_t cursor_begin,
    int32_t cursor_end)
{
    const struct swl_text_input_v3_listener_callbacks *cb = data;
    if (cb && cb->preedit_string)
        cb->preedit_string(
            cb->data, text_input, text, cursor_begin, cursor_end);
}

static void swl_text_input_v3_handle_commit_string(
    void *data,
    struct zwp_text_input_v3 *text_input,
    const char *text)
{
    const struct swl_text_input_v3_listener_callbacks *cb = data;
    if (cb && cb->commit_string)
        cb->commit_string(cb->data, text_input, text);
}

static void swl_text_input_v3_handle_delete_surrounding_text(
    void *data,
    struct zwp_text_input_v3 *text_input,
    uint32_t before_length,
    uint32_t after_length)
{
    const struct swl_text_input_v3_listener_callbacks *cb = data;
    if (cb && cb->delete_surrounding_text)
        cb->delete_surrounding_text(
            cb->data, text_input, before_length, after_length);
}

static void swl_text_input_v3_handle_done(
    void *data,
    struct zwp_text_input_v3 *text_input,
    uint32_t serial)
{
    const struct swl_text_input_v3_listener_callbacks *cb = data;
    if (cb && cb->done)
        cb->done(cb->data, text_input, serial);
}

static void swl_text_input_v3_handle_action(
    void *data,
    struct zwp_text_input_v3 *text_input,
    uint32_t action,
    uint32_t serial)
{
    const struct swl_text_input_v3_listener_callbacks *cb = data;
    if (cb && cb->action)
        cb->action(cb->data, text_input, action, serial);
}

static void swl_text_input_v3_handle_language(
    void *data,
    struct zwp_text_input_v3 *text_input,
    const char *language)
{
    const struct swl_text_input_v3_listener_callbacks *cb = data;
    if (cb && cb->language)
        cb->language(cb->data, text_input, language);
}

static void swl_text_input_v3_handle_preedit_hint(
    void *data,
    struct zwp_text_input_v3 *text_input,
    uint32_t start,
    uint32_t end,
    uint32_t hint)
{
    const struct swl_text_input_v3_listener_callbacks *cb = data;
    if (cb && cb->preedit_hint)
        cb->preedit_hint(cb->data, text_input, start, end, hint);
}

static const struct zwp_text_input_v3_listener swl_text_input_v3_listener_impl = {
    .enter                   = swl_text_input_v3_handle_enter,
    .leave                   = swl_text_input_v3_handle_leave,
    .preedit_string          = swl_text_input_v3_handle_preedit_string,
    .commit_string           = swl_text_input_v3_handle_commit_string,
    .delete_surrounding_text = swl_text_input_v3_handle_delete_surrounding_text,
    .done                    = swl_text_input_v3_handle_done,
    .action                  = swl_text_input_v3_handle_action,
    .language                = swl_text_input_v3_handle_language,
    .preedit_hint            = swl_text_input_v3_handle_preedit_hint,
};

int swl_text_input_v3_add_listener(
    struct zwp_text_input_v3 *text_input,
    const struct swl_text_input_v3_listener_callbacks *callbacks)
{
    return zwp_text_input_v3_add_listener(
        text_input, &swl_text_input_v3_listener_impl, (void *)callbacks);
}

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
    swl_text_input_v3_handle_enter(&callbacks, text_input, surface);
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
    swl_text_input_v3_handle_leave(&callbacks, text_input, surface);
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
    swl_text_input_v3_handle_preedit_string(
        &callbacks, text_input, text, cursor_begin, cursor_end);
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
    swl_text_input_v3_handle_commit_string(&callbacks, text_input, text);
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
    swl_text_input_v3_handle_delete_surrounding_text(
        &callbacks, text_input, before_length, after_length);
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
    swl_text_input_v3_handle_done(&callbacks, text_input, serial);
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
    swl_text_input_v3_handle_action(&callbacks, text_input, action, serial);
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
    swl_text_input_v3_handle_language(&callbacks, text_input, language);
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
    swl_text_input_v3_handle_preedit_hint(
        &callbacks, text_input, start, end, hint);
    if (record)
        *record = swl_test_text_input_listener_latest;
}
#endif
