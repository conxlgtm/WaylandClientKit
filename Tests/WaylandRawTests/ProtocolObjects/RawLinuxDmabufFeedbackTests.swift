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
        #expect(Glibc.fcntl(parserDescriptor, F_GETFD) == -1)
        #expect(errno == EBADF)
    }

    @Test
    func rejectsPartialEntriesAndClosesFd() throws {
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

        #expect(Glibc.fcntl(parserDescriptor, F_GETFD) == -1)
        #expect(errno == EBADF)
    }
}

@Suite
struct RawLinuxDmabufFeedbackStateTests {
    @Test
    func buildsSurfaceScopedFeedbackSnapshot() throws {
        let entries = [
            RawLinuxDmabufFormatModifier(format: 875_713_112, modifier: 0),
            RawLinuxDmabufFormatModifier(format: 875_713_089, modifier: UInt64.max),
        ]
        var state = RawLinuxDmabufFeedbackState()

        state.replaceFormatTable(entries)
        state.setMainDevice(bytes: [0x01, 0x02, 0x03, 0x04])
        state.setCurrentTrancheTargetDevice(bytes: [0x05, 0x06, 0x07, 0x08])
        try state.appendCurrentTrancheFormats(indices: [1, 0])
        state.setCurrentTrancheFlags(RawLinuxDmabufTrancheFlags.scanout.rawValue | 0x8000_0000)
        state.finishCurrentTranche()

        let snapshot = state.snapshot(scope: .surface(surfaceID: 77))

        #expect(snapshot.scope == .surface(surfaceID: 77))
        #expect(snapshot.mainDevice == RawLinuxDmabufDevice(bytes: [0x01, 0x02, 0x03, 0x04]))
        #expect(snapshot.formatTable == entries)
        #expect(snapshot.tranches.count == 1)
        #expect(
            snapshot.tranches[0].targetDevice
                == RawLinuxDmabufDevice(bytes: [0x05, 0x06, 0x07, 0x08])
        )
        #expect(snapshot.tranches[0].formats == [entries[1], entries[0]])
        #expect(snapshot.tranches[0].flags.contains(.scanout))
        #expect(snapshot.tranches[0].flags.unknownRawValue == 0x8000_0000)
    }

    @Test
    func rejectsFormatIndexOutsideCurrentTable() throws {
        var state = RawLinuxDmabufFeedbackState()
        state.replaceFormatTable([
            RawLinuxDmabufFormatModifier(format: 1, modifier: 2)
        ])

        do {
            try state.appendCurrentTrancheFormats(indices: [1])
            Issue.record("Expected invalid dmabuf format table index to throw")
        } catch RuntimeError.invalidDmabufFormatTableIndex(let index, let entryCount) {
            #expect(index == 1)
            #expect(entryCount == 1)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
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
