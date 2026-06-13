#pragma once

#ifndef __linux__
#error "WaylandClientKit currently supports Linux only."
#endif

#include <stdint.h>

struct gbm_device;
struct gbm_surface;

typedef void *swl_egl_display;
typedef void *swl_egl_config;
typedef void *swl_egl_context;
typedef void *swl_egl_surface;

#ifdef __cplusplus
extern "C" {
#endif

const char *swl_egl_query_client_extensions(void);
const char *swl_egl_query_display_extensions(swl_egl_display display);
int32_t swl_egl_error(void);
uint32_t swl_gles2_error(void);

swl_egl_display swl_egl_display_for_gbm_device(struct gbm_device *device);
int32_t swl_egl_initialize(
    swl_egl_display display,
    int32_t *out_major,
    int32_t *out_minor);
void swl_egl_terminate(swl_egl_display display);
int32_t swl_egl_bind_gles_api(void);
swl_egl_config swl_egl_choose_gles_window_config(
    swl_egl_display display,
    uint32_t native_visual_id);
swl_egl_context swl_egl_create_gles2_context(
    swl_egl_display display,
    swl_egl_config config);
void swl_egl_destroy_context(
    swl_egl_display display,
    swl_egl_context context);
swl_egl_surface swl_egl_create_window_surface(
    swl_egl_display display,
    swl_egl_config config,
    struct gbm_surface *surface);
void swl_egl_destroy_surface(
    swl_egl_display display,
    swl_egl_surface surface);
int32_t swl_egl_make_current(
    swl_egl_display display,
    swl_egl_surface surface,
    swl_egl_context context);
int32_t swl_egl_clear_current(swl_egl_display display);
int32_t swl_egl_swap_buffers(
    swl_egl_display display,
    swl_egl_surface surface);

int32_t swl_gles2_clear_rgba(
    uint32_t width,
    uint32_t height,
    float red,
    float green,
    float blue,
    float alpha);
int32_t swl_gles2_read_center_pixel_rgba8(
    uint32_t width,
    uint32_t height,
    uint8_t *out_rgba);

#ifdef SWL_ENABLE_TESTING
struct swl_test_egl_draw_record {
    int32_t make_current_call_count;
    int32_t clear_current_call_count;
    int32_t clear_call_count;
    int32_t read_pixel_call_count;
    int32_t swap_buffers_call_count;
    swl_egl_display display;
    swl_egl_surface surface;
    swl_egl_context context;
};

void swl_test_egl_draw_recording_begin(
    int32_t clear_current_result,
    int32_t egl_error);
void swl_test_egl_draw_recording_end(void);
struct swl_test_egl_draw_record swl_test_egl_draw_record(void);
#endif

#ifdef __cplusplus
}
#endif
