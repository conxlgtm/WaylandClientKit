@safe
package struct RawBorrowedBuffer: Equatable {
    @safe private let borrowedPointer: OpaquePointer

    @safe package var pointer: OpaquePointer {
        borrowedPointer
    }

    @safe
    package init(pointer bufferPointer: OpaquePointer) {
        unsafe borrowedPointer = bufferPointer
    }

    @safe
    package static func == (lhs: RawBorrowedBuffer, rhs: RawBorrowedBuffer) -> Bool {
        lhs.borrowedPointer == rhs.borrowedPointer
    }
}
