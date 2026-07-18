#include "wayland-client-kit-shims.h"
#include "generated/legacy-unstable/linux-dmabuf/linux-dmabuf-unstable-v1-client-protocol.h"

#ifdef SWL_ENABLE_TESTING
static struct swl_test_dmabuf_request_record swl_test_dmabuf_request_latest;

static struct zwp_linux_dmabuf_feedback_v1 *
swl_zwp_linux_dmabuf_v1_get_default_feedback_default(
    struct zwp_linux_dmabuf_v1 *linux_dmabuf)
{
    return zwp_linux_dmabuf_v1_get_default_feedback(linux_dmabuf);
}

static struct zwp_linux_dmabuf_feedback_v1 *
swl_zwp_linux_dmabuf_v1_get_surface_feedback_default(
    struct zwp_linux_dmabuf_v1 *linux_dmabuf,
    struct wl_surface *surface)
{
    return zwp_linux_dmabuf_v1_get_surface_feedback(linux_dmabuf, surface);
}

static struct zwp_linux_buffer_params_v1 *
swl_zwp_linux_dmabuf_v1_create_params_default(
    struct zwp_linux_dmabuf_v1 *linux_dmabuf)
{
    return zwp_linux_dmabuf_v1_create_params(linux_dmabuf);
}

static void swl_zwp_linux_buffer_params_v1_add_default(
    struct zwp_linux_buffer_params_v1 *params,
    int32_t fd,
    uint32_t plane_idx,
    uint32_t offset,
    uint32_t stride,
    uint32_t modifier_hi,
    uint32_t modifier_lo)
{
    zwp_linux_buffer_params_v1_add(
        params,
        fd,
        plane_idx,
        offset,
        stride,
        modifier_hi,
        modifier_lo);
}

static void swl_zwp_linux_buffer_params_v1_create_default(
    struct zwp_linux_buffer_params_v1 *params,
    int32_t width,
    int32_t height,
    uint32_t format,
    uint32_t flags)
{
    zwp_linux_buffer_params_v1_create(params, width, height, format, flags);
}

static struct zwp_linux_dmabuf_feedback_v1 *(*swl_get_default_feedback_impl)(
    struct zwp_linux_dmabuf_v1 *linux_dmabuf) =
        swl_zwp_linux_dmabuf_v1_get_default_feedback_default;
static struct zwp_linux_dmabuf_feedback_v1 *(*swl_get_surface_feedback_impl)(
    struct zwp_linux_dmabuf_v1 *linux_dmabuf,
    struct wl_surface *surface) =
        swl_zwp_linux_dmabuf_v1_get_surface_feedback_default;
static struct zwp_linux_buffer_params_v1 *(*swl_create_params_impl)(
    struct zwp_linux_dmabuf_v1 *linux_dmabuf) =
        swl_zwp_linux_dmabuf_v1_create_params_default;
static void (*swl_buffer_params_add_impl)(
    struct zwp_linux_buffer_params_v1 *params,
    int32_t fd,
    uint32_t plane_idx,
    uint32_t offset,
    uint32_t stride,
    uint32_t modifier_hi,
    uint32_t modifier_lo) =
        swl_zwp_linux_buffer_params_v1_add_default;
static void (*swl_buffer_params_create_impl)(
    struct zwp_linux_buffer_params_v1 *params,
    int32_t width,
    int32_t height,
    uint32_t format,
    uint32_t flags) =
        swl_zwp_linux_buffer_params_v1_create_default;

static void swl_test_record_dmabuf_request(
    enum swl_test_dmabuf_request_kind kind,
    void *object,
    void *surface,
    int32_t fd,
    uint32_t plane_idx,
    uint32_t offset,
    uint32_t stride,
    uint32_t modifier_hi,
    uint32_t modifier_lo,
    int32_t width,
    int32_t height,
    uint32_t format,
    uint32_t flags)
{
    swl_test_dmabuf_request_latest.call_count += 1;
    swl_test_dmabuf_request_latest.kind = kind;
    swl_test_dmabuf_request_latest.object = object;
    swl_test_dmabuf_request_latest.surface = surface;
    swl_test_dmabuf_request_latest.fd = fd;
    swl_test_dmabuf_request_latest.plane_idx = plane_idx;
    swl_test_dmabuf_request_latest.offset = offset;
    swl_test_dmabuf_request_latest.stride = stride;
    swl_test_dmabuf_request_latest.modifier_hi = modifier_hi;
    swl_test_dmabuf_request_latest.modifier_lo = modifier_lo;
    swl_test_dmabuf_request_latest.width = width;
    swl_test_dmabuf_request_latest.height = height;
    swl_test_dmabuf_request_latest.format = format;
    swl_test_dmabuf_request_latest.flags = flags;
}

static struct zwp_linux_dmabuf_feedback_v1 *
swl_test_get_default_feedback_record(
    struct zwp_linux_dmabuf_v1 *linux_dmabuf)
{
    swl_test_record_dmabuf_request(
        SWL_TEST_DMABUF_GET_DEFAULT_FEEDBACK, linux_dmabuf, NULL, -1,
        0, 0, 0, 0, 0, 0, 0, 0, 0);
    return NULL;
}

static struct zwp_linux_dmabuf_feedback_v1 *
swl_test_get_surface_feedback_record(
    struct zwp_linux_dmabuf_v1 *linux_dmabuf,
    struct wl_surface *surface)
{
    swl_test_record_dmabuf_request(
        SWL_TEST_DMABUF_GET_SURFACE_FEEDBACK, linux_dmabuf, surface, -1,
        0, 0, 0, 0, 0, 0, 0, 0, 0);
    return NULL;
}

static struct zwp_linux_buffer_params_v1 *
swl_test_create_params_record(struct zwp_linux_dmabuf_v1 *linux_dmabuf)
{
    swl_test_record_dmabuf_request(
        SWL_TEST_DMABUF_CREATE_PARAMS, linux_dmabuf, NULL, -1,
        0, 0, 0, 0, 0, 0, 0, 0, 0);
    return NULL;
}

static void swl_test_buffer_params_add_record(
    struct zwp_linux_buffer_params_v1 *params,
    int32_t fd,
    uint32_t plane_idx,
    uint32_t offset,
    uint32_t stride,
    uint32_t modifier_hi,
    uint32_t modifier_lo)
{
    swl_test_record_dmabuf_request(
        SWL_TEST_DMABUF_BUFFER_PARAMS_ADD, params, NULL, fd, plane_idx,
        offset, stride, modifier_hi, modifier_lo, 0, 0, 0, 0);
}

static void swl_test_buffer_params_create_record(
    struct zwp_linux_buffer_params_v1 *params,
    int32_t width,
    int32_t height,
    uint32_t format,
    uint32_t flags)
{
    swl_test_record_dmabuf_request(
        SWL_TEST_DMABUF_BUFFER_PARAMS_CREATE, params, NULL, -1, 0, 0, 0,
        0, 0, width, height, format, flags);
}
#else
#define swl_get_default_feedback_impl zwp_linux_dmabuf_v1_get_default_feedback
#define swl_get_surface_feedback_impl zwp_linux_dmabuf_v1_get_surface_feedback
#define swl_create_params_impl zwp_linux_dmabuf_v1_create_params
#define swl_buffer_params_add_impl zwp_linux_buffer_params_v1_add
#define swl_buffer_params_create_impl zwp_linux_buffer_params_v1_create
#endif

struct zwp_linux_dmabuf_feedback_v1 *
swl_zwp_linux_dmabuf_v1_get_default_feedback(
    struct zwp_linux_dmabuf_v1 *linux_dmabuf)
{
    return swl_get_default_feedback_impl(linux_dmabuf);
}

struct zwp_linux_dmabuf_feedback_v1 *
swl_zwp_linux_dmabuf_v1_get_surface_feedback(
    struct zwp_linux_dmabuf_v1 *linux_dmabuf,
    struct wl_surface *surface)
{
    return swl_get_surface_feedback_impl(linux_dmabuf, surface);
}

struct zwp_linux_buffer_params_v1 *
swl_zwp_linux_dmabuf_v1_create_params(
    struct zwp_linux_dmabuf_v1 *linux_dmabuf)
{
    return swl_create_params_impl(linux_dmabuf);
}

void swl_zwp_linux_buffer_params_v1_add(
    struct zwp_linux_buffer_params_v1 *params,
    int32_t fd,
    uint32_t plane_idx,
    uint32_t offset,
    uint32_t stride,
    uint32_t modifier_hi,
    uint32_t modifier_lo)
{
    swl_buffer_params_add_impl(
        params,
        fd,
        plane_idx,
        offset,
        stride,
        modifier_hi,
        modifier_lo);
}

void swl_zwp_linux_buffer_params_v1_create(
    struct zwp_linux_buffer_params_v1 *params,
    int32_t width,
    int32_t height,
    uint32_t format,
    uint32_t flags)
{
    swl_buffer_params_create_impl(params, width, height, format, flags);
}

#ifdef SWL_ENABLE_TESTING
void swl_test_dmabuf_request_recording_begin(void)
{
    swl_test_dmabuf_request_latest =
        (struct swl_test_dmabuf_request_record){
            .kind = SWL_TEST_DMABUF_REQUEST_NONE,
            .fd = -1,
        };

    swl_get_default_feedback_impl = swl_test_get_default_feedback_record;
    swl_get_surface_feedback_impl = swl_test_get_surface_feedback_record;
    swl_create_params_impl = swl_test_create_params_record;
    swl_buffer_params_add_impl = swl_test_buffer_params_add_record;
    swl_buffer_params_create_impl = swl_test_buffer_params_create_record;
}

void swl_test_dmabuf_request_recording_end(void)
{
    swl_get_default_feedback_impl =
        swl_zwp_linux_dmabuf_v1_get_default_feedback_default;
    swl_get_surface_feedback_impl =
        swl_zwp_linux_dmabuf_v1_get_surface_feedback_default;
    swl_create_params_impl =
        swl_zwp_linux_dmabuf_v1_create_params_default;
    swl_buffer_params_add_impl =
        swl_zwp_linux_buffer_params_v1_add_default;
    swl_buffer_params_create_impl =
        swl_zwp_linux_buffer_params_v1_create_default;
}

struct swl_test_dmabuf_request_record swl_test_dmabuf_request_record(void)
{
    return swl_test_dmabuf_request_latest;
}
#endif
