#if !os(Linux)
    #error("WaylandClientKit currently supports Linux only.")
#endif

#if !canImport(Glibc)
    #error("WaylandClientKit supports glibc Linux only; Musl/static SDK builds are unsupported.")
#endif
