#ifndef SWIFT_WAYLAND_UNSAFE_SHIM_H
#define SWIFT_WAYLAND_UNSAFE_SHIM_H

#define SWL_SWIFT_UNSAFE __attribute__((swift_attr("@unsafe")))

int swl_eventfd(unsigned int initval, int flags) SWL_SWIFT_UNSAFE;
int swl_efd_cloexec(void) SWL_SWIFT_UNSAFE;
int swl_efd_nonblock(void) SWL_SWIFT_UNSAFE;

#endif
