import CWaylandProtocols
import Testing

@testable import WaylandRaw

@Suite
struct WaylandArrayTests {
    @Test
    func decodesUInt32ValuesFromUnalignedStorage() throws {
        let values = [UInt32(0x0102_0304), UInt32(0xa0b0_c0d0)]
        var storage = [UInt8](repeating: 0, count: 1 + values.count * MemoryLayout<UInt32>.stride)
        for (index, value) in values.enumerated() {
            unsafe withUnsafeBytes(of: value) { bytes in
                let offset = 1 + index * MemoryLayout<UInt32>.stride
                unsafe storage.replaceSubrange(offset..<(offset + bytes.count), with: bytes)
            }
        }
        let decoded = try unsafe storage.withUnsafeMutableBytes { bytes in
            var array = unsafe wl_array(
                size: values.count * MemoryLayout<UInt32>.stride,
                alloc: values.count * MemoryLayout<UInt32>.stride,
                data: bytes.baseAddress?.advanced(by: 1)
            )
            return try WaylandArray.uint32Values(from: &array)
        }
        #expect(decoded == values)
    }
    @Test
    func rejectsPartialUInt32Storage() throws {
        var storage = [UInt8](repeating: 0, count: 3)
        do {
            _ = try unsafe storage.withUnsafeMutableBytes { bytes in
                var array = unsafe wl_array(size: 3, alloc: 3, data: bytes.baseAddress)
                return try WaylandArray.uint32Values(from: &array)
            }
            Issue.record("Expected invalid Wayland array size to throw")
        } catch RuntimeError.invalidWaylandArrayByteCount(let byteCount, let elementSize) {
            #expect(byteCount == 3)
            #expect(elementSize == MemoryLayout<UInt32>.stride)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func decodesUInt16ValuesFromUnalignedStorage() throws {
        let values = [UInt16(2), UInt16(513)]
        var storage = [UInt8](repeating: 0, count: 1 + values.count * MemoryLayout<UInt16>.stride)
        for (index, value) in values.enumerated() {
            unsafe withUnsafeBytes(of: value) { bytes in
                let offset = 1 + index * MemoryLayout<UInt16>.stride
                unsafe storage.replaceSubrange(offset..<(offset + bytes.count), with: bytes)
            }
        }

        let decoded = try unsafe storage.withUnsafeMutableBytes { bytes in
            var array = unsafe wl_array(
                size: values.count * MemoryLayout<UInt16>.stride,
                alloc: values.count * MemoryLayout<UInt16>.stride,
                data: bytes.baseAddress?.advanced(by: 1)
            )
            return try WaylandArray.uint16Values(from: &array)
        }

        #expect(decoded == values)
    }

    @Test
    func returnsRawBytes() {
        var storage = [UInt8](arrayLiteral: 0xCA, 0xFE, 0xBA, 0xBE)
        let byteCount = storage.count
        let decoded = unsafe storage.withUnsafeMutableBytes { bytes in
            var array = unsafe wl_array(
                size: byteCount,
                alloc: byteCount,
                data: bytes.baseAddress
            )
            return WaylandArray.bytes(from: &array)
        }

        #expect(decoded == [0xCA, 0xFE, 0xBA, 0xBE])
    }
}
