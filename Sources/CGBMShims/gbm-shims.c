#include <errno.h>
#include <gbm.h>
#include <libdrm/drm_fourcc.h>
#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <unistd.h>
#include <xf86drm.h>

#include "swift-wayland-gbm-shims.h"

static void swl_gbm_bo_export_init(struct swl_gbm_bo_export *out_export)
{
    out_export->width = 0;
    out_export->height = 0;
    out_export->format = 0;
    out_export->modifier = DRM_FORMAT_MOD_INVALID;
    out_export->plane_count = 0;

    for (uint32_t index = 0; index < SWL_GBM_MAX_PLANES; index++)
    {
        out_export->planes[index].fd = -1;
        out_export->planes[index].offset = 0;
        out_export->planes[index].stride = 0;
    }
}

uint32_t swl_drm_format_xrgb8888(void)
{
    return DRM_FORMAT_XRGB8888;
}

uint32_t swl_drm_format_argb8888(void)
{
    return DRM_FORMAT_ARGB8888;
}

uint64_t swl_drm_format_mod_linear(void)
{
    return DRM_FORMAT_MOD_LINEAR;
}

uint64_t swl_drm_format_mod_invalid(void)
{
    return DRM_FORMAT_MOD_INVALID;
}

uint32_t swl_gbm_bo_use_scanout(void)
{
    return GBM_BO_USE_SCANOUT;
}

uint32_t swl_gbm_bo_use_rendering(void)
{
    return GBM_BO_USE_RENDERING;
}

uint32_t swl_gbm_bo_use_write(void)
{
    return GBM_BO_USE_WRITE;
}

uint32_t swl_gbm_bo_use_linear(void)
{
    return GBM_BO_USE_LINEAR;
}

uint32_t swl_drm_device_id_byte_count(void)
{
    return (uint32_t) sizeof(dev_t);
}

uint32_t swl_drm_render_node_path_max(void)
{
    return 256;
}

uint32_t swl_drm_node_primary_bit(void)
{
    return 1u << DRM_NODE_PRIMARY;
}

uint32_t swl_drm_node_render_bit(void)
{
    return 1u << DRM_NODE_RENDER;
}

static int32_t swl_drm_write_selected_node_path(
    uint32_t available_nodes,
    const char *const *nodes,
    char *out_path,
    uint32_t out_path_count)
{
    if (out_path == NULL || out_path_count == 0)
    {
        errno = EINVAL;
        return -1;
    }

    const char *selected_node = NULL;
    if (nodes != NULL &&
        (available_nodes & swl_drm_node_render_bit()) != 0 &&
        nodes[DRM_NODE_RENDER] != NULL)
    {
        selected_node = nodes[DRM_NODE_RENDER];
    }
    else if (nodes != NULL &&
             (available_nodes & swl_drm_node_primary_bit()) != 0 &&
             nodes[DRM_NODE_PRIMARY] != NULL)
    {
        selected_node = nodes[DRM_NODE_PRIMARY];
    }

    if (selected_node == NULL)
    {
        errno = ENODEV;
        return -1;
    }

    int written = snprintf(out_path, out_path_count, "%s", selected_node);
    if (written < 0 || (uint32_t) written >= out_path_count)
    {
        errno = ENAMETOOLONG;
        return -1;
    }

    return 0;
}

int32_t swl_drm_node_path_from_available_nodes(
    uint32_t available_nodes,
    const char *primary_node_path,
    const char *render_node_path,
    char *out_path,
    uint32_t out_path_count)
{
    const char *nodes[DRM_NODE_MAX] = {NULL};
    nodes[DRM_NODE_PRIMARY] = primary_node_path;
    nodes[DRM_NODE_RENDER] = render_node_path;

    return swl_drm_write_selected_node_path(
        available_nodes,
        nodes,
        out_path,
        out_path_count);
}

int32_t swl_drm_render_node_path_from_device_bytes(
    const uint8_t *device_id_bytes,
    uint32_t byte_count,
    char *out_path,
    uint32_t out_path_count)
{
    if (device_id_bytes == NULL || out_path == NULL || out_path_count == 0)
    {
        errno = EINVAL;
        return -1;
    }

    if (byte_count != sizeof(dev_t))
    {
        errno = EINVAL;
        return -1;
    }

    dev_t device_id = 0;
    memcpy(&device_id, device_id_bytes, sizeof(device_id));

    drmDevicePtr device = NULL;
    int result = drmGetDeviceFromDevId(device_id, 0, &device);
    if (result != 0)
    {
        errno = result < 0 ? -result : result;
        return -1;
    }

    if (device == NULL)
    {
        errno = ENODEV;
        return -1;
    }

    int selection_result = swl_drm_write_selected_node_path(
        (uint32_t) device->available_nodes,
        (const char *const *) device->nodes,
        out_path,
        out_path_count);
    int saved_errno = errno;
    drmFreeDevice(&device);
    if (selection_result != 0)
    {
        errno = saved_errno;
        return -1;
    }

    return 0;
}

struct gbm_device *swl_gbm_create_device(int32_t fd)
{
    if (fd < 0)
    {
        errno = EINVAL;
        return NULL;
    }

    return gbm_create_device(fd);
}

void swl_gbm_device_destroy(struct gbm_device *device)
{
    if (device != NULL)
    {
        gbm_device_destroy(device);
    }
}

const char *swl_gbm_device_get_backend_name(struct gbm_device *device)
{
    if (device == NULL)
    {
        errno = EINVAL;
        return NULL;
    }

    return gbm_device_get_backend_name(device);
}

int32_t swl_gbm_device_is_format_supported(
    struct gbm_device *device,
    uint32_t format,
    uint32_t flags)
{
    if (device == NULL)
    {
        errno = EINVAL;
        return 0;
    }

    return gbm_device_is_format_supported(device, format, flags);
}

int32_t swl_gbm_device_get_format_modifier_plane_count(
    struct gbm_device *device,
    uint32_t format,
    uint64_t modifier)
{
    if (device == NULL)
    {
        errno = EINVAL;
        return -1;
    }

    return gbm_device_get_format_modifier_plane_count(device, format, modifier);
}

#ifdef SWL_ENABLE_TESTING
static struct swl_test_gbm_bo_create_record swl_test_gbm_bo_create_latest;

static struct gbm_bo *swl_gbm_bo_create_default(
    struct gbm_device *device,
    uint32_t width,
    uint32_t height,
    uint32_t format,
    uint32_t flags)
{
    return gbm_bo_create(device, width, height, format, flags);
}

static struct gbm_bo *swl_gbm_bo_create_with_modifiers2_default(
    struct gbm_device *device,
    uint32_t width,
    uint32_t height,
    uint32_t format,
    const uint64_t *modifiers,
    uint32_t count,
    uint32_t flags)
{
    return gbm_bo_create_with_modifiers2(
        device,
        width,
        height,
        format,
        modifiers,
        count,
        flags);
}

static struct gbm_bo *(*swl_gbm_bo_create_impl)(
    struct gbm_device *device,
    uint32_t width,
    uint32_t height,
    uint32_t format,
    uint32_t flags) = swl_gbm_bo_create_default;

static struct gbm_bo *(*swl_gbm_bo_create_with_modifiers2_impl)(
    struct gbm_device *device,
    uint32_t width,
    uint32_t height,
    uint32_t format,
    const uint64_t *modifiers,
    uint32_t count,
    uint32_t flags) = swl_gbm_bo_create_with_modifiers2_default;

static void swl_test_gbm_bo_create_record_call(
    enum swl_test_gbm_bo_create_kind kind,
    struct gbm_device *device,
    uint32_t width,
    uint32_t height,
    uint32_t format,
    uint64_t modifier,
    uint32_t modifier_count,
    uint32_t flags)
{
    swl_test_gbm_bo_create_latest.call_count += 1;
    swl_test_gbm_bo_create_latest.kind = kind;
    swl_test_gbm_bo_create_latest.device = device;
    swl_test_gbm_bo_create_latest.width = width;
    swl_test_gbm_bo_create_latest.height = height;
    swl_test_gbm_bo_create_latest.format = format;
    swl_test_gbm_bo_create_latest.modifier = modifier;
    swl_test_gbm_bo_create_latest.modifier_count = modifier_count;
    swl_test_gbm_bo_create_latest.flags = flags;
}

static struct gbm_bo *swl_test_gbm_bo_create_record_impl(
    struct gbm_device *device,
    uint32_t width,
    uint32_t height,
    uint32_t format,
    uint32_t flags)
{
    swl_test_gbm_bo_create_record_call(
        SWL_TEST_GBM_BO_CREATE,
        device,
        width,
        height,
        format,
        DRM_FORMAT_MOD_INVALID,
        0,
        flags);
    return NULL;
}

static struct gbm_bo *swl_test_gbm_bo_create_with_modifiers2_record(
    struct gbm_device *device,
    uint32_t width,
    uint32_t height,
    uint32_t format,
    const uint64_t *modifiers,
    uint32_t count,
    uint32_t flags)
{
    uint64_t modifier = DRM_FORMAT_MOD_INVALID;
    if (modifiers != NULL && count > 0)
    {
        modifier = modifiers[0];
    }

    swl_test_gbm_bo_create_record_call(
        SWL_TEST_GBM_BO_CREATE_WITH_MODIFIERS2,
        device,
        width,
        height,
        format,
        modifier,
        count,
        flags);
    return NULL;
}
#else
#define swl_gbm_bo_create_impl gbm_bo_create
#define swl_gbm_bo_create_with_modifiers2_impl gbm_bo_create_with_modifiers2
#endif

struct gbm_bo *swl_gbm_bo_create(
    struct gbm_device *device,
    uint32_t width,
    uint32_t height,
    uint32_t format,
    uint32_t flags)
{
    if (device == NULL || width == 0 || height == 0)
    {
        errno = EINVAL;
        return NULL;
    }

    return swl_gbm_bo_create_impl(device, width, height, format, flags);
}

struct gbm_bo *swl_gbm_bo_create_with_modifiers2(
    struct gbm_device *device,
    uint32_t width,
    uint32_t height,
    uint32_t format,
    const uint64_t *modifiers,
    uint32_t count,
    uint32_t flags)
{
    if (device == NULL || width == 0 || height == 0)
    {
        errno = EINVAL;
        return NULL;
    }

    if (modifiers == NULL && count > 0)
    {
        errno = EINVAL;
        return NULL;
    }

    return swl_gbm_bo_create_with_modifiers2_impl(
        device,
        width,
        height,
        format,
        modifiers,
        count,
        flags);
}

struct gbm_bo *swl_gbm_bo_create_with_modifier2(
    struct gbm_device *device,
    uint32_t width,
    uint32_t height,
    uint32_t format,
    uint64_t modifier,
    uint32_t flags)
{
    uint64_t modifiers[1] = {modifier};
    return swl_gbm_bo_create_with_modifiers2(
        device,
        width,
        height,
        format,
        modifiers,
        1,
        flags);
}

struct gbm_bo *swl_gbm_bo_create_for_modifier(
    struct gbm_device *device,
    uint32_t width,
    uint32_t height,
    uint32_t format,
    uint64_t modifier,
    uint32_t flags)
{
    if (modifier == DRM_FORMAT_MOD_INVALID)
    {
        return swl_gbm_bo_create(device, width, height, format, flags);
    }

    return swl_gbm_bo_create_with_modifier2(
        device,
        width,
        height,
        format,
        modifier,
        flags);
}

void swl_gbm_bo_destroy(struct gbm_bo *buffer)
{
    if (buffer != NULL)
    {
        gbm_bo_destroy(buffer);
    }
}

int32_t swl_gbm_bo_export_dmabuf(
    struct gbm_bo *buffer,
    struct swl_gbm_bo_export *out_export)
{
    if (out_export == NULL)
    {
        errno = EINVAL;
        return -1;
    }

    swl_gbm_bo_export_init(out_export);

    if (buffer == NULL)
    {
        errno = EINVAL;
        return -1;
    }

    int plane_count = gbm_bo_get_plane_count(buffer);
    if (plane_count <= 0 || plane_count > SWL_GBM_MAX_PLANES)
    {
        errno = EINVAL;
        return -1;
    }

    out_export->width = gbm_bo_get_width(buffer);
    out_export->height = gbm_bo_get_height(buffer);
    out_export->format = gbm_bo_get_format(buffer);
    out_export->modifier = gbm_bo_get_modifier(buffer);
    out_export->plane_count = (uint32_t) plane_count;

    for (int plane = 0; plane < plane_count; plane++)
    {
        int fd = gbm_bo_get_fd_for_plane(buffer, plane);
        if (fd < 0)
        {
            int saved_errno = errno;
            swl_gbm_bo_export_close(out_export);
            errno = saved_errno > 0 ? saved_errno : EIO;
            return -1;
        }

        out_export->planes[plane].fd = fd;
        out_export->planes[plane].offset = gbm_bo_get_offset(buffer, plane);
        out_export->planes[plane].stride =
            gbm_bo_get_stride_for_plane(buffer, plane);
    }

    return 0;
}

int32_t swl_gbm_bo_export_take_plane_fd(
    struct swl_gbm_bo_export *exported_buffer,
    uint32_t plane_index)
{
    if (exported_buffer == NULL || plane_index >= exported_buffer->plane_count)
    {
        errno = EINVAL;
        return -1;
    }

    int fd = exported_buffer->planes[plane_index].fd;
    if (fd < 0)
    {
        errno = EBADF;
        return -1;
    }

    exported_buffer->planes[plane_index].fd = -1;
    return fd;
}

uint32_t swl_gbm_bo_export_plane_offset(
    const struct swl_gbm_bo_export *exported_buffer,
    uint32_t plane_index)
{
    if (exported_buffer == NULL || plane_index >= exported_buffer->plane_count)
    {
        errno = EINVAL;
        return 0;
    }

    return exported_buffer->planes[plane_index].offset;
}

uint32_t swl_gbm_bo_export_plane_stride(
    const struct swl_gbm_bo_export *exported_buffer,
    uint32_t plane_index)
{
    if (exported_buffer == NULL || plane_index >= exported_buffer->plane_count)
    {
        errno = EINVAL;
        return 0;
    }

    return exported_buffer->planes[plane_index].stride;
}

void swl_gbm_bo_export_close(struct swl_gbm_bo_export *exported_buffer)
{
    if (exported_buffer == NULL)
    {
        return;
    }

    uint32_t plane_count = exported_buffer->plane_count;
    if (plane_count > SWL_GBM_MAX_PLANES)
    {
        plane_count = SWL_GBM_MAX_PLANES;
    }

    for (uint32_t index = 0; index < plane_count; index++)
    {
        int fd = exported_buffer->planes[index].fd;
        if (fd >= 0)
        {
            close(fd);
            exported_buffer->planes[index].fd = -1;
        }
    }

    exported_buffer->plane_count = 0;
}

#ifdef SWL_ENABLE_TESTING
void swl_test_gbm_bo_create_recording_begin(void)
{
    swl_test_gbm_bo_create_latest =
        (struct swl_test_gbm_bo_create_record){
            .kind = SWL_TEST_GBM_BO_CREATE_NONE,
            .modifier = DRM_FORMAT_MOD_INVALID,
        };

    swl_gbm_bo_create_impl = swl_test_gbm_bo_create_record_impl;
    swl_gbm_bo_create_with_modifiers2_impl =
        swl_test_gbm_bo_create_with_modifiers2_record;
}

void swl_test_gbm_bo_create_recording_end(void)
{
    swl_gbm_bo_create_impl = swl_gbm_bo_create_default;
    swl_gbm_bo_create_with_modifiers2_impl =
        swl_gbm_bo_create_with_modifiers2_default;
}

struct swl_test_gbm_bo_create_record swl_test_gbm_bo_create_record(void)
{
    return swl_test_gbm_bo_create_latest;
}
#endif
