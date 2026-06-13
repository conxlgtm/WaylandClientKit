#include "wayland-client-kit-shims.h"
#include "generated/staging/xdg-activation/xdg-activation-v1-client-protocol.h"

static void swl_xdg_activation_token_v1_handle_done(
    void *data,
    struct xdg_activation_token_v1 *token,
    const char *token_value)
{
    const struct swl_xdg_activation_token_v1_listener_callbacks *cb = data;
    if (cb && cb->done)
        cb->done(cb->data, token, token_value);
}

static const struct xdg_activation_token_v1_listener
    swl_xdg_activation_token_v1_listener_impl = {
        .done = swl_xdg_activation_token_v1_handle_done,
    };

#ifdef SWL_ENABLE_TESTING
static struct swl_test_activation_listener_record
    swl_test_activation_listener_latest;

static void swl_test_record_activation_done(
    void *data,
    struct xdg_activation_token_v1 *token,
    const char *token_value)
{
    swl_test_activation_listener_latest.call_count += 1;
    swl_test_activation_listener_latest.kind =
        SWL_TEST_ACTIVATION_LISTENER_DONE;
    swl_test_activation_listener_latest.data = data;
    swl_test_activation_listener_latest.token = token;
    swl_test_activation_listener_latest.text = token_value;
}

static struct swl_xdg_activation_token_v1_listener_callbacks
swl_test_activation_listener_callbacks(void *data)
{
    return (struct swl_xdg_activation_token_v1_listener_callbacks){
        .done = swl_test_record_activation_done,
        .data = data,
    };
}
#endif

int swl_xdg_activation_token_v1_add_listener(
    struct xdg_activation_token_v1 *token,
    const struct swl_xdg_activation_token_v1_listener_callbacks *callbacks)
{
    return xdg_activation_token_v1_add_listener(
        token,
        &swl_xdg_activation_token_v1_listener_impl,
        (void *)callbacks);
}

#ifdef SWL_ENABLE_TESTING
void swl_test_activation_listener_emit_done(
    void *data,
    struct xdg_activation_token_v1 *token,
    const char *token_value,
    struct swl_test_activation_listener_record *record)
{
    swl_test_activation_listener_latest =
        (struct swl_test_activation_listener_record){0};
    struct swl_xdg_activation_token_v1_listener_callbacks callbacks =
        swl_test_activation_listener_callbacks(data);
    swl_xdg_activation_token_v1_handle_done(&callbacks, token, token_value);
    if (record)
        *record = swl_test_activation_listener_latest;
}
#endif
