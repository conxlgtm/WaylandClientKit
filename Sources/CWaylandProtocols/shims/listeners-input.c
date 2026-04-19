#include "wayforge-shims.h"

static void swl_seat_handle_capabilities(
    void *data,
    struct wl_seat *seat,
    uint32_t capabilities)
{
    const struct swl_seat_listener_callbacks *callbacks = data;
    if (callbacks != NULL && callbacks->capabilities != NULL)
    {
        callbacks->capabilities(callbacks->data, seat, capabilities);
    }
}

static void swl_seat_handle_name(
    void *data,
    struct wl_seat *seat,
    const char *name)
{
    const struct swl_seat_listener_callbacks *callbacks = data;
    if (callbacks != NULL && callbacks->name != NULL)
    {
        callbacks->name(callbacks->data, seat, name);
    }
}

static const struct wl_seat_listener swl_seat_listener_impl = {
    .capabilities = swl_seat_handle_capabilities,
    .name = swl_seat_handle_name,
};

int swl_seat_add_listener(
    struct wl_seat *seat,
    const struct swl_seat_listener_callbacks *callbacks)
{
    return wl_seat_add_listener(
        seat,
        &swl_seat_listener_impl,
        (void *)callbacks);
}

static void swl_pointer_handle_enter(
    void *data,
    struct wl_pointer *pointer,
    uint32_t serial,
    struct wl_surface *surface,
    wl_fixed_t surfaceX,
    wl_fixed_t surfaceY)
{
    const struct swl_pointer_listener_callbacks *callbacks = data;
    if (callbacks != NULL && callbacks->enter != NULL)
    {
        callbacks->enter(
            callbacks->data,
            pointer,
            serial,
            surface,
            surfaceX,
            surfaceY);
    }
}

static void swl_pointer_handle_leave(
    void *data,
    struct wl_pointer *pointer,
    uint32_t serial,
    struct wl_surface *surface)
{
    const struct swl_pointer_listener_callbacks *callbacks = data;
    if (callbacks != NULL && callbacks->leave != NULL)
    {
        callbacks->leave(callbacks->data, pointer, serial, surface);
    }
}

static void swl_pointer_handle_motion(
    void *data,
    struct wl_pointer *pointer,
    uint32_t time,
    wl_fixed_t surfaceX,
    wl_fixed_t surfaceY)
{
    const struct swl_pointer_listener_callbacks *callbacks = data;
    if (callbacks != NULL && callbacks->motion != NULL)
    {
        callbacks->motion(callbacks->data, pointer, time, surfaceX, surfaceY);
    }
}

static void swl_pointer_handle_button(
    void *data,
    struct wl_pointer *pointer,
    uint32_t serial,
    uint32_t time,
    uint32_t button,
    uint32_t state)
{
    const struct swl_pointer_listener_callbacks *callbacks = data;
    if (callbacks != NULL && callbacks->button != NULL)
    {
        callbacks->button(
            callbacks->data,
            pointer,
            serial,
            time,
            button,
            state);
    }
}

static void swl_pointer_handle_axis(
    void *data,
    struct wl_pointer *pointer,
    uint32_t time,
    uint32_t axis,
    wl_fixed_t value)
{
    const struct swl_pointer_listener_callbacks *callbacks = data;
    if (callbacks != NULL && callbacks->axis != NULL)
    {
        callbacks->axis(callbacks->data, pointer, time, axis, value);
    }
}

static void swl_pointer_handle_frame(
    void *data,
    struct wl_pointer *pointer)
{
    const struct swl_pointer_listener_callbacks *callbacks = data;
    if (callbacks != NULL && callbacks->frame != NULL)
    {
        callbacks->frame(callbacks->data, pointer);
    }
}

static void swl_pointer_handle_axis_source(
    void *data,
    struct wl_pointer *pointer,
    uint32_t axisSource)
{
    const struct swl_pointer_listener_callbacks *callbacks = data;
    if (callbacks != NULL && callbacks->axis_source != NULL)
    {
        callbacks->axis_source(callbacks->data, pointer, axisSource);
    }
}

static void swl_pointer_handle_axis_stop(
    void *data,
    struct wl_pointer *pointer,
    uint32_t time,
    uint32_t axis)
{
    const struct swl_pointer_listener_callbacks *callbacks = data;
    if (callbacks != NULL && callbacks->axis_stop != NULL)
    {
        callbacks->axis_stop(callbacks->data, pointer, time, axis);
    }
}

static void swl_pointer_handle_axis_discrete(
    void *data,
    struct wl_pointer *pointer,
    uint32_t axis,
    int32_t discrete)
{
    const struct swl_pointer_listener_callbacks *callbacks = data;
    if (callbacks != NULL && callbacks->axis_discrete != NULL)
    {
        callbacks->axis_discrete(callbacks->data, pointer, axis, discrete);
    }
}

static void swl_pointer_handle_axis_value120(
    void *data,
    struct wl_pointer *pointer,
    uint32_t axis,
    int32_t value120)
{
    const struct swl_pointer_listener_callbacks *callbacks = data;
    if (callbacks != NULL && callbacks->axis_value120 != NULL)
    {
        callbacks->axis_value120(callbacks->data, pointer, axis, value120);
    }
}

static void swl_pointer_handle_axis_relative_direction(
    void *data,
    struct wl_pointer *pointer,
    uint32_t axis,
    uint32_t direction)
{
    const struct swl_pointer_listener_callbacks *callbacks = data;
    if (callbacks != NULL && callbacks->axis_relative_direction != NULL)
    {
        callbacks->axis_relative_direction(
            callbacks->data,
            pointer,
            axis,
            direction);
    }
}

static const struct wl_pointer_listener swl_pointer_listener_impl = {
    .enter = swl_pointer_handle_enter,
    .leave = swl_pointer_handle_leave,
    .motion = swl_pointer_handle_motion,
    .button = swl_pointer_handle_button,
    .axis = swl_pointer_handle_axis,
    .frame = swl_pointer_handle_frame,
    .axis_source = swl_pointer_handle_axis_source,
    .axis_stop = swl_pointer_handle_axis_stop,
    .axis_discrete = swl_pointer_handle_axis_discrete,
    .axis_value120 = swl_pointer_handle_axis_value120,
    .axis_relative_direction = swl_pointer_handle_axis_relative_direction,
};

int swl_pointer_add_listener(
    struct wl_pointer *pointer,
    const struct swl_pointer_listener_callbacks *callbacks)
{
    return wl_pointer_add_listener(
        pointer,
        &swl_pointer_listener_impl,
        (void *)callbacks);
}

static void swl_keyboard_handle_keymap(
    void *data,
    struct wl_keyboard *keyboard,
    uint32_t format,
    int32_t fd,
    uint32_t size)
{
    const struct swl_keyboard_listener_callbacks *callbacks = data;
    if (callbacks != NULL && callbacks->keymap != NULL)
    {
        callbacks->keymap(callbacks->data, keyboard, format, fd, size);
    }
}

static void swl_keyboard_handle_enter(
    void *data,
    struct wl_keyboard *keyboard,
    uint32_t serial,
    struct wl_surface *surface,
    struct wl_array *keys)
{
    const struct swl_keyboard_listener_callbacks *callbacks = data;
    if (callbacks != NULL && callbacks->enter != NULL)
    {
        callbacks->enter(callbacks->data, keyboard, serial, surface, keys);
    }
}

static void swl_keyboard_handle_leave(
    void *data,
    struct wl_keyboard *keyboard,
    uint32_t serial,
    struct wl_surface *surface)
{
    const struct swl_keyboard_listener_callbacks *callbacks = data;
    if (callbacks != NULL && callbacks->leave != NULL)
    {
        callbacks->leave(callbacks->data, keyboard, serial, surface);
    }
}

static void swl_keyboard_handle_key(
    void *data,
    struct wl_keyboard *keyboard,
    uint32_t serial,
    uint32_t time,
    uint32_t key,
    uint32_t state)
{
    const struct swl_keyboard_listener_callbacks *callbacks = data;
    if (callbacks != NULL && callbacks->key != NULL)
    {
        callbacks->key(callbacks->data, keyboard, serial, time, key, state);
    }
}

static void swl_keyboard_handle_modifiers(
    void *data,
    struct wl_keyboard *keyboard,
    uint32_t serial,
    uint32_t modsDepressed,
    uint32_t modsLatched,
    uint32_t modsLocked,
    uint32_t group)
{
    const struct swl_keyboard_listener_callbacks *callbacks = data;
    if (callbacks != NULL && callbacks->modifiers != NULL)
    {
        callbacks->modifiers(
            callbacks->data,
            keyboard,
            serial,
            modsDepressed,
            modsLatched,
            modsLocked,
            group);
    }
}

static void swl_keyboard_handle_repeat_info(
    void *data,
    struct wl_keyboard *keyboard,
    int32_t rate,
    int32_t delay)
{
    const struct swl_keyboard_listener_callbacks *callbacks = data;
    if (callbacks != NULL && callbacks->repeat_info != NULL)
    {
        callbacks->repeat_info(callbacks->data, keyboard, rate, delay);
    }
}

static const struct wl_keyboard_listener swl_keyboard_listener_impl = {
    .keymap = swl_keyboard_handle_keymap,
    .enter = swl_keyboard_handle_enter,
    .leave = swl_keyboard_handle_leave,
    .key = swl_keyboard_handle_key,
    .modifiers = swl_keyboard_handle_modifiers,
    .repeat_info = swl_keyboard_handle_repeat_info,
};

int swl_keyboard_add_listener(
    struct wl_keyboard *keyboard,
    const struct swl_keyboard_listener_callbacks *callbacks)
{
    return wl_keyboard_add_listener(
        keyboard,
        &swl_keyboard_listener_impl,
        (void *)callbacks);
}

static void swl_touch_handle_down(
    void *data,
    struct wl_touch *touch,
    uint32_t serial,
    uint32_t time,
    struct wl_surface *surface,
    int32_t id,
    wl_fixed_t x,
    wl_fixed_t y)
{
    const struct swl_touch_listener_callbacks *callbacks = data;
    if (callbacks != NULL && callbacks->down != NULL)
    {
        callbacks->down(
            callbacks->data,
            touch,
            serial,
            time,
            surface,
            id,
            x,
            y);
    }
}

static void swl_touch_handle_up(
    void *data,
    struct wl_touch *touch,
    uint32_t serial,
    uint32_t time,
    int32_t id)
{
    const struct swl_touch_listener_callbacks *callbacks = data;
    if (callbacks != NULL && callbacks->up != NULL)
    {
        callbacks->up(callbacks->data, touch, serial, time, id);
    }
}

static void swl_touch_handle_motion(
    void *data,
    struct wl_touch *touch,
    uint32_t time,
    int32_t id,
    wl_fixed_t x,
    wl_fixed_t y)
{
    const struct swl_touch_listener_callbacks *callbacks = data;
    if (callbacks != NULL && callbacks->motion != NULL)
    {
        callbacks->motion(callbacks->data, touch, time, id, x, y);
    }
}

static void swl_touch_handle_frame(
    void *data,
    struct wl_touch *touch)
{
    const struct swl_touch_listener_callbacks *callbacks = data;
    if (callbacks != NULL && callbacks->frame != NULL)
    {
        callbacks->frame(callbacks->data, touch);
    }
}

static void swl_touch_handle_cancel(
    void *data,
    struct wl_touch *touch)
{
    const struct swl_touch_listener_callbacks *callbacks = data;
    if (callbacks != NULL && callbacks->cancel != NULL)
    {
        callbacks->cancel(callbacks->data, touch);
    }
}

static void swl_touch_handle_shape(
    void *data,
    struct wl_touch *touch,
    int32_t id,
    wl_fixed_t major,
    wl_fixed_t minor)
{
    const struct swl_touch_listener_callbacks *callbacks = data;
    if (callbacks != NULL && callbacks->shape != NULL)
    {
        callbacks->shape(callbacks->data, touch, id, major, minor);
    }
}

static void swl_touch_handle_orientation(
    void *data,
    struct wl_touch *touch,
    int32_t id,
    wl_fixed_t orientation)
{
    const struct swl_touch_listener_callbacks *callbacks = data;
    if (callbacks != NULL && callbacks->orientation != NULL)
    {
        callbacks->orientation(callbacks->data, touch, id, orientation);
    }
}

static const struct wl_touch_listener swl_touch_listener_impl = {
    .down = swl_touch_handle_down,
    .up = swl_touch_handle_up,
    .motion = swl_touch_handle_motion,
    .frame = swl_touch_handle_frame,
    .cancel = swl_touch_handle_cancel,
    .shape = swl_touch_handle_shape,
    .orientation = swl_touch_handle_orientation,
};

int swl_touch_add_listener(
    struct wl_touch *touch,
    const struct swl_touch_listener_callbacks *callbacks)
{
    return wl_touch_add_listener(
        touch,
        &swl_touch_listener_impl,
        (void *)callbacks);
}
