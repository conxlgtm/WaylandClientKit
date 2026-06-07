@safe
// SAFETY: RawSurfaceBuffer is a borrowed wl_buffer wrapper passed only through
// package-internal owner-thread commit helpers. Ownership stays with the typed buffer
// object that created it.
// swiftlint:disable:next attributes
package struct RawSurfaceBuffer: @unchecked Sendable {
    @safe package let pointer: OpaquePointer

    @safe
    package init(pointer bufferPointer: OpaquePointer) {
        unsafe pointer = bufferPointer
    }
}

extension RawBuffer {
    @safe package var surfaceBuffer: RawSurfaceBuffer {
        RawSurfaceBuffer(pointer: pointer)
    }
}

extension RawLinuxDmabufBuffer {
    @safe package var surfaceBuffer: RawSurfaceBuffer {
        RawSurfaceBuffer(pointer: pointer)
    }
}
