import CWaylandProtocols

enum WaylandArray {
    static func uint32Values(from array: UnsafeMutablePointer<wl_array>?)
        throws(RuntimeError) -> [UInt32]
    {
        guard
            let array,
            let data = array.pointee.data,
            array.pointee.size > 0
        else {
            return []
        }

        let byteCount = Int(array.pointee.size)
        let elementSize = MemoryLayout<UInt32>.stride
        guard byteCount.isMultiple(of: elementSize) else {
            throw RuntimeError.invalidWaylandArrayByteCount(
                byteCount: byteCount,
                elementSize: elementSize
            )
        }

        let bytes = UnsafeRawBufferPointer(start: data, count: byteCount)
        return stride(from: 0, to: byteCount, by: elementSize).map { offset in
            bytes.loadUnaligned(fromByteOffset: offset, as: UInt32.self)
        }
    }
}
