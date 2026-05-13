import Glibc
import Testing

@testable import WaylandRaw

@Suite(.serialized)
struct RawLinuxDmabufFormatTableTests {
    @Test
    func parsesFormatModifierPairsFromReadOnlyMappedFd() throws {
        let entries = [
            RawLinuxDmabufFormatModifier(
                format: 0x3432_5258,
                modifier: 0x0102_0304_0506_0708
            ),
            RawLinuxDmabufFormatModifier(
                format: 0x3432_525A,
                modifier: 0x8877_6655_4433_2211
            ),
        ]
        let bytes = formatTableBytes(entries)
        var descriptor = try RawFileDescriptor.memfd(name: "swift-wayland-dmabuf-table")
        defer {
            descriptor.close()
        }
        try descriptor.resize(byteCount: bytes.count)
        #expect(
            try RawFileDescriptor.write(descriptor: descriptor.rawValue, bytes: bytes)
                == bytes.count
        )

        let parserDescriptor = Glibc.dup(descriptor.rawValue)
        #expect(parserDescriptor >= 0)

        let parsed = try RawLinuxDmabufFormatTable.parse(
            fileDescriptor: parserDescriptor,
            byteCount: UInt32(bytes.count)
        )

        #expect(parsed == entries)
    }

    @Test
    func rejectsPartialEntries() throws {
        let bytes = [UInt8](repeating: 0xAA, count: RawLinuxDmabufFormatTable.entryByteCount - 1)
        var descriptor = try RawFileDescriptor.memfd(name: "swift-wayland-dmabuf-table-bad")
        defer {
            descriptor.close()
        }
        try descriptor.resize(byteCount: bytes.count)
        #expect(
            try RawFileDescriptor.write(descriptor: descriptor.rawValue, bytes: bytes)
                == bytes.count
        )

        let parserDescriptor = Glibc.dup(descriptor.rawValue)
        #expect(parserDescriptor >= 0)

        do {
            _ = try RawLinuxDmabufFormatTable.parse(
                fileDescriptor: parserDescriptor,
                byteCount: UInt32(bytes.count)
            )
            Issue.record("Expected partial dmabuf format table to throw")
        } catch RuntimeError.invalidDmabufFormatTableByteCount(let byteCount, let entryByteCount) {
            #expect(byteCount == bytes.count)
            #expect(entryByteCount == RawLinuxDmabufFormatTable.entryByteCount)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func formatTableSizeLargerThanFdReportsMalformedSizeWithoutSignal() throws {
        var descriptor = try RawFileDescriptor.memfd(name: "swift-wayland-dmabuf-table-short")
        defer {
            descriptor.close()
        }

        let parserDescriptor = Glibc.dup(descriptor.rawValue)
        #expect(parserDescriptor >= 0)

        do {
            _ = try RawLinuxDmabufFormatTable.parse(
                fileDescriptor: parserDescriptor,
                byteCount: UInt32(RawLinuxDmabufFormatTable.entryByteCount)
            )
            Issue.record("Expected short dmabuf format table fd to throw")
        } catch RuntimeError.invalidDmabufFormatTableByteCount(let byteCount, let entryByteCount) {
            #expect(byteCount == RawLinuxDmabufFormatTable.entryByteCount)
            #expect(entryByteCount == RawLinuxDmabufFormatTable.entryByteCount)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func formatTableShortFdClosesDescriptor() throws {
        var descriptor = try RawFileDescriptor.memfd(name: "swift-wayland-dmabuf-table-short")
        defer {
            descriptor.close()
        }

        let parserDescriptor = Glibc.dup(descriptor.rawValue)
        #expect(parserDescriptor >= 0)

        #expect(
            throws: RuntimeError.invalidDmabufFormatTableByteCount(
                byteCount: RawLinuxDmabufFormatTable.entryByteCount,
                entryByteCount: RawLinuxDmabufFormatTable.entryByteCount
            )
        ) {
            _ = try RawLinuxDmabufFormatTable.parse(
                fileDescriptor: parserDescriptor,
                byteCount: UInt32(RawLinuxDmabufFormatTable.entryByteCount)
            )
        }
        #expect(Glibc.fcntl(parserDescriptor, F_GETFD) == -1)
    }
}

private func formatTableBytes(_ entries: [RawLinuxDmabufFormatModifier]) -> [UInt8] {
    var bytes: [UInt8] = []
    for entry in entries {
        var format = entry.format
        unsafe withUnsafeBytes(of: &format) { formatBytes in
            bytes.append(contentsOf: unsafe Array(formatBytes))
        }
        bytes.append(contentsOf: [0, 0, 0, 0])
        var modifier = entry.modifier
        unsafe withUnsafeBytes(of: &modifier) { modifierBytes in
            bytes.append(contentsOf: unsafe Array(modifierBytes))
        }
    }

    return bytes
}
