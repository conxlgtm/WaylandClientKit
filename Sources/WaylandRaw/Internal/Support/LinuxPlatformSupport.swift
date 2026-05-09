#if !os(Linux)
    #error("SwiftWayland currently supports Linux only.")
#endif

#if !canImport(Glibc)
    #error("SwiftWayland supports glibc Linux only; Musl/static SDK builds are unsupported.")
#endif
