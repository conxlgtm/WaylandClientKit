#ifndef SWIFT_WAYLAND_RUNTIME_SHIMS_H
#define SWIFT_WAYLAND_RUNTIME_SHIMS_H

#ifndef __linux__
#error "SwiftWayland currently supports Linux only."
#endif

#define SWL_SWIFT_UNSAFE __attribute__((swift_attr("@unsafe")))

int swl_eventfd(unsigned int initval, int flags) SWL_SWIFT_UNSAFE;
int swl_efd_cloexec(void) SWL_SWIFT_UNSAFE;
int swl_efd_nonblock(void) SWL_SWIFT_UNSAFE;

#endif
