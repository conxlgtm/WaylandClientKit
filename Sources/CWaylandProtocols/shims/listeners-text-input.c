#include "swift-wayland-shims.h"
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
