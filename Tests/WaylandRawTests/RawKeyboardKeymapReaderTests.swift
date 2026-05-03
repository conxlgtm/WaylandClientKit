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
            id: keymapID(),
            format: .xkbV1,
            fd: descriptor,
            size: UInt32(bytes.count),
            maximumSize: 1_024
        ) { close($0) }

        #expect(payload.xkbV1Bytes?.rawValue == bytes)
    }

    @Test
    func noKeymapProducesDistinctPayloadWithoutReadingBytes() throws {
        let descriptor = Int32(-1)
        let id = keymapID()

        let payload = try RawKeyboardKeymapReader.readKeymap(
            id: id,
            format: .noKeymap,
            fd: descriptor,
            size: 0,
            maximumSize: 1_024
        ) { _ in
            Issue.record("noKeymap should not close invalid file descriptors")
        }

        #expect(payload == .noKeymap(id: id))
        #expect(payload.size == 0)
    }

    @Test
    func throwsWhenFormatIsUnsupported() throws {
        let bytes = [UInt8(1), UInt8(0)]
        let descriptor = try makeTemporaryFileDescriptor(bytes: bytes)
        let unsupported = RawKeyboardKeymapFormat(rawValue: 99)
        var closedDescriptors: [Int32] = []

        #expect(
            throws: RawKeyboardKeymapReadError.unsupportedFormat(
                format: unsupported,
                advertisedSize: UInt32(bytes.count)
            )
        ) {
            try RawKeyboardKeymapReader.readKeymap(
                id: keymapID(),
                format: unsupported,
                fd: descriptor,
                size: UInt32(bytes.count),
                maximumSize: 1_024
            ) { descriptor in
                closedDescriptors.append(descriptor)
                close(descriptor)
            }
        }
        #expect(closedDescriptors == [descriptor])
    }

    @Test
    func throwsWhenKeymapFileDescriptorIsSmallerThanAdvertisedSize() throws {
        let bytes = [UInt8(1), UInt8(0)]
        let descriptor = try makeTemporaryFileDescriptor(bytes: bytes)

        var closedDescriptors: [Int32] = []
        do {
            _ = try RawKeyboardKeymapReader.readKeymap(
                id: keymapID(),
                format: .xkbV1,
                fd: descriptor,
                size: 4,
                maximumSize: 1_024
            ) { descriptor in
                closedDescriptors.append(descriptor)
                close(descriptor)
            }
            Issue.record("Expected keymap fd size error")
        } catch RawKeyboardKeymapReadError.fdTooSmall(let size, let actualSize) {
            #expect(size == 4)
            #expect(actualSize == Int64(bytes.count))
        }

        #expect(closedDescriptors == [descriptor])
    }

    @Test
    func throwsWhenKeymapExceedsConfiguredMaximum() throws {
        let bytes = [UInt8](repeating: 0, count: 8)
        let descriptor = try makeTemporaryFileDescriptor(bytes: bytes)

        #expect(throws: RawKeyboardKeymapReadError.tooLarge(size: 8, maxSize: 4)) {
            try RawKeyboardKeymapReader.readKeymap(
                id: keymapID(),
                format: .xkbV1,
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
            throws: RawKeyboardKeymapReadError.invalidSizeLimit(
                maxSize: RawKeyboardKeymapReader.hardMaximumKeymapSizeBytes + 1,
                hardMaximumSize: RawKeyboardKeymapReader.hardMaximumKeymapSizeBytes
            )
        ) {
            try RawKeyboardKeymapReader.readKeymap(
                id: keymapID(),
                format: .xkbV1,
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

        #expect(throws: RawKeyboardKeymapReadError.missingNULTerminator(size: 2)) {
            try RawKeyboardKeymapReader.readKeymap(
                id: keymapID(),
                format: .xkbV1,
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

        #expect(throws: RawKeyboardKeymapReadError.emptyXKBV1Payload(size: 1)) {
            try RawKeyboardKeymapReader.readKeymap(
                id: keymapID(),
                format: .xkbV1,
                fd: descriptor,
                size: 1,
                maximumSize: 1_024
            ) { close($0) }
        }
    }

    private func keymapID() -> RawKeyboardKeymapID {
        RawKeyboardKeymapID(
            seatID: RawSeatID(rawValue: 1),
            keyboardGeneration: 1,
            keymapGeneration: 1
        )
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
