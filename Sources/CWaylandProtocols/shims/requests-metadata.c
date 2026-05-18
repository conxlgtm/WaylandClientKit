#include "swift-wayland-shims.h"
#include "generated/staging/content-type/content-type-v1-client-protocol.h"
#include "generated/staging/alpha-modifier/alpha-modifier-v1-client-protocol.h"
#include "generated/staging/tearing-control/tearing-control-v1-client-protocol.h"
#include "generated/staging/color-representation/color-representation-v1-client-protocol.h"
#include "generated/staging/color-management/color-management-v1-client-protocol.h"

struct wp_content_type_v1 *swl_wp_content_type_manager_v1_get_surface_content_type(
    struct wp_content_type_manager_v1 *manager,
    struct wl_surface *surface)
{
    return wp_content_type_manager_v1_get_surface_content_type(manager, surface);
}

void swl_wp_content_type_v1_set_content_type(
    struct wp_content_type_v1 *content_type,
    uint32_t value)
{
    wp_content_type_v1_set_content_type(content_type, value);
}

void swl_wp_content_type_v1_destroy(struct wp_content_type_v1 *content_type)
{
    wp_content_type_v1_destroy(content_type);
}

void swl_wp_content_type_manager_v1_destroy(
    struct wp_content_type_manager_v1 *manager)
{
    wp_content_type_manager_v1_destroy(manager);
}

struct wp_alpha_modifier_surface_v1 *swl_wp_alpha_modifier_v1_get_surface(
    struct wp_alpha_modifier_v1 *manager,
    struct wl_surface *surface)
{
    return wp_alpha_modifier_v1_get_surface(manager, surface);
}

void swl_wp_alpha_modifier_surface_v1_set_multiplier(
    struct wp_alpha_modifier_surface_v1 *surface,
    uint32_t factor)
{
    wp_alpha_modifier_surface_v1_set_multiplier(surface, factor);
}

void swl_wp_alpha_modifier_surface_v1_destroy(
    struct wp_alpha_modifier_surface_v1 *surface)
{
    wp_alpha_modifier_surface_v1_destroy(surface);
}

void swl_wp_alpha_modifier_v1_destroy(struct wp_alpha_modifier_v1 *manager)
{
    wp_alpha_modifier_v1_destroy(manager);
}

struct wp_tearing_control_v1 *
swl_wp_tearing_control_manager_v1_get_tearing_control(
    struct wp_tearing_control_manager_v1 *manager,
    struct wl_surface *surface)
{
    return wp_tearing_control_manager_v1_get_tearing_control(manager, surface);
}

void swl_wp_tearing_control_v1_set_presentation_hint(
    struct wp_tearing_control_v1 *tearing_control,
    uint32_t hint)
{
    wp_tearing_control_v1_set_presentation_hint(tearing_control, hint);
}

void swl_wp_tearing_control_v1_destroy(
    struct wp_tearing_control_v1 *tearing_control)
{
    wp_tearing_control_v1_destroy(tearing_control);
}

void swl_wp_tearing_control_manager_v1_destroy(
    struct wp_tearing_control_manager_v1 *manager)
{
    wp_tearing_control_manager_v1_destroy(manager);
}

struct wp_color_representation_surface_v1 *
swl_wp_color_representation_manager_v1_get_surface(
    struct wp_color_representation_manager_v1 *manager,
    struct wl_surface *surface)
{
    return wp_color_representation_manager_v1_get_surface(manager, surface);
}

void swl_wp_color_representation_surface_v1_set_alpha_mode(
    struct wp_color_representation_surface_v1 *surface,
    uint32_t alpha_mode)
{
    wp_color_representation_surface_v1_set_alpha_mode(surface, alpha_mode);
}

void swl_wp_color_representation_surface_v1_set_coefficients_and_range(
    struct wp_color_representation_surface_v1 *surface,
    uint32_t coefficients,
    uint32_t range)
{
    wp_color_representation_surface_v1_set_coefficients_and_range(
        surface, coefficients, range);
}

void swl_wp_color_representation_surface_v1_set_chroma_location(
    struct wp_color_representation_surface_v1 *surface,
    uint32_t chroma_location)
{
    wp_color_representation_surface_v1_set_chroma_location(surface, chroma_location);
}

void swl_wp_color_representation_surface_v1_destroy(
    struct wp_color_representation_surface_v1 *surface)
{
    wp_color_representation_surface_v1_destroy(surface);
}

void swl_wp_color_representation_manager_v1_destroy(
    struct wp_color_representation_manager_v1 *manager)
{
    wp_color_representation_manager_v1_destroy(manager);
}

struct wp_color_management_output_v1 *swl_wp_color_manager_v1_get_output(
    struct wp_color_manager_v1 *manager,
    struct wl_output *output)
{
    return wp_color_manager_v1_get_output(manager, output);
}

struct wp_color_management_surface_v1 *swl_wp_color_manager_v1_get_surface(
    struct wp_color_manager_v1 *manager,
    struct wl_surface *surface)
{
    return wp_color_manager_v1_get_surface(manager, surface);
}

struct wp_color_management_surface_feedback_v1 *
swl_wp_color_manager_v1_get_surface_feedback(
    struct wp_color_manager_v1 *manager,
    struct wl_surface *surface)
{
    return wp_color_manager_v1_get_surface_feedback(manager, surface);
}

struct wp_image_description_v1 *swl_wp_color_manager_v1_get_image_description(
    struct wp_color_manager_v1 *manager,
    struct wp_image_description_reference_v1 *reference)
{
    return wp_color_manager_v1_get_image_description(manager, reference);
}

struct wp_image_description_v1 *
swl_wp_color_management_output_v1_get_image_description(
    struct wp_color_management_output_v1 *output)
{
    return wp_color_management_output_v1_get_image_description(output);
}

void swl_wp_color_management_surface_v1_set_image_description(
    struct wp_color_management_surface_v1 *surface,
    struct wp_image_description_v1 *image_description,
    uint32_t render_intent)
{
    wp_color_management_surface_v1_set_image_description(
        surface, image_description, render_intent);
}

void swl_wp_color_management_surface_v1_unset_image_description(
    struct wp_color_management_surface_v1 *surface)
{
    wp_color_management_surface_v1_unset_image_description(surface);
}

struct wp_image_description_v1 *
swl_wp_color_management_surface_feedback_v1_get_preferred(
    struct wp_color_management_surface_feedback_v1 *feedback)
{
    return wp_color_management_surface_feedback_v1_get_preferred(feedback);
}

void swl_wp_color_management_output_v1_destroy(
    struct wp_color_management_output_v1 *output)
{
    wp_color_management_output_v1_destroy(output);
}

void swl_wp_color_management_surface_v1_destroy(
    struct wp_color_management_surface_v1 *surface)
{
    wp_color_management_surface_v1_destroy(surface);
}

void swl_wp_color_management_surface_feedback_v1_destroy(
    struct wp_color_management_surface_feedback_v1 *feedback)
{
    wp_color_management_surface_feedback_v1_destroy(feedback);
}

void swl_wp_image_description_v1_destroy(
    struct wp_image_description_v1 *image_description)
{
    wp_image_description_v1_destroy(image_description);
}

void swl_wp_image_description_reference_v1_destroy(
    struct wp_image_description_reference_v1 *reference)
{
    wp_image_description_reference_v1_destroy(reference);
}

void swl_wp_color_manager_v1_destroy(struct wp_color_manager_v1 *manager)
{
    wp_color_manager_v1_destroy(manager);
}
