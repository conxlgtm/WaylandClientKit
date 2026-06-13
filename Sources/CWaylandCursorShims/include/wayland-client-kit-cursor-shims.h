#pragma once

#ifndef __linux__
#error "WaylandClientKit currently supports Linux only."
#endif

#include <stdint.h>

struct wl_buffer;
struct wl_cursor;
struct wl_cursor_image;
struct wl_cursor_theme;
struct wl_shm;

#ifdef __cplusplus
extern "C" {
#endif

struct wl_cursor_theme *swl_cursor_theme_load(
    const char *name,
    int32_t size,
    struct wl_shm *shm
);

void swl_cursor_theme_destroy(struct wl_cursor_theme *theme);

struct wl_cursor *swl_cursor_theme_get_cursor(
    struct wl_cursor_theme *theme,
    const char *name
);

uint32_t swl_cursor_image_count(struct wl_cursor *cursor);

struct wl_cursor_image *swl_cursor_image_at(
    struct wl_cursor *cursor,
    uint32_t index
);

uint32_t swl_cursor_image_width(struct wl_cursor_image *image);
uint32_t swl_cursor_image_height(struct wl_cursor_image *image);
uint32_t swl_cursor_image_hotspot_x(struct wl_cursor_image *image);
uint32_t swl_cursor_image_hotspot_y(struct wl_cursor_image *image);
uint32_t swl_cursor_image_delay(struct wl_cursor_image *image);

struct wl_buffer *swl_cursor_image_get_buffer(struct wl_cursor_image *image);

#ifdef __cplusplus
}
#endif
