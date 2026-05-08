@unsafe
package struct RawBorrowedBuffer: Equatable {
    private let borrowedPointer: OpaquePointer

    package var pointer: OpaquePointer {
        unsafe borrowedPointer
    }

    package init(pointer bufferPointer: OpaquePointer) {
        unsafe borrowedPointer = bufferPointer
    }
}
