@safe
package struct RawSurfaceBuffer {
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
