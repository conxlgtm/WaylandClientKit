#pragma once

#ifndef __linux__
#error "SwiftWayland currently supports Linux only."
#endif

#include <stdint.h>

#define SWL_GBM_MAX_PLANES 4

#if !defined(SWL_ENABLE_TESTING) && !defined(NDEBUG)
#define SWL_ENABLE_TESTING 1
#endif

struct gbm_device;
struct gbm_bo;

struct swl_gbm_bo_plane {
    int32_t fd;
    uint32_t offset;
    uint32_t stride;
};

struct swl_gbm_bo_export {
    uint32_t width;
    uint32_t height;
    uint32_t format;
    uint64_t modifier;
    uint32_t plane_count;
    struct swl_gbm_bo_plane planes[SWL_GBM_MAX_PLANES];
};

#ifdef __cplusplus
extern "C" {
#endif

uint32_t swl_drm_format_xrgb8888(void);
uint32_t swl_drm_format_argb8888(void);
uint64_t swl_drm_format_mod_linear(void);
uint64_t swl_drm_format_mod_invalid(void);

uint32_t swl_gbm_bo_use_scanout(void);
uint32_t swl_gbm_bo_use_rendering(void);
uint32_t swl_gbm_bo_use_write(void);
uint32_t swl_gbm_bo_use_linear(void);

uint32_t swl_drm_device_id_byte_count(void);
uint32_t swl_drm_render_node_path_max(void);
uint32_t swl_drm_node_primary_bit(void);
uint32_t swl_drm_node_render_bit(void);
int32_t swl_drm_node_path_from_available_nodes(
    uint32_t available_nodes,
    const char *primary_node_path,
    const char *render_node_path,
    char *out_path,
    uint32_t out_path_count);
int32_t swl_drm_render_node_path_from_device_bytes(
    const uint8_t *device_id_bytes,
    uint32_t byte_count,
    char *out_path,
    uint32_t out_path_count);

struct gbm_device *swl_gbm_create_device(int32_t fd);
void swl_gbm_device_destroy(struct gbm_device *device);
const char *swl_gbm_device_get_backend_name(struct gbm_device *device);
int32_t swl_gbm_device_is_format_supported(
    struct gbm_device *device,
    uint32_t format,
    uint32_t flags);
int32_t swl_gbm_device_get_format_modifier_plane_count(
    struct gbm_device *device,
    uint32_t format,
    uint64_t modifier);

struct gbm_bo *swl_gbm_bo_create(
    struct gbm_device *device,
    uint32_t width,
    uint32_t height,
    uint32_t format,
    uint32_t flags);
struct gbm_bo *swl_gbm_bo_create_with_modifiers2(
    struct gbm_device *device,
    uint32_t width,
    uint32_t height,
    uint32_t format,
    const uint64_t *modifiers,
    uint32_t count,
    uint32_t flags);
struct gbm_bo *swl_gbm_bo_create_with_modifier2(
    struct gbm_device *device,
    uint32_t width,
    uint32_t height,
    uint32_t format,
    uint64_t modifier,
    uint32_t flags);
struct gbm_bo *swl_gbm_bo_create_for_modifier(
    struct gbm_device *device,
    uint32_t width,
    uint32_t height,
    uint32_t format,
    uint64_t modifier,
    uint32_t flags);
void swl_gbm_bo_destroy(struct gbm_bo *buffer);
int32_t swl_gbm_bo_export_dmabuf(
    struct gbm_bo *buffer,
    struct swl_gbm_bo_export *out_export);
int32_t swl_gbm_bo_export_take_plane_fd(
    struct swl_gbm_bo_export *exported_buffer,
    uint32_t plane_index);
uint32_t swl_gbm_bo_export_plane_offset(
    const struct swl_gbm_bo_export *exported_buffer,
    uint32_t plane_index);
uint32_t swl_gbm_bo_export_plane_stride(
    const struct swl_gbm_bo_export *exported_buffer,
    uint32_t plane_index);
void swl_gbm_bo_export_close(struct swl_gbm_bo_export *exported_buffer);

#ifdef SWL_ENABLE_TESTING
enum swl_test_gbm_bo_create_kind {
    SWL_TEST_GBM_BO_CREATE_NONE = 0,
    SWL_TEST_GBM_BO_CREATE = 1,
    SWL_TEST_GBM_BO_CREATE_WITH_MODIFIERS2 = 2,
};

struct swl_test_gbm_bo_create_record {
    int32_t                          call_count;
    enum swl_test_gbm_bo_create_kind kind;
    void                            *device;
    uint32_t                         width;
    uint32_t                         height;
    uint32_t                         format;
    uint64_t                         modifier;
    uint32_t                         modifier_count;
    uint32_t                         flags;
};

void swl_test_gbm_bo_create_recording_begin(void);
void swl_test_gbm_bo_create_recording_end(void);
struct swl_test_gbm_bo_create_record swl_test_gbm_bo_create_record(void);
#endif

#ifdef __cplusplus
}
#endif
