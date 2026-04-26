import Glibc
import Testing

@testable import WaylandRaw

@Suite
struct RawInputEventStreamTests {
    @Test
    func yieldsEventsFromPumpedBatchesInOrder() async throws {
        let seatID = RawSeatID(rawValue: 4)
        let seatRemoved = RawInputEvent(
            sequence: 1,
            seatID: seatID,
            deviceID: nil,
            kind: .seatRemoved
        )
        let seatSnapshot = RawInputEvent(
            sequence: 2,
            seatID: seatID,
            deviceID: nil,
            kind: .seat(
                RawSeatEventSnapshot(
                    advertisedCapabilities: [.keyboard],
                    activeCapabilities: [.keyboard],
                    name: "seat0"
                )
            )
        )
        let repeatInfo = RawInputEvent(
            sequence: 3,
            seatID: seatID,
            deviceID: nil,
            kind: .keyboard(.repeatInfo(.init(rate: 30, delay: 400)))
        )
        let batches = [[seatRemoved, seatSnapshot], [repeatInfo]]
        var pumpCount = 0
        let stream = RawInputEventStream(timeoutMilliseconds: 0) { _ in
            defer { pumpCount += 1 }
            return batches[pumpCount]
        }
        var iterator = stream.makeAsyncIterator()

        #expect(try await iterator.next()?.sequence == 1)
        #expect(try await iterator.next()?.sequence == 2)
        #expect(try await iterator.next()?.sequence == 3)
        #expect(pumpCount == 2)
    }

    @Test
    func terminatesAfterPumpError() async throws {
        let stream = RawInputEventStream(timeoutMilliseconds: 0) { _ in
            throw RuntimeError.pollFailed(EINVAL)
        }
        var iterator = stream.makeAsyncIterator()

        do {
            _ = try await iterator.next()
            Issue.record("Expected pump error")
        } catch RuntimeError.pollFailed(let errno) {
            #expect(errno == EINVAL)
        }

        #expect(try await iterator.next() == nil)
    }
}
