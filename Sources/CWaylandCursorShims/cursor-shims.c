#include <wayland-client.h>
#include <wayland-cursor.h>

#include "swift-wayland-cursor-shims.h"

struct wl_cursor_theme *swl_cursor_theme_load(
    const char *name,
    int32_t size,
    struct wl_shm *shm)
{
    return wl_cursor_theme_load(name, size, shm);
}

void swl_cursor_theme_destroy(struct wl_cursor_theme *theme)
{
    wl_cursor_theme_destroy(theme);
}

struct wl_cursor *swl_cursor_theme_get_cursor(
    struct wl_cursor_theme *theme,
    const char *name)
{
    return wl_cursor_theme_get_cursor(theme, name);
}

uint32_t swl_cursor_image_count(struct wl_cursor *cursor)
{
    if (cursor == NULL)
    {
        return 0;
    }

    return cursor->image_count;
}

struct wl_cursor_image *swl_cursor_image_at(
    struct wl_cursor *cursor,
    uint32_t index)
{
    if (cursor == NULL)
    {
        return NULL;
    }

    if (index >= cursor->image_count)
    {
        return NULL;
    }

    return cursor->images[index];
}

uint32_t swl_cursor_image_width(struct wl_cursor_image *image)
{
    if (image == NULL)
    {
        return 0;
    }

    return image->width;
}

uint32_t swl_cursor_image_height(struct wl_cursor_image *image)
{
    if (image == NULL)
    {
        return 0;
    }

    return image->height;
}

uint32_t swl_cursor_image_hotspot_x(struct wl_cursor_image *image)
{
    if (image == NULL)
    {
        return 0;
    }

    return image->hotspot_x;
}

uint32_t swl_cursor_image_hotspot_y(struct wl_cursor_image *image)
{
    if (image == NULL)
    {
        return 0;
    }

    return image->hotspot_y;
}

uint32_t swl_cursor_image_delay(struct wl_cursor_image *image)
{
    if (image == NULL)
    {
        return 0;
    }

    return image->delay;
}

struct wl_buffer *swl_cursor_image_get_buffer(struct wl_cursor_image *image)
{
    if (image == NULL)
    {
        return NULL;
    }

    return wl_cursor_image_get_buffer(image);
}
