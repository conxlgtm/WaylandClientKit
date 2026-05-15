@safe
extension Array where Element == CChar {
    package func nullTerminatedUTF8String(writtenByteCount: Int) -> String? {
        let upperBound = Swift.min(Swift.max(writtenByteCount, 0), count)
        let endIndex = self[..<upperBound].firstIndex(of: 0) ?? upperBound
        return String(
            validating: self[..<endIndex].map { UInt8(bitPattern: $0) },
            as: UTF8.self
        )
    }
}
