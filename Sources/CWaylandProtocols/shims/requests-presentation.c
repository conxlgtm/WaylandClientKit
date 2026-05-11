#include "swift-wayland-shims.h"
#include "generated/stable/presentation-time/presentation-time-client-protocol.h"

struct wp_presentation_feedback *swl_wp_presentation_feedback(
    struct wp_presentation *presentation,
    struct wl_surface *surface)
{
    return wp_presentation_feedback(presentation, surface);
}

void swl_wp_presentation_destroy(struct wp_presentation *presentation)
{
    wp_presentation_destroy(presentation);
}

void swl_wp_presentation_feedback_destroy(
    struct wp_presentation_feedback *feedback)
{
    wp_presentation_feedback_destroy(feedback);
}
