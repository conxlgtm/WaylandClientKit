#include "swift-wayland-shims.h"

/*
 * wl_seat listener bridge
 */

static void swl_seat_handle_capabilities(
    void *data, struct wl_seat *seat, uint32_t capabilities)
{
    const struct swl_seat_listener_callbacks *cb = data;
    if (cb && cb->capabilities)
        cb->capabilities(cb->data, seat, capabilities);
}

static void swl_seat_handle_name(
    void *data, struct wl_seat *seat, const char *name)
{
    const struct swl_seat_listener_callbacks *cb = data;
    if (cb && cb->name)
        cb->name(cb->data, seat, name);
}

static const struct wl_seat_listener swl_seat_listener_impl = {
    .capabilities = swl_seat_handle_capabilities,
    .name         = swl_seat_handle_name,
};

int swl_seat_add_listener(
    struct wl_seat *seat,
    const struct swl_seat_listener_callbacks *callbacks)
{
    return wl_seat_add_listener(
        seat, &swl_seat_listener_impl, (void *)callbacks);
}

/*
 * wl_pointer listener bridge
 */

static void swl_pointer_handle_enter(
    void *data, struct wl_pointer *pointer, uint32_t serial,
    struct wl_surface *surface, wl_fixed_t surface_x, wl_fixed_t surface_y)
{
    const struct swl_pointer_listener_callbacks *cb = data;
    if (cb && cb->enter)
        cb->enter(cb->data, pointer, serial, surface, surface_x, surface_y);
}

static void swl_pointer_handle_leave(
    void *data, struct wl_pointer *pointer,
    uint32_t serial, struct wl_surface *surface)
{
    const struct swl_pointer_listener_callbacks *cb = data;
    if (cb && cb->leave)
        cb->leave(cb->data, pointer, serial, surface);
}

static void swl_pointer_handle_motion(
    void *data, struct wl_pointer *pointer,
    uint32_t time, wl_fixed_t surface_x, wl_fixed_t surface_y)
{
    const struct swl_pointer_listener_callbacks *cb = data;
    if (cb && cb->motion)
        cb->motion(cb->data, pointer, time, surface_x, surface_y);
}

static void swl_pointer_handle_button(
    void *data, struct wl_pointer *pointer,
    uint32_t serial, uint32_t time, uint32_t button, uint32_t state)
{
    const struct swl_pointer_listener_callbacks *cb = data;
    if (cb && cb->button)
        cb->button(cb->data, pointer, serial, time, button, state);
}

static void swl_pointer_handle_axis(
    void *data, struct wl_pointer *pointer,
    uint32_t time, uint32_t axis, wl_fixed_t value)
{
    const struct swl_pointer_listener_callbacks *cb = data;
    if (cb && cb->axis)
        cb->axis(cb->data, pointer, time, axis, value);
}

static void swl_pointer_handle_frame(void *data, struct wl_pointer *pointer)
{
    const struct swl_pointer_listener_callbacks *cb = data;
    if (cb && cb->frame)
        cb->frame(cb->data, pointer);
}

static void swl_pointer_handle_axis_source(
    void *data, struct wl_pointer *pointer, uint32_t axis_source)
{
    const struct swl_pointer_listener_callbacks *cb = data;
    if (cb && cb->axis_source)
        cb->axis_source(cb->data, pointer, axis_source);
}

static void swl_pointer_handle_axis_stop(
    void *data, struct wl_pointer *pointer, uint32_t time, uint32_t axis)
{
    const struct swl_pointer_listener_callbacks *cb = data;
    if (cb && cb->axis_stop)
        cb->axis_stop(cb->data, pointer, time, axis);
}

static void swl_pointer_handle_axis_discrete(
    void *data, struct wl_pointer *pointer, uint32_t axis, int32_t discrete)
{
    const struct swl_pointer_listener_callbacks *cb = data;
    if (cb && cb->axis_discrete)
        cb->axis_discrete(cb->data, pointer, axis, discrete);
}

static void swl_pointer_handle_axis_value120(
    void *data, struct wl_pointer *pointer, uint32_t axis, int32_t value120)
{
    const struct swl_pointer_listener_callbacks *cb = data;
    if (cb && cb->axis_value120)
        cb->axis_value120(cb->data, pointer, axis, value120);
}

static void swl_pointer_handle_axis_relative_direction(
    void *data, struct wl_pointer *pointer,
    uint32_t axis, uint32_t direction)
{
    const struct swl_pointer_listener_callbacks *cb = data;
    if (cb && cb->axis_relative_direction)
        cb->axis_relative_direction(cb->data, pointer, axis, direction);
}

static const struct wl_pointer_listener swl_pointer_listener_impl = {
    .enter                  = swl_pointer_handle_enter,
    .leave                  = swl_pointer_handle_leave,
    .motion                 = swl_pointer_handle_motion,
    .button                 = swl_pointer_handle_button,
    .axis                   = swl_pointer_handle_axis,
    .frame                  = swl_pointer_handle_frame,
    .axis_source            = swl_pointer_handle_axis_source,
    .axis_stop              = swl_pointer_handle_axis_stop,
    .axis_discrete          = swl_pointer_handle_axis_discrete,
    .axis_value120          = swl_pointer_handle_axis_value120,
    .axis_relative_direction = swl_pointer_handle_axis_relative_direction,
};

int swl_pointer_add_listener(
    struct wl_pointer *pointer,
    const struct swl_pointer_listener_callbacks *callbacks)
{
    return wl_pointer_add_listener(
        pointer, &swl_pointer_listener_impl, (void *)callbacks);
}

/*
 * wl_keyboard listener bridge
 */

static void swl_keyboard_handle_keymap(
    void *data, struct wl_keyboard *keyboard,
    uint32_t format, int32_t fd, uint32_t size)
{
    const struct swl_keyboard_listener_callbacks *cb = data;
    if (cb && cb->keymap)
        cb->keymap(cb->data, keyboard, format, fd, size);
}

static void swl_keyboard_handle_enter(
    void *data, struct wl_keyboard *keyboard,
    uint32_t serial, struct wl_surface *surface, struct wl_array *keys)
{
    const struct swl_keyboard_listener_callbacks *cb = data;
    if (cb && cb->enter)
        cb->enter(cb->data, keyboard, serial, surface, keys);
}

static void swl_keyboard_handle_leave(
    void *data, struct wl_keyboard *keyboard,
    uint32_t serial, struct wl_surface *surface)
{
    const struct swl_keyboard_listener_callbacks *cb = data;
    if (cb && cb->leave)
        cb->leave(cb->data, keyboard, serial, surface);
}

static void swl_keyboard_handle_key(
    void *data, struct wl_keyboard *keyboard,
    uint32_t serial, uint32_t time, uint32_t key, uint32_t state)
{
    const struct swl_keyboard_listener_callbacks *cb = data;
    if (cb && cb->key)
        cb->key(cb->data, keyboard, serial, time, key, state);
}

static void swl_keyboard_handle_modifiers(
    void *data, struct wl_keyboard *keyboard, uint32_t serial,
    uint32_t mods_depressed, uint32_t mods_latched,
    uint32_t mods_locked, uint32_t group)
{
    const struct swl_keyboard_listener_callbacks *cb = data;
    if (cb && cb->modifiers)
        cb->modifiers(cb->data, keyboard, serial,
                      mods_depressed, mods_latched, mods_locked, group);
}

static void swl_keyboard_handle_repeat_info(
    void *data, struct wl_keyboard *keyboard, int32_t rate, int32_t delay)
{
    const struct swl_keyboard_listener_callbacks *cb = data;
    if (cb && cb->repeat_info)
        cb->repeat_info(cb->data, keyboard, rate, delay);
}

static const struct wl_keyboard_listener swl_keyboard_listener_impl = {
    .keymap      = swl_keyboard_handle_keymap,
    .enter       = swl_keyboard_handle_enter,
    .leave       = swl_keyboard_handle_leave,
    .key         = swl_keyboard_handle_key,
    .modifiers   = swl_keyboard_handle_modifiers,
    .repeat_info = swl_keyboard_handle_repeat_info,
};

int swl_keyboard_add_listener(
    struct wl_keyboard *keyboard,
    const struct swl_keyboard_listener_callbacks *callbacks)
{
    return wl_keyboard_add_listener(
        keyboard, &swl_keyboard_listener_impl, (void *)callbacks);
}

/*
 * wl_touch listener bridge
 */

static void swl_touch_handle_down(
    void *data, struct wl_touch *touch, uint32_t serial, uint32_t time,
    struct wl_surface *surface, int32_t id, wl_fixed_t x, wl_fixed_t y)
{
    const struct swl_touch_listener_callbacks *cb = data;
    if (cb && cb->down)
        cb->down(cb->data, touch, serial, time, surface, id, x, y);
}

static void swl_touch_handle_up(
    void *data, struct wl_touch *touch,
    uint32_t serial, uint32_t time, int32_t id)
{
    const struct swl_touch_listener_callbacks *cb = data;
    if (cb && cb->up)
        cb->up(cb->data, touch, serial, time, id);
}

static void swl_touch_handle_motion(
    void *data, struct wl_touch *touch,
    uint32_t time, int32_t id, wl_fixed_t x, wl_fixed_t y)
{
    const struct swl_touch_listener_callbacks *cb = data;
    if (cb && cb->motion)
        cb->motion(cb->data, touch, time, id, x, y);
}

static void swl_touch_handle_frame(void *data, struct wl_touch *touch)
{
    const struct swl_touch_listener_callbacks *cb = data;
    if (cb && cb->frame)
        cb->frame(cb->data, touch);
}

static void swl_touch_handle_cancel(void *data, struct wl_touch *touch)
{
    const struct swl_touch_listener_callbacks *cb = data;
    if (cb && cb->cancel)
        cb->cancel(cb->data, touch);
}

static void swl_touch_handle_shape(
    void *data, struct wl_touch *touch,
    int32_t id, wl_fixed_t major, wl_fixed_t minor)
{
    const struct swl_touch_listener_callbacks *cb = data;
    if (cb && cb->shape)
        cb->shape(cb->data, touch, id, major, minor);
}

static void swl_touch_handle_orientation(
    void *data, struct wl_touch *touch, int32_t id, wl_fixed_t orientation)
{
    const struct swl_touch_listener_callbacks *cb = data;
    if (cb && cb->orientation)
        cb->orientation(cb->data, touch, id, orientation);
}

static const struct wl_touch_listener swl_touch_listener_impl = {
    .down        = swl_touch_handle_down,
    .up          = swl_touch_handle_up,
    .motion      = swl_touch_handle_motion,
    .frame       = swl_touch_handle_frame,
    .cancel      = swl_touch_handle_cancel,
    .shape       = swl_touch_handle_shape,
    .orientation = swl_touch_handle_orientation,
};

int swl_touch_add_listener(
    struct wl_touch *touch,
    const struct swl_touch_listener_callbacks *callbacks)
{
    return wl_touch_add_listener(
        touch, &swl_touch_listener_impl, (void *)callbacks);
}
