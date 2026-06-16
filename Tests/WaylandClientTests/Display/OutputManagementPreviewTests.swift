import Testing

@testable import WaylandClient
@testable import WaylandRaw

@Suite
struct OutputManagementPreviewTests {
    @Test
    func collectorBuildsSnapshotFromDoneBoundFacts() throws {
        var nextHeadID: UInt64 = 1
        var nextModeID: UInt64 = 10
        let collector = OutputManagementCollector(
            headIDProvider: { _ in
                defer { nextHeadID += 1 }
                return OutputManagementHeadID(rawValue: nextHeadID)
            },
            modeIDProvider: {
                defer { nextModeID += 1 }
                return OutputManagementModeID(rawValue: nextModeID)
            }
        )
        let head = RawWlrOutputHead(pointer: try unsafe fakePointer(0xA01), version: RawVersion(4))
        let mode = RawWlrOutputMode(pointer: try unsafe fakePointer(0xA02), version: RawVersion(4))
        defer {
            head.abandonAfterManagerFinished()
            mode.abandonAfterManagerFinished()
        }

        collector.handle(.head(head))
        collector.handle(.headEvent(head, .name("DP-1")))
        collector.handle(.headEvent(head, .description("Example display")))
        collector.handle(.headEvent(head, .enabled(true)))
        collector.handle(.headEvent(head, .position(x: 10, y: 20)))
        collector.handle(.headEvent(head, .transform(OutputTransform.rotated90.rawValue)))
        collector.handle(.headEvent(head, .scale(WaylandFixed(rawValue: 384))))
        collector.handle(.headEvent(head, .make("Example")))
        collector.handle(.headEvent(head, .model("Panel")))
        collector.handle(.headEvent(head, .serialNumber("ABC123")))
        collector.handle(.headEvent(head, .mode(mode)))
        collector.handle(.modeEvent(head, mode, .size(width: 1_920, height: 1_080)))
        collector.handle(.modeEvent(head, mode, .refresh(60_000)))
        collector.handle(.modeEvent(head, mode, .preferred))
        collector.handle(.headEvent(head, .currentMode(mode)))
        collector.handle(.done(42))

        let snapshot = try collector.snapshot()

        #expect(snapshot.serial == 42)
        #expect(snapshot.heads.count == 1)
        let outputHead = try #require(snapshot.heads.first)
        #expect(outputHead.id == OutputManagementHeadID(rawValue: 1))
        #expect(outputHead.name == "DP-1")
        #expect(outputHead.description == "Example display")
        #expect(outputHead.enabled)
        #expect(outputHead.position == LogicalOffset(x: 10, y: 20))
        #expect(outputHead.transform == .rotated90)
        #expect(outputHead.scale == (try SurfaceScale(numerator: 384, denominator: 256)))
        #expect(outputHead.make == "Example")
        #expect(outputHead.model == "Panel")
        #expect(outputHead.serialNumber == "ABC123")
        #expect(outputHead.modes.count == 1)

        let outputMode = try #require(outputHead.modes.first)
        #expect(outputMode.id == OutputManagementModeID(rawValue: 10))
        #expect(outputMode.size == (try PositivePixelSize(width: 1_920, height: 1_080)))
        #expect(
            outputMode.refresh == OutputRefreshRate.milliHertz(PositiveInt32(unchecked: 60_000)))
        #expect(outputMode.isPreferred)
        #expect(outputMode.isCurrent)
    }

    @Test
    func collectorRejectsMissingDoneSerial() throws {
        let collector = OutputManagementCollector(
            headIDProvider: { _ in OutputManagementHeadID(rawValue: 1) },
            modeIDProvider: { OutputManagementModeID(rawValue: 1) }
        )

        #expect(throws: ClientError.display(.outputManagementIncomplete)) {
            _ = try collector.snapshot()
        }
    }

    @Test
    func collectorRemovesFinishedHeadsAndModes() throws {
        let collector = OutputManagementCollector(
            headIDProvider: { _ in OutputManagementHeadID(rawValue: 1) },
            modeIDProvider: { OutputManagementModeID(rawValue: 1) }
        )
        let head = RawWlrOutputHead(pointer: try unsafe fakePointer(0xA11), version: RawVersion(4))
        let mode = RawWlrOutputMode(pointer: try unsafe fakePointer(0xA12), version: RawVersion(4))
        defer {
            head.abandonAfterManagerFinished()
            mode.abandonAfterManagerFinished()
        }

        collector.handle(.head(head))
        collector.handle(.headEvent(head, .mode(mode)))
        collector.handle(.modeEvent(head, mode, .size(width: 800, height: 600)))
        collector.handle(.modeEvent(head, mode, .finished))
        collector.handle(.done(5))

        var snapshot = try collector.snapshot()
        #expect(snapshot.heads.first?.modes.isEmpty == true)

        collector.handle(.headEvent(head, .finished))
        snapshot = try collector.snapshot()
        #expect(snapshot.heads.isEmpty)
    }

    @Test
    func configurationResultMappingIsTyped() {
        #expect(DisplayCore.outputManagementConfigurationError(for: .succeeded) == nil)
        #expect(
            DisplayCore.outputManagementConfigurationError(for: .failed)
                == ClientError.display(.outputConfigurationFailed)
        )
        #expect(
            DisplayCore.outputManagementConfigurationError(for: .cancelled)
                == ClientError.display(.outputConfigurationCancelled)
        )
        #expect(
            DisplayCore.outputManagementConfigurationError(for: nil)
                == ClientError.display(.outputConfigurationFailed)
        )
    }
}

private enum FakePointerError: Error {
    case invalid(UInt)
}

private func fakePointer(_ bitPattern: UInt) throws -> OpaquePointer {
    guard let pointer = unsafe OpaquePointer(bitPattern: bitPattern) else {
        throw FakePointerError.invalid(bitPattern)
    }
    return unsafe pointer
}
