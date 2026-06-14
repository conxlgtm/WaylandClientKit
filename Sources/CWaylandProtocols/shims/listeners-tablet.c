#include "wayland-client-kit-shims.h"
#include "generated/stable/tablet/tablet-v2-client-protocol.h"

static void swl_tablet_seat_handle_tablet_added(
    void *data,
    struct zwp_tablet_seat_v2 *seat,
    struct zwp_tablet_v2 *tablet)
{
    const struct swl_zwp_tablet_seat_v2_listener_callbacks *cb = data;
    if (cb && cb->tablet_added)
        cb->tablet_added(cb->data, seat, tablet);
}

static void swl_tablet_seat_handle_tool_added(
    void *data,
    struct zwp_tablet_seat_v2 *seat,
    struct zwp_tablet_tool_v2 *tool)
{
    const struct swl_zwp_tablet_seat_v2_listener_callbacks *cb = data;
    if (cb && cb->tool_added)
        cb->tool_added(cb->data, seat, tool);
}

static void swl_tablet_seat_handle_pad_added(
    void *data,
    struct zwp_tablet_seat_v2 *seat,
    struct zwp_tablet_pad_v2 *pad)
{
    const struct swl_zwp_tablet_seat_v2_listener_callbacks *cb = data;
    if (cb && cb->pad_added)
        cb->pad_added(cb->data, seat, pad);
}

static const struct zwp_tablet_seat_v2_listener swl_tablet_seat_listener_impl = {
    .tablet_added = swl_tablet_seat_handle_tablet_added,
    .tool_added   = swl_tablet_seat_handle_tool_added,
    .pad_added    = swl_tablet_seat_handle_pad_added,
};

int swl_zwp_tablet_seat_v2_add_listener(
    struct zwp_tablet_seat_v2 *seat,
    const struct swl_zwp_tablet_seat_v2_listener_callbacks *callbacks)
{
    return zwp_tablet_seat_v2_add_listener(
        seat, &swl_tablet_seat_listener_impl, (void *)callbacks);
}

static void swl_tablet_handle_name(
    void *data,
    struct zwp_tablet_v2 *tablet,
    const char *name)
{
    const struct swl_zwp_tablet_v2_listener_callbacks *cb = data;
    if (cb && cb->name)
        cb->name(cb->data, tablet, name);
}

static void swl_tablet_handle_id(
    void *data,
    struct zwp_tablet_v2 *tablet,
    uint32_t vid,
    uint32_t pid)
{
    const struct swl_zwp_tablet_v2_listener_callbacks *cb = data;
    if (cb && cb->id)
        cb->id(cb->data, tablet, vid, pid);
}

static void swl_tablet_handle_path(
    void *data,
    struct zwp_tablet_v2 *tablet,
    const char *path)
{
    const struct swl_zwp_tablet_v2_listener_callbacks *cb = data;
    if (cb && cb->path)
        cb->path(cb->data, tablet, path);
}

static void swl_tablet_handle_done(void *data, struct zwp_tablet_v2 *tablet)
{
    const struct swl_zwp_tablet_v2_listener_callbacks *cb = data;
    if (cb && cb->done)
        cb->done(cb->data, tablet);
}

static void swl_tablet_handle_removed(void *data, struct zwp_tablet_v2 *tablet)
{
    const struct swl_zwp_tablet_v2_listener_callbacks *cb = data;
    if (cb && cb->removed)
        cb->removed(cb->data, tablet);
}

static void swl_tablet_handle_bustype(
    void *data,
    struct zwp_tablet_v2 *tablet,
    uint32_t bustype)
{
    const struct swl_zwp_tablet_v2_listener_callbacks *cb = data;
    if (cb && cb->bustype)
        cb->bustype(cb->data, tablet, bustype);
}

static const struct zwp_tablet_v2_listener swl_tablet_listener_impl = {
    .name    = swl_tablet_handle_name,
    .id      = swl_tablet_handle_id,
    .path    = swl_tablet_handle_path,
    .done    = swl_tablet_handle_done,
    .removed = swl_tablet_handle_removed,
    .bustype = swl_tablet_handle_bustype,
};

int swl_zwp_tablet_v2_add_listener(
    struct zwp_tablet_v2 *tablet,
    const struct swl_zwp_tablet_v2_listener_callbacks *callbacks)
{
    return zwp_tablet_v2_add_listener(
        tablet, &swl_tablet_listener_impl, (void *)callbacks);
}

static void swl_tool_handle_type(void *data, struct zwp_tablet_tool_v2 *tool, uint32_t type)
{
    const struct swl_zwp_tablet_tool_v2_listener_callbacks *cb = data;
    if (cb && cb->type)
        cb->type(cb->data, tool, type);
}

static void swl_tool_handle_hardware_serial(
    void *data,
    struct zwp_tablet_tool_v2 *tool,
    uint32_t serial_hi,
    uint32_t serial_lo)
{
    const struct swl_zwp_tablet_tool_v2_listener_callbacks *cb = data;
    if (cb && cb->hardware_serial)
        cb->hardware_serial(cb->data, tool, serial_hi, serial_lo);
}

static void swl_tool_handle_hardware_id_wacom(
    void *data,
    struct zwp_tablet_tool_v2 *tool,
    uint32_t hardware_id_hi,
    uint32_t hardware_id_lo)
{
    const struct swl_zwp_tablet_tool_v2_listener_callbacks *cb = data;
    if (cb && cb->hardware_id_wacom)
        cb->hardware_id_wacom(cb->data, tool, hardware_id_hi, hardware_id_lo);
}

static void swl_tool_handle_capability(
    void *data,
    struct zwp_tablet_tool_v2 *tool,
    uint32_t capability)
{
    const struct swl_zwp_tablet_tool_v2_listener_callbacks *cb = data;
    if (cb && cb->capability)
        cb->capability(cb->data, tool, capability);
}

static void swl_tool_handle_done(void *data, struct zwp_tablet_tool_v2 *tool)
{
    const struct swl_zwp_tablet_tool_v2_listener_callbacks *cb = data;
    if (cb && cb->done)
        cb->done(cb->data, tool);
}

static void swl_tool_handle_removed(void *data, struct zwp_tablet_tool_v2 *tool)
{
    const struct swl_zwp_tablet_tool_v2_listener_callbacks *cb = data;
    if (cb && cb->removed)
        cb->removed(cb->data, tool);
}

static void swl_tool_handle_proximity_in(
    void *data,
    struct zwp_tablet_tool_v2 *tool,
    uint32_t serial,
    struct zwp_tablet_v2 *tablet,
    struct wl_surface *surface)
{
    const struct swl_zwp_tablet_tool_v2_listener_callbacks *cb = data;
    if (cb && cb->proximity_in)
        cb->proximity_in(cb->data, tool, serial, tablet, surface);
}

static void swl_tool_handle_proximity_out(void *data, struct zwp_tablet_tool_v2 *tool)
{
    const struct swl_zwp_tablet_tool_v2_listener_callbacks *cb = data;
    if (cb && cb->proximity_out)
        cb->proximity_out(cb->data, tool);
}

static void swl_tool_handle_down(
    void *data,
    struct zwp_tablet_tool_v2 *tool,
    uint32_t serial)
{
    const struct swl_zwp_tablet_tool_v2_listener_callbacks *cb = data;
    if (cb && cb->down)
        cb->down(cb->data, tool, serial);
}

static void swl_tool_handle_up(void *data, struct zwp_tablet_tool_v2 *tool)
{
    const struct swl_zwp_tablet_tool_v2_listener_callbacks *cb = data;
    if (cb && cb->up)
        cb->up(cb->data, tool);
}

static void swl_tool_handle_motion(
    void *data,
    struct zwp_tablet_tool_v2 *tool,
    wl_fixed_t x,
    wl_fixed_t y)
{
    const struct swl_zwp_tablet_tool_v2_listener_callbacks *cb = data;
    if (cb && cb->motion)
        cb->motion(cb->data, tool, x, y);
}

static void swl_tool_handle_pressure(
    void *data,
    struct zwp_tablet_tool_v2 *tool,
    uint32_t pressure)
{
    const struct swl_zwp_tablet_tool_v2_listener_callbacks *cb = data;
    if (cb && cb->pressure)
        cb->pressure(cb->data, tool, pressure);
}

static void swl_tool_handle_distance(
    void *data,
    struct zwp_tablet_tool_v2 *tool,
    uint32_t distance)
{
    const struct swl_zwp_tablet_tool_v2_listener_callbacks *cb = data;
    if (cb && cb->distance)
        cb->distance(cb->data, tool, distance);
}

static void swl_tool_handle_tilt(
    void *data,
    struct zwp_tablet_tool_v2 *tool,
    wl_fixed_t x,
    wl_fixed_t y)
{
    const struct swl_zwp_tablet_tool_v2_listener_callbacks *cb = data;
    if (cb && cb->tilt)
        cb->tilt(cb->data, tool, x, y);
}

static void swl_tool_handle_rotation(
    void *data,
    struct zwp_tablet_tool_v2 *tool,
    wl_fixed_t degrees)
{
    const struct swl_zwp_tablet_tool_v2_listener_callbacks *cb = data;
    if (cb && cb->rotation)
        cb->rotation(cb->data, tool, degrees);
}

static void swl_tool_handle_slider(
    void *data,
    struct zwp_tablet_tool_v2 *tool,
    int32_t position)
{
    const struct swl_zwp_tablet_tool_v2_listener_callbacks *cb = data;
    if (cb && cb->slider)
        cb->slider(cb->data, tool, position);
}

static void swl_tool_handle_wheel(
    void *data,
    struct zwp_tablet_tool_v2 *tool,
    wl_fixed_t degrees,
    int32_t clicks)
{
    const struct swl_zwp_tablet_tool_v2_listener_callbacks *cb = data;
    if (cb && cb->wheel)
        cb->wheel(cb->data, tool, degrees, clicks);
}

static void swl_tool_handle_button(
    void *data,
    struct zwp_tablet_tool_v2 *tool,
    uint32_t serial,
    uint32_t button,
    uint32_t state)
{
    const struct swl_zwp_tablet_tool_v2_listener_callbacks *cb = data;
    if (cb && cb->button)
        cb->button(cb->data, tool, serial, button, state);
}

static void swl_tool_handle_frame(
    void *data,
    struct zwp_tablet_tool_v2 *tool,
    uint32_t time)
{
    const struct swl_zwp_tablet_tool_v2_listener_callbacks *cb = data;
    if (cb && cb->frame)
        cb->frame(cb->data, tool, time);
}

static const struct zwp_tablet_tool_v2_listener swl_tablet_tool_listener_impl = {
    .type              = swl_tool_handle_type,
    .hardware_serial   = swl_tool_handle_hardware_serial,
    .hardware_id_wacom = swl_tool_handle_hardware_id_wacom,
    .capability        = swl_tool_handle_capability,
    .done              = swl_tool_handle_done,
    .removed           = swl_tool_handle_removed,
    .proximity_in      = swl_tool_handle_proximity_in,
    .proximity_out     = swl_tool_handle_proximity_out,
    .down              = swl_tool_handle_down,
    .up                = swl_tool_handle_up,
    .motion            = swl_tool_handle_motion,
    .pressure          = swl_tool_handle_pressure,
    .distance          = swl_tool_handle_distance,
    .tilt              = swl_tool_handle_tilt,
    .rotation          = swl_tool_handle_rotation,
    .slider            = swl_tool_handle_slider,
    .wheel             = swl_tool_handle_wheel,
    .button            = swl_tool_handle_button,
    .frame             = swl_tool_handle_frame,
};

int swl_zwp_tablet_tool_v2_add_listener(
    struct zwp_tablet_tool_v2 *tool,
    const struct swl_zwp_tablet_tool_v2_listener_callbacks *callbacks)
{
    return zwp_tablet_tool_v2_add_listener(
        tool, &swl_tablet_tool_listener_impl, (void *)callbacks);
}

static void swl_pad_handle_group(
    void *data,
    struct zwp_tablet_pad_v2 *pad,
    struct zwp_tablet_pad_group_v2 *group)
{
    const struct swl_zwp_tablet_pad_v2_listener_callbacks *cb = data;
    if (cb && cb->group)
        cb->group(cb->data, pad, group);
}

static void swl_pad_handle_path(void *data, struct zwp_tablet_pad_v2 *pad, const char *path)
{
    const struct swl_zwp_tablet_pad_v2_listener_callbacks *cb = data;
    if (cb && cb->path)
        cb->path(cb->data, pad, path);
}

static void swl_pad_handle_buttons(void *data, struct zwp_tablet_pad_v2 *pad, uint32_t buttons)
{
    const struct swl_zwp_tablet_pad_v2_listener_callbacks *cb = data;
    if (cb && cb->buttons)
        cb->buttons(cb->data, pad, buttons);
}

static void swl_pad_handle_done(void *data, struct zwp_tablet_pad_v2 *pad)
{
    const struct swl_zwp_tablet_pad_v2_listener_callbacks *cb = data;
    if (cb && cb->done)
        cb->done(cb->data, pad);
}

static void swl_pad_handle_button(
    void *data,
    struct zwp_tablet_pad_v2 *pad,
    uint32_t time,
    uint32_t button,
    uint32_t state)
{
    const struct swl_zwp_tablet_pad_v2_listener_callbacks *cb = data;
    if (cb && cb->button)
        cb->button(cb->data, pad, time, button, state);
}

static void swl_pad_handle_enter(
    void *data,
    struct zwp_tablet_pad_v2 *pad,
    uint32_t serial,
    struct zwp_tablet_v2 *tablet,
    struct wl_surface *surface)
{
    const struct swl_zwp_tablet_pad_v2_listener_callbacks *cb = data;
    if (cb && cb->enter)
        cb->enter(cb->data, pad, serial, tablet, surface);
}

static void swl_pad_handle_leave(
    void *data,
    struct zwp_tablet_pad_v2 *pad,
    uint32_t serial,
    struct wl_surface *surface)
{
    const struct swl_zwp_tablet_pad_v2_listener_callbacks *cb = data;
    if (cb && cb->leave)
        cb->leave(cb->data, pad, serial, surface);
}

static void swl_pad_handle_removed(void *data, struct zwp_tablet_pad_v2 *pad)
{
    const struct swl_zwp_tablet_pad_v2_listener_callbacks *cb = data;
    if (cb && cb->removed)
        cb->removed(cb->data, pad);
}

static const struct zwp_tablet_pad_v2_listener swl_tablet_pad_listener_impl = {
    .group   = swl_pad_handle_group,
    .path    = swl_pad_handle_path,
    .buttons = swl_pad_handle_buttons,
    .done    = swl_pad_handle_done,
    .button  = swl_pad_handle_button,
    .enter   = swl_pad_handle_enter,
    .leave   = swl_pad_handle_leave,
    .removed = swl_pad_handle_removed,
};

int swl_zwp_tablet_pad_v2_add_listener(
    struct zwp_tablet_pad_v2 *pad,
    const struct swl_zwp_tablet_pad_v2_listener_callbacks *callbacks)
{
    return zwp_tablet_pad_v2_add_listener(
        pad, &swl_tablet_pad_listener_impl, (void *)callbacks);
}

static void swl_pad_group_handle_buttons(
    void *data,
    struct zwp_tablet_pad_group_v2 *group,
    struct wl_array *buttons)
{
    const struct swl_zwp_tablet_pad_group_v2_listener_callbacks *cb = data;
    if (cb && cb->buttons)
        cb->buttons(cb->data, group, buttons);
}

static void swl_pad_group_handle_ring(
    void *data,
    struct zwp_tablet_pad_group_v2 *group,
    struct zwp_tablet_pad_ring_v2 *ring)
{
    const struct swl_zwp_tablet_pad_group_v2_listener_callbacks *cb = data;
    if (cb && cb->ring)
        cb->ring(cb->data, group, ring);
}

static void swl_pad_group_handle_strip(
    void *data,
    struct zwp_tablet_pad_group_v2 *group,
    struct zwp_tablet_pad_strip_v2 *strip)
{
    const struct swl_zwp_tablet_pad_group_v2_listener_callbacks *cb = data;
    if (cb && cb->strip)
        cb->strip(cb->data, group, strip);
}

static void swl_pad_group_handle_modes(
    void *data,
    struct zwp_tablet_pad_group_v2 *group,
    uint32_t modes)
{
    const struct swl_zwp_tablet_pad_group_v2_listener_callbacks *cb = data;
    if (cb && cb->modes)
        cb->modes(cb->data, group, modes);
}

static void swl_pad_group_handle_done(void *data, struct zwp_tablet_pad_group_v2 *group)
{
    const struct swl_zwp_tablet_pad_group_v2_listener_callbacks *cb = data;
    if (cb && cb->done)
        cb->done(cb->data, group);
}

static void swl_pad_group_handle_mode_switch(
    void *data,
    struct zwp_tablet_pad_group_v2 *group,
    uint32_t time,
    uint32_t serial,
    uint32_t mode)
{
    const struct swl_zwp_tablet_pad_group_v2_listener_callbacks *cb = data;
    if (cb && cb->mode_switch)
        cb->mode_switch(cb->data, group, time, serial, mode);
}

static void swl_pad_group_handle_dial(
    void *data,
    struct zwp_tablet_pad_group_v2 *group,
    struct zwp_tablet_pad_dial_v2 *dial)
{
    const struct swl_zwp_tablet_pad_group_v2_listener_callbacks *cb = data;
    if (cb && cb->dial)
        cb->dial(cb->data, group, dial);
}

static const struct zwp_tablet_pad_group_v2_listener swl_tablet_pad_group_listener_impl = {
    .buttons     = swl_pad_group_handle_buttons,
    .ring        = swl_pad_group_handle_ring,
    .strip       = swl_pad_group_handle_strip,
    .modes       = swl_pad_group_handle_modes,
    .done        = swl_pad_group_handle_done,
    .mode_switch = swl_pad_group_handle_mode_switch,
    .dial        = swl_pad_group_handle_dial,
};

int swl_zwp_tablet_pad_group_v2_add_listener(
    struct zwp_tablet_pad_group_v2 *group,
    const struct swl_zwp_tablet_pad_group_v2_listener_callbacks *callbacks)
{
    return zwp_tablet_pad_group_v2_add_listener(
        group, &swl_tablet_pad_group_listener_impl, (void *)callbacks);
}
