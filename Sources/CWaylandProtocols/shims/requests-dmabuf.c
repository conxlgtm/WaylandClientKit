#include "swift-wayland-shims.h"
#include "generated/legacy-unstable/linux-dmabuf/linux-dmabuf-unstable-v1-client-protocol.h"

void swl_zwp_linux_dmabuf_v1_destroy(
    struct zwp_linux_dmabuf_v1 *linux_dmabuf)
{
    zwp_linux_dmabuf_v1_destroy(linux_dmabuf);
}
