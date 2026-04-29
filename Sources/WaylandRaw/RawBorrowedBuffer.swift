package struct RawBorrowedBuffer: Equatable {
    package let pointer: OpaquePointer

    package init(pointer bufferPointer: OpaquePointer) {
        pointer = bufferPointer
    }
}
