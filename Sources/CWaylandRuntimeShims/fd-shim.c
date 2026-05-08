#include "swift-wayland-runtime-shims.h"

#include <errno.h>
#include <pthread.h>
#include <signal.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

#ifndef MFD_CLOEXEC
#define MFD_CLOEXEC 0x0001U
#endif

int swl_memfd_create(const char *name, unsigned int flags)
{
    return memfd_create(name, flags);
}

unsigned int swl_mfd_cloexec(void)
{
    return MFD_CLOEXEC;
}

ssize_t swl_write_no_sigpipe(int fd, const void *buffer, size_t count)
{
    sigset_t signal_set;
    sigset_t original_signal_set;
    sigset_t pending_signal_set;
    int signal_state_changed = 0;
    int consume_generated_sigpipe = 0;

    if (sigemptyset(&signal_set) == 0
        && sigaddset(&signal_set, SIGPIPE) == 0
        && pthread_sigmask(SIG_BLOCK, &signal_set, &original_signal_set) == 0) {
        signal_state_changed = 1;

        if (sigpending(&pending_signal_set) == 0) {
            consume_generated_sigpipe = sigismember(&pending_signal_set, SIGPIPE) == 0;
        }
    }

    ssize_t result;
    do {
        result = write(fd, buffer, count);
    } while (result < 0 && errno == EINTR);

    int saved_errno = errno;

    if (result < 0 && saved_errno == EPIPE && consume_generated_sigpipe) {
        struct timespec timeout = {0, 0};
        while (sigtimedwait(&signal_set, NULL, &timeout) < 0 && errno == EINTR) {
        }
    }

    if (signal_state_changed) {
        pthread_sigmask(SIG_SETMASK, &original_signal_set, NULL);
    }

    errno = saved_errno;
    return result;
}
