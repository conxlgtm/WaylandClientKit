import CWaylandProtocols

enum WaylandArray {
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
