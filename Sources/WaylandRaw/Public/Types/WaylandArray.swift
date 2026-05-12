import CWaylandProtocols

enum WaylandArray {
    @safe
    static func bytes(from array: UnsafeMutablePointer<wl_array>?) -> [UInt8] {
        guard
            let array = unsafe array,
            let data = unsafe array.pointee.data,
            unsafe array.pointee.size > 0
        else {
            return []
        }

        let byteCount = unsafe Int(array.pointee.size)
        let bytes = unsafe UnsafeRawBufferPointer(start: data, count: byteCount)
        return unsafe Array(bytes)
    }

    @safe
    static func uint16Values(from array: UnsafeMutablePointer<wl_array>?)
        throws(RuntimeError) -> [UInt16]
    {
        let bytes = bytes(from: array)
        guard !bytes.isEmpty else { return [] }

        let elementSize = MemoryLayout<UInt16>.stride
        guard bytes.count.isMultiple(of: elementSize) else {
            throw RuntimeError.invalidWaylandArrayByteCount(
                byteCount: bytes.count,
                elementSize: elementSize
            )
        }

        return unsafe bytes.withUnsafeBytes { buffer in
            stride(from: 0, to: bytes.count, by: elementSize).map { offset in
                unsafe buffer.loadUnaligned(fromByteOffset: offset, as: UInt16.self)
            }
        }
    }

    @safe
    static func uint32Values(from array: UnsafeMutablePointer<wl_array>?)
        throws(RuntimeError) -> [UInt32]
    {
        guard
            let array = unsafe array,
            let data = unsafe array.pointee.data,
            unsafe array.pointee.size > 0
        else {
            return []
        }

        let byteCount = unsafe Int(array.pointee.size)
        let elementSize = MemoryLayout<UInt32>.stride
        guard byteCount.isMultiple(of: elementSize) else {
            throw RuntimeError.invalidWaylandArrayByteCount(
                byteCount: byteCount,
                elementSize: elementSize
            )
        }

        let bytes = unsafe UnsafeRawBufferPointer(start: data, count: byteCount)
        return stride(from: 0, to: byteCount, by: elementSize).map { offset in
            unsafe bytes.loadUnaligned(fromByteOffset: offset, as: UInt32.self)
        }
    }
}
