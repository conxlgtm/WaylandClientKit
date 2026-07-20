#include "wayland-client-kit-shims.h"
#include "generated/legacy-unstable/xdg-decoration/xdg-decoration-unstable-v1-client-protocol.h"
#include "generated/stable/xdg-shell/xdg-shell-client-protocol.h"

#ifdef SWL_ENABLE_TESTING
static struct swl_test_xdg_popup_configure_record
    swl_test_xdg_popup_configure_latest;
static struct swl_test_xdg_popup_done_record swl_test_xdg_popup_done_latest;
static struct swl_test_xdg_popup_repositioned_record
    swl_test_xdg_popup_repositioned_latest;

static void swl_test_record_xdg_popup_configure(
    void *data,
    struct xdg_popup *popup,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height)
{
    swl_test_xdg_popup_configure_latest.call_count += 1;
    swl_test_xdg_popup_configure_latest.data = data;
    swl_test_xdg_popup_configure_latest.popup = popup;
    swl_test_xdg_popup_configure_latest.x = x;
    swl_test_xdg_popup_configure_latest.y = y;
    swl_test_xdg_popup_configure_latest.width = width;
    swl_test_xdg_popup_configure_latest.height = height;
}

static void swl_test_record_xdg_popup_done(
    void *data,
    struct xdg_popup *popup)
{
    swl_test_xdg_popup_done_latest.call_count += 1;
    swl_test_xdg_popup_done_latest.data = data;
    swl_test_xdg_popup_done_latest.popup = popup;
}

static void swl_test_record_xdg_popup_repositioned(
    void *data,
    struct xdg_popup *popup,
    uint32_t token)
{
    swl_test_xdg_popup_repositioned_latest.call_count += 1;
    swl_test_xdg_popup_repositioned_latest.data = data;
    swl_test_xdg_popup_repositioned_latest.popup = popup;
    swl_test_xdg_popup_repositioned_latest.token = token;
}

void swl_test_xdg_popup_listener_emit_configure(
    void *data,
    struct xdg_popup *popup,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height,
    struct swl_test_xdg_popup_configure_record *record)
{
    swl_test_xdg_popup_configure_latest =
        (struct swl_test_xdg_popup_configure_record){0};

    const struct swl_xdg_popup_listener_callbacks callbacks = {
        .configure = swl_test_record_xdg_popup_configure,
        .data = data,
    };

    callbacks.configure(callbacks.data, popup, x, y, width, height);

    if (record)
        *record = swl_test_xdg_popup_configure_latest;
}

void swl_test_xdg_popup_listener_emit_done(
    void *data,
    struct xdg_popup *popup,
    struct swl_test_xdg_popup_done_record *record)
{
    swl_test_xdg_popup_done_latest =
        (struct swl_test_xdg_popup_done_record){0};

    const struct swl_xdg_popup_listener_callbacks callbacks = {
        .popup_done = swl_test_record_xdg_popup_done,
        .data = data,
    };

    callbacks.popup_done(callbacks.data, popup);

    if (record)
        *record = swl_test_xdg_popup_done_latest;
}

void swl_test_xdg_popup_listener_emit_repositioned(
    void *data,
    struct xdg_popup *popup,
    uint32_t token,
    struct swl_test_xdg_popup_repositioned_record *record)
{
    swl_test_xdg_popup_repositioned_latest =
        (struct swl_test_xdg_popup_repositioned_record){0};

    const struct swl_xdg_popup_listener_callbacks callbacks = {
        .repositioned = swl_test_record_xdg_popup_repositioned,
        .data = data,
    };

    callbacks.repositioned(callbacks.data, popup, token);

    if (record)
        *record = swl_test_xdg_popup_repositioned_latest;
}
#endif
