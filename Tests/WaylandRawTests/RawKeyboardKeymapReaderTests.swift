import Glibc
import Testing

@testable import WaylandRaw

@Suite
struct RawKeyboardKeymapReaderTests {
    @Test
    func readsNullTerminatedKeymapFromSizedFileDescriptor() throws {
        let bytes = Array("xkb_keymap {}".utf8) + [0]
        let descriptor = try makeTemporaryFileDescriptor(bytes: bytes)

        let payload = try RawKeyboardKeymapReader.readKeymap(
            fd: descriptor,
            size: UInt32(bytes.count),
            maximumSize: 1_024
        ) { close($0) }

        #expect(payload == bytes)
    }

    @Test
    func throwsWhenKeymapFileDescriptorIsSmallerThanAdvertisedSize() throws {
        let bytes = [UInt8(1), UInt8(0)]
        let descriptor = try makeTemporaryFileDescriptor(bytes: bytes)

        var closedDescriptors: [Int32] = []
        do {
            _ = try RawKeyboardKeymapReader.readKeymap(
                fd: descriptor,
                size: 4,
                maximumSize: 1_024
            ) { descriptor in
                closedDescriptors.append(descriptor)
                close(descriptor)
            }
            Issue.record("Expected keymap fd size error")
        } catch RuntimeError.keymapFdTooSmall(let size, let actualSize) {
            #expect(size == 4)
            #expect(actualSize == Int64(bytes.count))
        }

        #expect(closedDescriptors == [descriptor])
    }

    @Test
    func throwsWhenKeymapExceedsConfiguredMaximum() throws {
        let bytes = [UInt8](repeating: 0, count: 8)
        let descriptor = try makeTemporaryFileDescriptor(bytes: bytes)

        #expect(throws: RuntimeError.keymapTooLarge(size: 8, maxSize: 4)) {
            try RawKeyboardKeymapReader.readKeymap(
                fd: descriptor,
                size: 8,
                maximumSize: 4
            ) { close($0) }
        }
    }

    @Test
    func throwsWhenConfiguredMaximumExceedsHardMaximum() throws {
        let bytes = [UInt8](repeating: 0, count: 8)
        let descriptor = try makeTemporaryFileDescriptor(bytes: bytes)

        #expect(
            throws: RuntimeError.invalidKeymapSizeLimit(
                maxSize: RawKeyboardKeymapReader.hardMaximumKeymapSizeBytes + 1,
                hardMaximumSize: RawKeyboardKeymapReader.hardMaximumKeymapSizeBytes
            )
        ) {
            try RawKeyboardKeymapReader.readKeymap(
                fd: descriptor,
                size: 8,
                maximumSize: RawKeyboardKeymapReader.hardMaximumKeymapSizeBytes + 1
            ) { close($0) }
        }
    }

    @Test
    func throwsWhenXKBKeymapIsNotNullTerminated() throws {
        let bytes = [UInt8(1), UInt8(2)]
        let descriptor = try makeTemporaryFileDescriptor(bytes: bytes)

        #expect(throws: RuntimeError.keymapNotNullTerminated(size: 2)) {
            try RawKeyboardKeymapReader.readKeymap(
                fd: descriptor,
                size: 2,
                maximumSize: 1_024
            ) { close($0) }
        }
    }

    @Test
    func throwsWhenKeymapSizeIsTooSmallForXKBString() throws {
        let bytes = [UInt8(0)]
        let descriptor = try makeTemporaryFileDescriptor(bytes: bytes)

        #expect(throws: RuntimeError.invalidKeymapSize(1)) {
            try RawKeyboardKeymapReader.readKeymap(
                fd: descriptor,
                size: 1,
                maximumSize: 1_024
            ) { close($0) }
        }
    }

    private func makeTemporaryFileDescriptor(bytes: [UInt8]) throws -> Int32 {
        var template = Array("/tmp/swift-wayland-keymap-XXXXXX".utf8CString)
        let descriptor = template.withUnsafeMutableBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return Int32(-1) }
            return mkstemp(baseAddress)
        }
        try #require(descriptor >= 0)
        template.withUnsafeBufferPointer { buffer in
            if let baseAddress = buffer.baseAddress {
                unlink(baseAddress)
            }
        }

        let writeResult = bytes.withUnsafeBytes { rawBytes in
            write(descriptor, rawBytes.baseAddress, bytes.count)
        }
        try #require(writeResult == bytes.count)
        try #require(lseek(descriptor, 0, SEEK_SET) == 0)
        return descriptor
    }
}
