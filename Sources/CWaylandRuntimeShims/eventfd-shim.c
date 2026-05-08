#include "swift-wayland-runtime-shims.h"

#include <sys/eventfd.h>

int swl_eventfd(unsigned int initval, int flags)
{
    return eventfd(initval, flags);
}

int swl_efd_cloexec(void)
{
    return EFD_CLOEXEC;
}

int swl_efd_nonblock(void)
{
    return EFD_NONBLOCK;
}
