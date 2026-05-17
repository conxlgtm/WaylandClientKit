#include "swift-wayland-shims.h"
#include "generated/legacy-unstable/text-input/text-input-unstable-v3-client-protocol.h"

struct zwp_text_input_v3 *swl_text_input_manager_v3_get_text_input(
    struct zwp_text_input_manager_v3 *manager,
    struct wl_seat *seat)
{
    return zwp_text_input_manager_v3_get_text_input(manager, seat);
}

void swl_text_input_v3_enable(struct zwp_text_input_v3 *text_input)
{
    zwp_text_input_v3_enable(text_input);
}

void swl_text_input_v3_disable(struct zwp_text_input_v3 *text_input)
{
    zwp_text_input_v3_disable(text_input);
}

void swl_text_input_v3_set_surrounding_text(
    struct zwp_text_input_v3 *text_input,
    const char *text,
    int32_t cursor,
    int32_t anchor)
{
    zwp_text_input_v3_set_surrounding_text(text_input, text, cursor, anchor);
}

void swl_text_input_v3_set_text_change_cause(
    struct zwp_text_input_v3 *text_input,
    uint32_t cause)
{
    zwp_text_input_v3_set_text_change_cause(text_input, cause);
}

void swl_text_input_v3_set_content_type(
    struct zwp_text_input_v3 *text_input,
    uint32_t hint,
    uint32_t purpose)
{
    zwp_text_input_v3_set_content_type(text_input, hint, purpose);
}

void swl_text_input_v3_set_cursor_rectangle(
    struct zwp_text_input_v3 *text_input,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height)
{
    zwp_text_input_v3_set_cursor_rectangle(text_input, x, y, width, height);
}

void swl_text_input_v3_commit(struct zwp_text_input_v3 *text_input)
{
    zwp_text_input_v3_commit(text_input);
}

void swl_text_input_v3_destroy(struct zwp_text_input_v3 *text_input)
{
    zwp_text_input_v3_destroy(text_input);
}

void swl_text_input_manager_v3_destroy(
    struct zwp_text_input_manager_v3 *manager)
{
    zwp_text_input_manager_v3_destroy(manager);
}
