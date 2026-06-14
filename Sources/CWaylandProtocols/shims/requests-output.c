#include "wayland-client-kit-shims.h"
#include "generated/legacy-unstable/xdg-output/xdg-output-unstable-v1-client-protocol.h"

struct zxdg_output_v1 *swl_zxdg_output_manager_v1_get_xdg_output(
    struct zxdg_output_manager_v1 *manager,
    struct wl_output *output)
{
    return zxdg_output_manager_v1_get_xdg_output(manager, output);
}

void swl_zxdg_output_v1_destroy(struct zxdg_output_v1 *output)
{
    zxdg_output_v1_destroy(output);
}

void swl_zxdg_output_manager_v1_destroy(
    struct zxdg_output_manager_v1 *manager)
{
    zxdg_output_manager_v1_destroy(manager);
}
