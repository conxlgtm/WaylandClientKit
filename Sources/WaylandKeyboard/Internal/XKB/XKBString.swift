@safe
package func stringFromXKBSizedCall(
    _ body: (UnsafeMutablePointer<CChar>?, Int) -> Int32
) -> String? {
    let required = body(nil, 0)
    guard required > 0, Int(required) < Int.max else { return nil }

    let capacity = Int(required) + 1
    var buffer = [CChar](repeating: 0, count: capacity)
    let written = unsafe body(&buffer, capacity)
    guard written > 0, Int(written) < capacity else { return nil }

    return stringFromNullTerminatedXKBBuffer(
        buffer,
        writtenByteCount: Int(written)
    )
}

@safe
package func stringFromXKBNameCall(
    initialCapacity: Int = 64,
    _ body: (UnsafeMutablePointer<CChar>, Int) -> Int32
) -> String? {
    guard initialCapacity > 0 else { return nil }

    var buffer = [CChar](repeating: 0, count: initialCapacity)
    let required = unsafe body(&buffer, buffer.count)
    guard required > 0, Int(required) < Int.max else { return nil }

    if Int(required) < buffer.count {
        return stringFromNullTerminatedXKBBuffer(
            buffer,
            writtenByteCount: Int(required)
        )
    }

    let capacity = Int(required) + 1
    buffer = [CChar](repeating: 0, count: capacity)
    let written = unsafe body(&buffer, capacity)
    guard written > 0, Int(written) < capacity else { return nil }

    return stringFromNullTerminatedXKBBuffer(
        buffer,
        writtenByteCount: Int(written)
    )
}

@safe
private func stringFromNullTerminatedXKBBuffer(
    _ buffer: [CChar],
    writtenByteCount: Int
) -> String? {
    let upperBound = min(max(writtenByteCount, 0), buffer.count)
    let endIndex = buffer[..<upperBound].firstIndex(of: 0) ?? upperBound
    return String(
        validating: buffer[..<endIndex].map { UInt8(bitPattern: $0) },
        as: UTF8.self
    )
}
