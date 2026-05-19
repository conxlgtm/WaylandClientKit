#include "swift-wayland-shims.h"
#include "generated/stable/presentation-time/presentation-time-client-protocol.h"

#ifdef SWL_ENABLE_TESTING
static struct swl_test_presentation_request_record
    swl_test_presentation_request_latest;

static struct wp_presentation_feedback *swl_presentation_feedback_default(
    struct wp_presentation *presentation,
    struct wl_surface *surface)
{
    return wp_presentation_feedback(presentation, surface);
}

static void swl_presentation_destroy_default(
    struct wp_presentation *presentation)
{
    wp_presentation_destroy(presentation);
}

static void swl_presentation_feedback_destroy_default(
    struct wp_presentation_feedback *feedback)
{
    wp_presentation_feedback_destroy(feedback);
}

static struct wp_presentation_feedback *(*swl_presentation_feedback_impl)(
    struct wp_presentation *presentation,
    struct wl_surface *surface) =
        swl_presentation_feedback_default;
static void (*swl_presentation_destroy_impl)(
    struct wp_presentation *presentation) =
        swl_presentation_destroy_default;
static void (*swl_presentation_feedback_destroy_impl)(
    struct wp_presentation_feedback *feedback) =
        swl_presentation_feedback_destroy_default;

static void swl_test_record_presentation_request(
    enum swl_test_presentation_request_kind kind,
    void *object,
    void *surface,
    void *feedback)
{
    swl_test_presentation_request_latest.call_count += 1;
    swl_test_presentation_request_latest.kind = kind;
    swl_test_presentation_request_latest.object = object;
    swl_test_presentation_request_latest.surface = surface;
    swl_test_presentation_request_latest.feedback = feedback;
}

static struct wp_presentation_feedback *swl_test_presentation_feedback_record(
    struct wp_presentation *presentation,
    struct wl_surface *surface)
{
    struct wp_presentation_feedback *feedback =
        (struct wp_presentation_feedback *)0xA601;
    swl_test_record_presentation_request(
        SWL_TEST_PRESENTATION_FEEDBACK, presentation, surface, feedback);
    return feedback;
}

static void swl_test_presentation_destroy_record(
    struct wp_presentation *presentation)
{
    swl_test_record_presentation_request(
        SWL_TEST_PRESENTATION_DESTROY, presentation, NULL, NULL);
}

static void swl_test_presentation_feedback_destroy_record(
    struct wp_presentation_feedback *feedback)
{
    swl_test_record_presentation_request(
        SWL_TEST_PRESENTATION_FEEDBACK_DESTROY, feedback, NULL, feedback);
}
#else
#define swl_presentation_feedback_impl wp_presentation_feedback
#define swl_presentation_destroy_impl wp_presentation_destroy
#define swl_presentation_feedback_destroy_impl wp_presentation_feedback_destroy
#endif

struct wp_presentation_feedback *swl_wp_presentation_feedback(
    struct wp_presentation *presentation,
    struct wl_surface *surface)
{
    return swl_presentation_feedback_impl(presentation, surface);
}

void swl_wp_presentation_destroy(struct wp_presentation *presentation)
{
    swl_presentation_destroy_impl(presentation);
}

void swl_wp_presentation_feedback_destroy(
    struct wp_presentation_feedback *feedback)
{
    swl_presentation_feedback_destroy_impl(feedback);
}

#ifdef SWL_ENABLE_TESTING
void swl_test_presentation_request_recording_begin(void)
{
    swl_test_presentation_request_latest =
        (struct swl_test_presentation_request_record){0};
    swl_presentation_feedback_impl = swl_test_presentation_feedback_record;
    swl_presentation_destroy_impl = swl_test_presentation_destroy_record;
    swl_presentation_feedback_destroy_impl =
        swl_test_presentation_feedback_destroy_record;
}

void swl_test_presentation_request_recording_end(void)
{
    swl_presentation_feedback_impl = swl_presentation_feedback_default;
    swl_presentation_destroy_impl = swl_presentation_destroy_default;
    swl_presentation_feedback_destroy_impl =
        swl_presentation_feedback_destroy_default;
}

struct swl_test_presentation_request_record
swl_test_presentation_request_record(void)
{
    return swl_test_presentation_request_latest;
}
#endif
