#include "wayland-client-kit-shims.h"
#include "generated/staging/fractional-scale/fractional-scale-v1-client-protocol.h"
#include "generated/stable/viewporter/viewporter-client-protocol.h"

#ifdef SWL_ENABLE_TESTING
static struct swl_test_viewport_destination_record
    swl_test_viewport_destination_latest;
static struct swl_test_scale_destroy_record swl_test_scale_destroy_latest;

static void swl_wp_viewport_set_destination_default(
    struct wp_viewport *viewport,
    int32_t width,
    int32_t height)
{
    wp_viewport_set_destination(viewport, width, height);
}

static void (*swl_wp_viewport_set_destination_impl)(
    struct wp_viewport *viewport,
    int32_t width,
    int32_t height) = swl_wp_viewport_set_destination_default;

static void swl_test_record_wp_viewport_set_destination(
    struct wp_viewport *viewport,
    int32_t width,
    int32_t height)
{
    swl_test_viewport_destination_latest.call_count += 1;
    swl_test_viewport_destination_latest.viewport = viewport;
    swl_test_viewport_destination_latest.width = width;
    swl_test_viewport_destination_latest.height = height;
}

#define SWL_DEFINE_DESTROY_WRAPPER(name, type, destroy_kind, real_destroy)       \
    static void name##_default(type *object) { real_destroy(object); }           \
    static void (*name##_impl)(type *object) = name##_default;                   \
    static void name##_record(type *object)                                      \
    {                                                                            \
        swl_test_scale_destroy_latest.call_count += 1;                           \
        swl_test_scale_destroy_latest.kind = destroy_kind;                       \
        swl_test_scale_destroy_latest.object = object;                           \
    }

SWL_DEFINE_DESTROY_WRAPPER(
    swl_wp_viewport_destroy,
    struct wp_viewport,
    SWL_TEST_SCALE_DESTROY_VIEWPORT,
    wp_viewport_destroy)
SWL_DEFINE_DESTROY_WRAPPER(
    swl_wp_viewporter_destroy,
    struct wp_viewporter,
    SWL_TEST_SCALE_DESTROY_VIEWPORTER,
    wp_viewporter_destroy)
SWL_DEFINE_DESTROY_WRAPPER(
    swl_wp_fractional_scale_v1_destroy,
    struct wp_fractional_scale_v1,
    SWL_TEST_SCALE_DESTROY_FRACTIONAL_SCALE,
    wp_fractional_scale_v1_destroy)
SWL_DEFINE_DESTROY_WRAPPER(
    swl_wp_fractional_scale_manager_v1_destroy,
    struct wp_fractional_scale_manager_v1,
    SWL_TEST_SCALE_DESTROY_FRACTIONAL_SCALE_MANAGER,
    wp_fractional_scale_manager_v1_destroy)
#else
#define swl_wp_viewport_set_destination_impl wp_viewport_set_destination
#define swl_wp_viewport_destroy_impl wp_viewport_destroy
#define swl_wp_viewporter_destroy_impl wp_viewporter_destroy
#define swl_wp_fractional_scale_v1_destroy_impl wp_fractional_scale_v1_destroy
#define swl_wp_fractional_scale_manager_v1_destroy_impl \
    wp_fractional_scale_manager_v1_destroy
#endif

struct wp_viewport *swl_wp_viewporter_get_viewport(
    struct wp_viewporter *viewporter,
    struct wl_surface *surface)
{
    return wp_viewporter_get_viewport(viewporter, surface);
}

void swl_wp_viewport_set_destination(
    struct wp_viewport *viewport,
    int32_t width,
    int32_t height)
{
    swl_wp_viewport_set_destination_impl(viewport, width, height);
}

void swl_wp_viewport_destroy(struct wp_viewport *viewport)
{
    swl_wp_viewport_destroy_impl(viewport);
}

void swl_wp_viewporter_destroy(struct wp_viewporter *viewporter)
{
    swl_wp_viewporter_destroy_impl(viewporter);
}

struct wp_fractional_scale_v1 *swl_wp_fractional_scale_manager_v1_get_fractional_scale(
    struct wp_fractional_scale_manager_v1 *manager,
    struct wl_surface *surface)
{
    return wp_fractional_scale_manager_v1_get_fractional_scale(manager, surface);
}

void swl_wp_fractional_scale_v1_destroy(struct wp_fractional_scale_v1 *fractional_scale)
{
    swl_wp_fractional_scale_v1_destroy_impl(fractional_scale);
}

void swl_wp_fractional_scale_manager_v1_destroy(
    struct wp_fractional_scale_manager_v1 *manager)
{
    swl_wp_fractional_scale_manager_v1_destroy_impl(manager);
}

#ifdef SWL_ENABLE_TESTING
void swl_test_scale_request_recording_begin(void)
{
    swl_test_viewport_destination_latest =
        (struct swl_test_viewport_destination_record){0};
    swl_test_scale_destroy_latest =
        (struct swl_test_scale_destroy_record){
            .kind = SWL_TEST_SCALE_DESTROY_NONE,
        };

    swl_wp_viewport_set_destination_impl =
        swl_test_record_wp_viewport_set_destination;
    swl_wp_viewport_destroy_impl = swl_wp_viewport_destroy_record;
    swl_wp_viewporter_destroy_impl = swl_wp_viewporter_destroy_record;
    swl_wp_fractional_scale_v1_destroy_impl =
        swl_wp_fractional_scale_v1_destroy_record;
    swl_wp_fractional_scale_manager_v1_destroy_impl =
        swl_wp_fractional_scale_manager_v1_destroy_record;
}

void swl_test_scale_request_recording_end(void)
{
    swl_wp_viewport_set_destination_impl =
        swl_wp_viewport_set_destination_default;
    swl_wp_viewport_destroy_impl = swl_wp_viewport_destroy_default;
    swl_wp_viewporter_destroy_impl = swl_wp_viewporter_destroy_default;
    swl_wp_fractional_scale_v1_destroy_impl =
        swl_wp_fractional_scale_v1_destroy_default;
    swl_wp_fractional_scale_manager_v1_destroy_impl =
        swl_wp_fractional_scale_manager_v1_destroy_default;
}

struct swl_test_viewport_destination_record
swl_test_scale_viewport_destination_record(void)
{
    return swl_test_viewport_destination_latest;
}

struct swl_test_scale_destroy_record swl_test_scale_destroy_record(void)
{
    return swl_test_scale_destroy_latest;
}
#endif
