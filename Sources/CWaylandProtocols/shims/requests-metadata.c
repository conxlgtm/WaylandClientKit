#include "wayland-client-kit-shims.h"
#include "generated/staging/content-type/content-type-v1-client-protocol.h"
#include "generated/staging/alpha-modifier/alpha-modifier-v1-client-protocol.h"
#include "generated/staging/tearing-control/tearing-control-v1-client-protocol.h"
#include "generated/staging/color-representation/color-representation-v1-client-protocol.h"
#include "generated/staging/color-management/color-management-v1-client-protocol.h"

#ifdef SWL_ENABLE_TESTING
static struct swl_test_metadata_request_record swl_test_metadata_request_latest;
static struct swl_test_metadata_destroy_record swl_test_metadata_destroy_latest;

static struct wp_content_type_v1 *swl_content_type_get_surface_default(
    struct wp_content_type_manager_v1 *manager,
    struct wl_surface *surface)
{
    return wp_content_type_manager_v1_get_surface_content_type(manager, surface);
}

static void swl_content_type_set_default(
    struct wp_content_type_v1 *content_type,
    uint32_t value)
{
    wp_content_type_v1_set_content_type(content_type, value);
}

static void swl_content_type_destroy_default(
    struct wp_content_type_v1 *content_type)
{
    wp_content_type_v1_destroy(content_type);
}

static void swl_content_type_manager_destroy_default(
    struct wp_content_type_manager_v1 *manager)
{
    wp_content_type_manager_v1_destroy(manager);
}

static struct wp_alpha_modifier_surface_v1 *swl_alpha_modifier_get_surface_default(
    struct wp_alpha_modifier_v1 *manager,
    struct wl_surface *surface)
{
    return wp_alpha_modifier_v1_get_surface(manager, surface);
}

static void swl_alpha_modifier_set_multiplier_default(
    struct wp_alpha_modifier_surface_v1 *surface,
    uint32_t factor)
{
    wp_alpha_modifier_surface_v1_set_multiplier(surface, factor);
}

static void swl_alpha_modifier_surface_destroy_default(
    struct wp_alpha_modifier_surface_v1 *surface)
{
    wp_alpha_modifier_surface_v1_destroy(surface);
}

static void swl_alpha_modifier_manager_destroy_default(
    struct wp_alpha_modifier_v1 *manager)
{
    wp_alpha_modifier_v1_destroy(manager);
}

static struct wp_tearing_control_v1 *swl_tearing_control_get_surface_default(
    struct wp_tearing_control_manager_v1 *manager,
    struct wl_surface *surface)
{
    return wp_tearing_control_manager_v1_get_tearing_control(manager, surface);
}

static void swl_tearing_control_set_presentation_hint_default(
    struct wp_tearing_control_v1 *tearing_control,
    uint32_t hint)
{
    wp_tearing_control_v1_set_presentation_hint(tearing_control, hint);
}

static void swl_tearing_control_destroy_default(
    struct wp_tearing_control_v1 *tearing_control)
{
    wp_tearing_control_v1_destroy(tearing_control);
}

static void swl_tearing_control_manager_destroy_default(
    struct wp_tearing_control_manager_v1 *manager)
{
    wp_tearing_control_manager_v1_destroy(manager);
}

static struct wp_color_representation_surface_v1 *
swl_color_representation_get_surface_default(
    struct wp_color_representation_manager_v1 *manager,
    struct wl_surface *surface)
{
    return wp_color_representation_manager_v1_get_surface(manager, surface);
}

static void swl_color_representation_set_alpha_mode_default(
    struct wp_color_representation_surface_v1 *surface,
    uint32_t alpha_mode)
{
    wp_color_representation_surface_v1_set_alpha_mode(surface, alpha_mode);
}

static void swl_color_representation_set_coefficients_and_range_default(
    struct wp_color_representation_surface_v1 *surface,
    uint32_t coefficients,
    uint32_t range)
{
    wp_color_representation_surface_v1_set_coefficients_and_range(
        surface, coefficients, range);
}

static void swl_color_representation_set_chroma_location_default(
    struct wp_color_representation_surface_v1 *surface,
    uint32_t chroma_location)
{
    wp_color_representation_surface_v1_set_chroma_location(
        surface, chroma_location);
}

static void swl_color_representation_surface_destroy_default(
    struct wp_color_representation_surface_v1 *surface)
{
    wp_color_representation_surface_v1_destroy(surface);
}

static void swl_color_representation_manager_destroy_default(
    struct wp_color_representation_manager_v1 *manager)
{
    wp_color_representation_manager_v1_destroy(manager);
}

static struct wp_color_management_surface_v1 *swl_color_manager_get_surface_default(
    struct wp_color_manager_v1 *manager,
    struct wl_surface *surface)
{
    return wp_color_manager_v1_get_surface(manager, surface);
}

static struct wp_color_management_surface_feedback_v1 *
swl_color_manager_get_surface_feedback_default(
    struct wp_color_manager_v1 *manager,
    struct wl_surface *surface)
{
    return wp_color_manager_v1_get_surface_feedback(manager, surface);
}

static struct wp_image_description_v1 *swl_color_manager_get_image_description_default(
    struct wp_color_manager_v1 *manager,
    struct wp_image_description_reference_v1 *reference)
{
    return wp_color_manager_v1_get_image_description(manager, reference);
}

static void swl_color_management_surface_set_image_description_default(
    struct wp_color_management_surface_v1 *surface,
    struct wp_image_description_v1 *image_description,
    uint32_t render_intent)
{
    wp_color_management_surface_v1_set_image_description(
        surface, image_description, render_intent);
}

static void swl_color_management_surface_unset_image_description_default(
    struct wp_color_management_surface_v1 *surface)
{
    wp_color_management_surface_v1_unset_image_description(surface);
}

static void swl_color_management_surface_destroy_default(
    struct wp_color_management_surface_v1 *surface)
{
    wp_color_management_surface_v1_destroy(surface);
}

static struct wp_image_description_v1 *
swl_color_management_surface_feedback_get_preferred_default(
    struct wp_color_management_surface_feedback_v1 *feedback)
{
    return wp_color_management_surface_feedback_v1_get_preferred(feedback);
}

static void swl_color_management_surface_feedback_destroy_default(
    struct wp_color_management_surface_feedback_v1 *feedback)
{
    wp_color_management_surface_feedback_v1_destroy(feedback);
}

static void swl_image_description_destroy_default(
    struct wp_image_description_v1 *image_description)
{
    wp_image_description_v1_destroy(image_description);
}

static void swl_color_manager_destroy_default(struct wp_color_manager_v1 *manager)
{
    wp_color_manager_v1_destroy(manager);
}

static struct wp_content_type_v1 *(*swl_content_type_get_surface_impl)(
    struct wp_content_type_manager_v1 *manager,
    struct wl_surface *surface) =
        swl_content_type_get_surface_default;
static void (*swl_content_type_set_impl)(
    struct wp_content_type_v1 *content_type,
    uint32_t value) =
        swl_content_type_set_default;
static void (*swl_content_type_destroy_impl)(
    struct wp_content_type_v1 *content_type) =
        swl_content_type_destroy_default;
static void (*swl_content_type_manager_destroy_impl)(
    struct wp_content_type_manager_v1 *manager) =
        swl_content_type_manager_destroy_default;

static struct wp_alpha_modifier_surface_v1 *(*swl_alpha_modifier_get_surface_impl)(
    struct wp_alpha_modifier_v1 *manager,
    struct wl_surface *surface) =
        swl_alpha_modifier_get_surface_default;
static void (*swl_alpha_modifier_set_multiplier_impl)(
    struct wp_alpha_modifier_surface_v1 *surface,
    uint32_t factor) =
        swl_alpha_modifier_set_multiplier_default;
static void (*swl_alpha_modifier_surface_destroy_impl)(
    struct wp_alpha_modifier_surface_v1 *surface) =
        swl_alpha_modifier_surface_destroy_default;
static void (*swl_alpha_modifier_manager_destroy_impl)(
    struct wp_alpha_modifier_v1 *manager) =
        swl_alpha_modifier_manager_destroy_default;

static struct wp_tearing_control_v1 *(*swl_tearing_control_get_surface_impl)(
    struct wp_tearing_control_manager_v1 *manager,
    struct wl_surface *surface) =
        swl_tearing_control_get_surface_default;
static void (*swl_tearing_control_set_presentation_hint_impl)(
    struct wp_tearing_control_v1 *tearing_control,
    uint32_t hint) =
        swl_tearing_control_set_presentation_hint_default;
static void (*swl_tearing_control_destroy_impl)(
    struct wp_tearing_control_v1 *tearing_control) =
        swl_tearing_control_destroy_default;
static void (*swl_tearing_control_manager_destroy_impl)(
    struct wp_tearing_control_manager_v1 *manager) =
        swl_tearing_control_manager_destroy_default;

static struct wp_color_representation_surface_v1 *
    (*swl_color_representation_get_surface_impl)(
        struct wp_color_representation_manager_v1 *manager,
        struct wl_surface *surface) =
            swl_color_representation_get_surface_default;
static void (*swl_color_representation_set_alpha_mode_impl)(
    struct wp_color_representation_surface_v1 *surface,
    uint32_t alpha_mode) =
        swl_color_representation_set_alpha_mode_default;
static void (*swl_color_representation_set_coefficients_and_range_impl)(
    struct wp_color_representation_surface_v1 *surface,
    uint32_t coefficients,
    uint32_t range) =
        swl_color_representation_set_coefficients_and_range_default;
static void (*swl_color_representation_set_chroma_location_impl)(
    struct wp_color_representation_surface_v1 *surface,
    uint32_t chroma_location) =
        swl_color_representation_set_chroma_location_default;
static void (*swl_color_representation_surface_destroy_impl)(
    struct wp_color_representation_surface_v1 *surface) =
        swl_color_representation_surface_destroy_default;
static void (*swl_color_representation_manager_destroy_impl)(
    struct wp_color_representation_manager_v1 *manager) =
        swl_color_representation_manager_destroy_default;

static struct wp_color_management_surface_v1 *
    (*swl_color_manager_get_surface_impl)(
        struct wp_color_manager_v1 *manager,
        struct wl_surface *surface) =
            swl_color_manager_get_surface_default;
static struct wp_color_management_surface_feedback_v1 *
    (*swl_color_manager_get_surface_feedback_impl)(
        struct wp_color_manager_v1 *manager,
        struct wl_surface *surface) =
            swl_color_manager_get_surface_feedback_default;
static struct wp_image_description_v1 *
    (*swl_color_manager_get_image_description_impl)(
        struct wp_color_manager_v1 *manager,
        struct wp_image_description_reference_v1 *reference) =
            swl_color_manager_get_image_description_default;
static void (*swl_color_management_surface_set_image_description_impl)(
    struct wp_color_management_surface_v1 *surface,
    struct wp_image_description_v1 *image_description,
    uint32_t render_intent) =
        swl_color_management_surface_set_image_description_default;
static void (*swl_color_management_surface_unset_image_description_impl)(
    struct wp_color_management_surface_v1 *surface) =
        swl_color_management_surface_unset_image_description_default;
static void (*swl_color_management_surface_destroy_impl)(
    struct wp_color_management_surface_v1 *surface) =
        swl_color_management_surface_destroy_default;
static struct wp_image_description_v1 *
    (*swl_color_management_surface_feedback_get_preferred_impl)(
        struct wp_color_management_surface_feedback_v1 *feedback) =
            swl_color_management_surface_feedback_get_preferred_default;
static void (*swl_color_management_surface_feedback_destroy_impl)(
    struct wp_color_management_surface_feedback_v1 *feedback) =
        swl_color_management_surface_feedback_destroy_default;
static void (*swl_image_description_destroy_impl)(
    struct wp_image_description_v1 *image_description) =
        swl_image_description_destroy_default;
static void (*swl_color_manager_destroy_impl)(
    struct wp_color_manager_v1 *manager) =
        swl_color_manager_destroy_default;

static void swl_test_record_metadata_request(
    enum swl_test_metadata_request_kind kind,
    void *object,
    void *surface,
    void *reference,
    void *image_description,
    uint32_t value,
    uint32_t coefficients,
    uint32_t range,
    uint32_t render_intent)
{
    swl_test_metadata_request_latest.call_count += 1;
    swl_test_metadata_request_latest.kind = kind;
    swl_test_metadata_request_latest.object = object;
    swl_test_metadata_request_latest.surface = surface;
    swl_test_metadata_request_latest.reference = reference;
    swl_test_metadata_request_latest.image_description = image_description;
    swl_test_metadata_request_latest.value = value;
    swl_test_metadata_request_latest.coefficients = coefficients;
    swl_test_metadata_request_latest.range = range;
    swl_test_metadata_request_latest.render_intent = render_intent;
}

static void swl_test_record_metadata_destroy(
    enum swl_test_metadata_destroy_kind kind,
    void *object)
{
    swl_test_metadata_destroy_latest.call_count += 1;
    swl_test_metadata_destroy_latest.kind = kind;
    swl_test_metadata_destroy_latest.object = object;
}

static struct wp_content_type_v1 *swl_test_content_type_get_surface_record(
    struct wp_content_type_manager_v1 *manager,
    struct wl_surface *surface)
{
    swl_test_record_metadata_request(
        SWL_TEST_METADATA_CONTENT_TYPE_GET_SURFACE,
        manager,
        surface,
        NULL,
        NULL,
        0,
        0,
        0,
        0);
    return (struct wp_content_type_v1 *)0xC701;
}

static void swl_test_content_type_set_record(
    struct wp_content_type_v1 *content_type,
    uint32_t value)
{
    swl_test_record_metadata_request(
        SWL_TEST_METADATA_CONTENT_TYPE_SET,
        content_type,
        NULL,
        NULL,
        NULL,
        value,
        0,
        0,
        0);
}

static void swl_test_content_type_destroy_record(
    struct wp_content_type_v1 *content_type)
{
    swl_test_record_metadata_destroy(
        SWL_TEST_METADATA_DESTROY_CONTENT_TYPE, content_type);
}

static void swl_test_content_type_manager_destroy_record(
    struct wp_content_type_manager_v1 *manager)
{
    swl_test_record_metadata_destroy(
        SWL_TEST_METADATA_DESTROY_CONTENT_TYPE_MANAGER, manager);
}

static struct wp_alpha_modifier_surface_v1 *
swl_test_alpha_modifier_get_surface_record(
    struct wp_alpha_modifier_v1 *manager,
    struct wl_surface *surface)
{
    swl_test_record_metadata_request(
        SWL_TEST_METADATA_ALPHA_MODIFIER_GET_SURFACE,
        manager,
        surface,
        NULL,
        NULL,
        0,
        0,
        0,
        0);
    return (struct wp_alpha_modifier_surface_v1 *)0xC704;
}

static void swl_test_alpha_modifier_set_multiplier_record(
    struct wp_alpha_modifier_surface_v1 *surface,
    uint32_t factor)
{
    swl_test_record_metadata_request(
        SWL_TEST_METADATA_ALPHA_MODIFIER_SET_MULTIPLIER,
        surface,
        NULL,
        NULL,
        NULL,
        factor,
        0,
        0,
        0);
}

static void swl_test_alpha_modifier_surface_destroy_record(
    struct wp_alpha_modifier_surface_v1 *surface)
{
    swl_test_record_metadata_destroy(
        SWL_TEST_METADATA_DESTROY_ALPHA_MODIFIER_SURFACE, surface);
}

static void swl_test_alpha_modifier_manager_destroy_record(
    struct wp_alpha_modifier_v1 *manager)
{
    swl_test_record_metadata_destroy(
        SWL_TEST_METADATA_DESTROY_ALPHA_MODIFIER_MANAGER, manager);
}

static struct wp_tearing_control_v1 *
swl_test_tearing_control_get_surface_record(
    struct wp_tearing_control_manager_v1 *manager,
    struct wl_surface *surface)
{
    swl_test_record_metadata_request(
        SWL_TEST_METADATA_TEARING_CONTROL_GET_SURFACE,
        manager,
        surface,
        NULL,
        NULL,
        0,
        0,
        0,
        0);
    return (struct wp_tearing_control_v1 *)0xC705;
}

static void swl_test_tearing_control_set_presentation_hint_record(
    struct wp_tearing_control_v1 *tearing_control,
    uint32_t hint)
{
    swl_test_record_metadata_request(
        SWL_TEST_METADATA_TEARING_CONTROL_SET_PRESENTATION_HINT,
        tearing_control,
        NULL,
        NULL,
        NULL,
        hint,
        0,
        0,
        0);
}

static void swl_test_tearing_control_destroy_record(
    struct wp_tearing_control_v1 *tearing_control)
{
    swl_test_record_metadata_destroy(
        SWL_TEST_METADATA_DESTROY_TEARING_CONTROL, tearing_control);
}

static void swl_test_tearing_control_manager_destroy_record(
    struct wp_tearing_control_manager_v1 *manager)
{
    swl_test_record_metadata_destroy(
        SWL_TEST_METADATA_DESTROY_TEARING_CONTROL_MANAGER, manager);
}

static struct wp_color_representation_surface_v1 *
swl_test_color_representation_get_surface_record(
    struct wp_color_representation_manager_v1 *manager,
    struct wl_surface *surface)
{
    swl_test_record_metadata_request(
        SWL_TEST_METADATA_COLOR_REPRESENTATION_GET_SURFACE,
        manager,
        surface,
        NULL,
        NULL,
        0,
        0,
        0,
        0);
    return (struct wp_color_representation_surface_v1 *)0xC702;
}

static void swl_test_color_representation_set_alpha_mode_record(
    struct wp_color_representation_surface_v1 *surface,
    uint32_t alpha_mode)
{
    swl_test_record_metadata_request(
        SWL_TEST_METADATA_COLOR_REPRESENTATION_SET_ALPHA_MODE,
        surface,
        NULL,
        NULL,
        NULL,
        alpha_mode,
        0,
        0,
        0);
}

static void swl_test_color_representation_set_coefficients_and_range_record(
    struct wp_color_representation_surface_v1 *surface,
    uint32_t coefficients,
    uint32_t range)
{
    swl_test_record_metadata_request(
        SWL_TEST_METADATA_COLOR_REPRESENTATION_SET_COEFFICIENTS_AND_RANGE,
        surface,
        NULL,
        NULL,
        NULL,
        0,
        coefficients,
        range,
        0);
}

static void swl_test_color_representation_set_chroma_location_record(
    struct wp_color_representation_surface_v1 *surface,
    uint32_t chroma_location)
{
    swl_test_record_metadata_request(
        SWL_TEST_METADATA_COLOR_REPRESENTATION_SET_CHROMA_LOCATION,
        surface,
        NULL,
        NULL,
        NULL,
        chroma_location,
        0,
        0,
        0);
}

static void swl_test_color_representation_surface_destroy_record(
    struct wp_color_representation_surface_v1 *surface)
{
    swl_test_record_metadata_destroy(
        SWL_TEST_METADATA_DESTROY_COLOR_REPRESENTATION_SURFACE, surface);
}

static void swl_test_color_representation_manager_destroy_record(
    struct wp_color_representation_manager_v1 *manager)
{
    swl_test_record_metadata_destroy(
        SWL_TEST_METADATA_DESTROY_COLOR_REPRESENTATION_MANAGER, manager);
}

static struct wp_color_management_surface_v1 *
swl_test_color_manager_get_surface_record(
    struct wp_color_manager_v1 *manager,
    struct wl_surface *surface)
{
    swl_test_record_metadata_request(
        SWL_TEST_METADATA_COLOR_MANAGER_GET_SURFACE,
        manager,
        surface,
        NULL,
        NULL,
        0,
        0,
        0,
        0);
    return (struct wp_color_management_surface_v1 *)0xC706;
}

static struct wp_color_management_surface_feedback_v1 *
swl_test_color_manager_get_surface_feedback_record(
    struct wp_color_manager_v1 *manager,
    struct wl_surface *surface)
{
    swl_test_record_metadata_request(
        SWL_TEST_METADATA_COLOR_MANAGER_GET_SURFACE_FEEDBACK,
        manager,
        surface,
        NULL,
        NULL,
        0,
        0,
        0,
        0);
    return (struct wp_color_management_surface_feedback_v1 *)0xC707;
}

static struct wp_image_description_v1 *
swl_test_color_manager_get_image_description_record(
    struct wp_color_manager_v1 *manager,
    struct wp_image_description_reference_v1 *reference)
{
    swl_test_record_metadata_request(
        SWL_TEST_METADATA_COLOR_MANAGER_GET_IMAGE_DESCRIPTION,
        manager,
        NULL,
        reference,
        NULL,
        0,
        0,
        0,
        0);
    return (struct wp_image_description_v1 *)0xC703;
}

static struct wp_image_description_v1 *
swl_test_color_management_surface_feedback_get_preferred_record(
    struct wp_color_management_surface_feedback_v1 *feedback)
{
    swl_test_record_metadata_request(
        SWL_TEST_METADATA_COLOR_FEEDBACK_GET_PREFERRED,
        feedback,
        NULL,
        NULL,
        NULL,
        0,
        0,
        0,
        0);
    return (struct wp_image_description_v1 *)0xC708;
}

static void swl_test_color_management_surface_set_image_description_record(
    struct wp_color_management_surface_v1 *surface,
    struct wp_image_description_v1 *image_description,
    uint32_t render_intent)
{
    swl_test_record_metadata_request(
        SWL_TEST_METADATA_COLOR_SURFACE_SET_IMAGE_DESCRIPTION,
        surface,
        NULL,
        NULL,
        image_description,
        0,
        0,
        0,
        render_intent);
}

static void swl_test_color_management_surface_unset_image_description_record(
    struct wp_color_management_surface_v1 *surface)
{
    swl_test_record_metadata_request(
        SWL_TEST_METADATA_COLOR_SURFACE_UNSET_IMAGE_DESCRIPTION,
        surface,
        NULL,
        NULL,
        NULL,
        0,
        0,
        0,
        0);
}

static void swl_test_color_management_surface_destroy_record(
    struct wp_color_management_surface_v1 *surface)
{
    swl_test_record_metadata_destroy(
        SWL_TEST_METADATA_DESTROY_COLOR_MANAGEMENT_SURFACE, surface);
}

static void swl_test_color_management_surface_feedback_destroy_record(
    struct wp_color_management_surface_feedback_v1 *feedback)
{
    swl_test_record_metadata_destroy(
        SWL_TEST_METADATA_DESTROY_COLOR_MANAGEMENT_SURFACE_FEEDBACK, feedback);
}

static void swl_test_image_description_destroy_record(
    struct wp_image_description_v1 *image_description)
{
    swl_test_record_metadata_destroy(
        SWL_TEST_METADATA_DESTROY_IMAGE_DESCRIPTION, image_description);
}

static void swl_test_color_manager_destroy_record(
    struct wp_color_manager_v1 *manager)
{
    swl_test_record_metadata_destroy(
        SWL_TEST_METADATA_DESTROY_COLOR_MANAGER, manager);
}
#else
#define swl_content_type_get_surface_impl \
    wp_content_type_manager_v1_get_surface_content_type
#define swl_content_type_set_impl wp_content_type_v1_set_content_type
#define swl_content_type_destroy_impl wp_content_type_v1_destroy
#define swl_content_type_manager_destroy_impl wp_content_type_manager_v1_destroy
#define swl_alpha_modifier_get_surface_impl wp_alpha_modifier_v1_get_surface
#define swl_alpha_modifier_set_multiplier_impl \
    wp_alpha_modifier_surface_v1_set_multiplier
#define swl_alpha_modifier_surface_destroy_impl \
    wp_alpha_modifier_surface_v1_destroy
#define swl_alpha_modifier_manager_destroy_impl wp_alpha_modifier_v1_destroy
#define swl_tearing_control_get_surface_impl \
    wp_tearing_control_manager_v1_get_tearing_control
#define swl_tearing_control_set_presentation_hint_impl \
    wp_tearing_control_v1_set_presentation_hint
#define swl_tearing_control_destroy_impl wp_tearing_control_v1_destroy
#define swl_tearing_control_manager_destroy_impl \
    wp_tearing_control_manager_v1_destroy
#define swl_color_representation_get_surface_impl \
    wp_color_representation_manager_v1_get_surface
#define swl_color_representation_set_alpha_mode_impl \
    wp_color_representation_surface_v1_set_alpha_mode
#define swl_color_representation_set_coefficients_and_range_impl \
    wp_color_representation_surface_v1_set_coefficients_and_range
#define swl_color_representation_set_chroma_location_impl \
    wp_color_representation_surface_v1_set_chroma_location
#define swl_color_representation_surface_destroy_impl \
    wp_color_representation_surface_v1_destroy
#define swl_color_representation_manager_destroy_impl \
    wp_color_representation_manager_v1_destroy
#define swl_color_manager_get_surface_impl wp_color_manager_v1_get_surface
#define swl_color_manager_get_surface_feedback_impl \
    wp_color_manager_v1_get_surface_feedback
#define swl_color_manager_get_image_description_impl \
    wp_color_manager_v1_get_image_description
#define swl_color_management_surface_feedback_get_preferred_impl \
    wp_color_management_surface_feedback_v1_get_preferred
#define swl_color_management_surface_set_image_description_impl \
    wp_color_management_surface_v1_set_image_description
#define swl_color_management_surface_unset_image_description_impl \
    wp_color_management_surface_v1_unset_image_description
#define swl_color_management_surface_destroy_impl \
    wp_color_management_surface_v1_destroy
#define swl_color_management_surface_feedback_destroy_impl \
    wp_color_management_surface_feedback_v1_destroy
#define swl_image_description_destroy_impl wp_image_description_v1_destroy
#define swl_color_manager_destroy_impl wp_color_manager_v1_destroy
#endif

struct wp_content_type_v1 *swl_wp_content_type_manager_v1_get_surface_content_type(
    struct wp_content_type_manager_v1 *manager,
    struct wl_surface *surface)
{
    return swl_content_type_get_surface_impl(manager, surface);
}

void swl_wp_content_type_v1_set_content_type(
    struct wp_content_type_v1 *content_type,
    uint32_t value)
{
    swl_content_type_set_impl(content_type, value);
}

void swl_wp_content_type_v1_destroy(struct wp_content_type_v1 *content_type)
{
    swl_content_type_destroy_impl(content_type);
}

void swl_wp_content_type_manager_v1_destroy(
    struct wp_content_type_manager_v1 *manager)
{
    swl_content_type_manager_destroy_impl(manager);
}

struct wp_alpha_modifier_surface_v1 *swl_wp_alpha_modifier_v1_get_surface(
    struct wp_alpha_modifier_v1 *manager,
    struct wl_surface *surface)
{
    return swl_alpha_modifier_get_surface_impl(manager, surface);
}

void swl_wp_alpha_modifier_surface_v1_set_multiplier(
    struct wp_alpha_modifier_surface_v1 *surface,
    uint32_t factor)
{
    swl_alpha_modifier_set_multiplier_impl(surface, factor);
}

void swl_wp_alpha_modifier_surface_v1_destroy(
    struct wp_alpha_modifier_surface_v1 *surface)
{
    swl_alpha_modifier_surface_destroy_impl(surface);
}

void swl_wp_alpha_modifier_v1_destroy(struct wp_alpha_modifier_v1 *manager)
{
    swl_alpha_modifier_manager_destroy_impl(manager);
}

struct wp_tearing_control_v1 *
swl_wp_tearing_control_manager_v1_get_tearing_control(
    struct wp_tearing_control_manager_v1 *manager,
    struct wl_surface *surface)
{
    return swl_tearing_control_get_surface_impl(manager, surface);
}

void swl_wp_tearing_control_v1_set_presentation_hint(
    struct wp_tearing_control_v1 *tearing_control,
    uint32_t hint)
{
    swl_tearing_control_set_presentation_hint_impl(tearing_control, hint);
}

void swl_wp_tearing_control_v1_destroy(
    struct wp_tearing_control_v1 *tearing_control)
{
    swl_tearing_control_destroy_impl(tearing_control);
}

void swl_wp_tearing_control_manager_v1_destroy(
    struct wp_tearing_control_manager_v1 *manager)
{
    swl_tearing_control_manager_destroy_impl(manager);
}

struct wp_color_representation_surface_v1 *
swl_wp_color_representation_manager_v1_get_surface(
    struct wp_color_representation_manager_v1 *manager,
    struct wl_surface *surface)
{
    return swl_color_representation_get_surface_impl(manager, surface);
}

void swl_wp_color_representation_surface_v1_set_alpha_mode(
    struct wp_color_representation_surface_v1 *surface,
    uint32_t alpha_mode)
{
    swl_color_representation_set_alpha_mode_impl(surface, alpha_mode);
}

void swl_wp_color_representation_surface_v1_set_coefficients_and_range(
    struct wp_color_representation_surface_v1 *surface,
    uint32_t coefficients,
    uint32_t range)
{
    swl_color_representation_set_coefficients_and_range_impl(
        surface, coefficients, range);
}

void swl_wp_color_representation_surface_v1_set_chroma_location(
    struct wp_color_representation_surface_v1 *surface,
    uint32_t chroma_location)
{
    swl_color_representation_set_chroma_location_impl(surface, chroma_location);
}

void swl_wp_color_representation_surface_v1_destroy(
    struct wp_color_representation_surface_v1 *surface)
{
    swl_color_representation_surface_destroy_impl(surface);
}

void swl_wp_color_representation_manager_v1_destroy(
    struct wp_color_representation_manager_v1 *manager)
{
    swl_color_representation_manager_destroy_impl(manager);
}

struct wp_color_management_surface_v1 *swl_wp_color_manager_v1_get_surface(
    struct wp_color_manager_v1 *manager,
    struct wl_surface *surface)
{
    return swl_color_manager_get_surface_impl(manager, surface);
}

struct wp_color_management_surface_feedback_v1 *
swl_wp_color_manager_v1_get_surface_feedback(
    struct wp_color_manager_v1 *manager,
    struct wl_surface *surface)
{
    return swl_color_manager_get_surface_feedback_impl(manager, surface);
}

struct wp_image_description_v1 *swl_wp_color_manager_v1_get_image_description(
    struct wp_color_manager_v1 *manager,
    struct wp_image_description_reference_v1 *reference)
{
    return swl_color_manager_get_image_description_impl(manager, reference);
}

void swl_wp_color_management_surface_v1_set_image_description(
    struct wp_color_management_surface_v1 *surface,
    struct wp_image_description_v1 *image_description,
    uint32_t render_intent)
{
    swl_color_management_surface_set_image_description_impl(
        surface, image_description, render_intent);
}

void swl_wp_color_management_surface_v1_unset_image_description(
    struct wp_color_management_surface_v1 *surface)
{
    swl_color_management_surface_unset_image_description_impl(surface);
}

struct wp_image_description_v1 *
swl_wp_color_management_surface_feedback_v1_get_preferred(
    struct wp_color_management_surface_feedback_v1 *feedback)
{
    return swl_color_management_surface_feedback_get_preferred_impl(feedback);
}

void swl_wp_color_management_surface_v1_destroy(
    struct wp_color_management_surface_v1 *surface)
{
    swl_color_management_surface_destroy_impl(surface);
}

void swl_wp_color_management_surface_feedback_v1_destroy(
    struct wp_color_management_surface_feedback_v1 *feedback)
{
    swl_color_management_surface_feedback_destroy_impl(feedback);
}

void swl_wp_image_description_v1_destroy(
    struct wp_image_description_v1 *image_description)
{
    swl_image_description_destroy_impl(image_description);
}

void swl_wp_color_manager_v1_destroy(struct wp_color_manager_v1 *manager)
{
    swl_color_manager_destroy_impl(manager);
}

#ifdef SWL_ENABLE_TESTING
void swl_test_metadata_request_recording_begin(void)
{
    swl_test_metadata_request_latest =
        (struct swl_test_metadata_request_record){0};
    swl_test_metadata_destroy_latest =
        (struct swl_test_metadata_destroy_record){0};
    swl_content_type_get_surface_impl = swl_test_content_type_get_surface_record;
    swl_content_type_set_impl = swl_test_content_type_set_record;
    swl_content_type_destroy_impl = swl_test_content_type_destroy_record;
    swl_content_type_manager_destroy_impl =
        swl_test_content_type_manager_destroy_record;
    swl_alpha_modifier_get_surface_impl =
        swl_test_alpha_modifier_get_surface_record;
    swl_alpha_modifier_set_multiplier_impl =
        swl_test_alpha_modifier_set_multiplier_record;
    swl_alpha_modifier_surface_destroy_impl =
        swl_test_alpha_modifier_surface_destroy_record;
    swl_alpha_modifier_manager_destroy_impl =
        swl_test_alpha_modifier_manager_destroy_record;
    swl_tearing_control_get_surface_impl =
        swl_test_tearing_control_get_surface_record;
    swl_tearing_control_set_presentation_hint_impl =
        swl_test_tearing_control_set_presentation_hint_record;
    swl_tearing_control_destroy_impl = swl_test_tearing_control_destroy_record;
    swl_tearing_control_manager_destroy_impl =
        swl_test_tearing_control_manager_destroy_record;
    swl_color_representation_get_surface_impl =
        swl_test_color_representation_get_surface_record;
    swl_color_representation_set_alpha_mode_impl =
        swl_test_color_representation_set_alpha_mode_record;
    swl_color_representation_set_coefficients_and_range_impl =
        swl_test_color_representation_set_coefficients_and_range_record;
    swl_color_representation_set_chroma_location_impl =
        swl_test_color_representation_set_chroma_location_record;
    swl_color_representation_surface_destroy_impl =
        swl_test_color_representation_surface_destroy_record;
    swl_color_representation_manager_destroy_impl =
        swl_test_color_representation_manager_destroy_record;
    swl_color_manager_get_surface_impl = swl_test_color_manager_get_surface_record;
    swl_color_manager_get_surface_feedback_impl =
        swl_test_color_manager_get_surface_feedback_record;
    swl_color_manager_get_image_description_impl =
        swl_test_color_manager_get_image_description_record;
    swl_color_management_surface_feedback_get_preferred_impl =
        swl_test_color_management_surface_feedback_get_preferred_record;
    swl_color_management_surface_set_image_description_impl =
        swl_test_color_management_surface_set_image_description_record;
    swl_color_management_surface_unset_image_description_impl =
        swl_test_color_management_surface_unset_image_description_record;
    swl_color_management_surface_destroy_impl =
        swl_test_color_management_surface_destroy_record;
    swl_color_management_surface_feedback_destroy_impl =
        swl_test_color_management_surface_feedback_destroy_record;
    swl_image_description_destroy_impl = swl_test_image_description_destroy_record;
    swl_color_manager_destroy_impl = swl_test_color_manager_destroy_record;
}

void swl_test_metadata_request_recording_end(void)
{
    swl_content_type_get_surface_impl = swl_content_type_get_surface_default;
    swl_content_type_set_impl = swl_content_type_set_default;
    swl_content_type_destroy_impl = swl_content_type_destroy_default;
    swl_content_type_manager_destroy_impl =
        swl_content_type_manager_destroy_default;
    swl_alpha_modifier_get_surface_impl = swl_alpha_modifier_get_surface_default;
    swl_alpha_modifier_set_multiplier_impl =
        swl_alpha_modifier_set_multiplier_default;
    swl_alpha_modifier_surface_destroy_impl =
        swl_alpha_modifier_surface_destroy_default;
    swl_alpha_modifier_manager_destroy_impl =
        swl_alpha_modifier_manager_destroy_default;
    swl_tearing_control_get_surface_impl =
        swl_tearing_control_get_surface_default;
    swl_tearing_control_set_presentation_hint_impl =
        swl_tearing_control_set_presentation_hint_default;
    swl_tearing_control_destroy_impl = swl_tearing_control_destroy_default;
    swl_tearing_control_manager_destroy_impl =
        swl_tearing_control_manager_destroy_default;
    swl_color_representation_get_surface_impl =
        swl_color_representation_get_surface_default;
    swl_color_representation_set_alpha_mode_impl =
        swl_color_representation_set_alpha_mode_default;
    swl_color_representation_set_coefficients_and_range_impl =
        swl_color_representation_set_coefficients_and_range_default;
    swl_color_representation_set_chroma_location_impl =
        swl_color_representation_set_chroma_location_default;
    swl_color_representation_surface_destroy_impl =
        swl_color_representation_surface_destroy_default;
    swl_color_representation_manager_destroy_impl =
        swl_color_representation_manager_destroy_default;
    swl_color_manager_get_surface_impl = swl_color_manager_get_surface_default;
    swl_color_manager_get_surface_feedback_impl =
        swl_color_manager_get_surface_feedback_default;
    swl_color_manager_get_image_description_impl =
        swl_color_manager_get_image_description_default;
    swl_color_management_surface_feedback_get_preferred_impl =
        swl_color_management_surface_feedback_get_preferred_default;
    swl_color_management_surface_set_image_description_impl =
        swl_color_management_surface_set_image_description_default;
    swl_color_management_surface_unset_image_description_impl =
        swl_color_management_surface_unset_image_description_default;
    swl_color_management_surface_destroy_impl =
        swl_color_management_surface_destroy_default;
    swl_color_management_surface_feedback_destroy_impl =
        swl_color_management_surface_feedback_destroy_default;
    swl_image_description_destroy_impl = swl_image_description_destroy_default;
    swl_color_manager_destroy_impl = swl_color_manager_destroy_default;
}

struct swl_test_metadata_request_record swl_test_metadata_request_record(void)
{
    return swl_test_metadata_request_latest;
}

struct swl_test_metadata_destroy_record swl_test_metadata_destroy_record(void)
{
    return swl_test_metadata_destroy_latest;
}
#endif
