import Testing

@testable import WaylandClient

@Suite
struct EventStreamConfigurationTests {
    @Test
    func positiveIntRejectsInvalidCapacity() {
        #expect(throws: DomainValueError.nonPositiveInt(0)) {
            _ = try PositiveInt(0)
        }
    }

    @Test
    func configurationsUseOneCapacityDomainValue() throws {
        let minimum = try PositiveInt(1)
        let eventStreams = EventStreamConfiguration(
            eventCapacity: minimum,
            inputEventCapacity: minimum,
            textInputEventCapacity: minimum,
            dataTransferEventCapacity: minimum,
            presentationEventCapacity: minimum
        )
        let inputPipeline = InputPipelineConfiguration(
            motionCoalescing: [.pointerMotion],
            rawInputQueueCapacity: minimum,
            pendingInputEventCapacity: minimum
        )
        let diagnostics = DiagnosticsConfiguration(capacity: minimum)

        #expect(eventStreams.eventCapacity == minimum)
        #expect(eventStreams.inputEventCapacity == minimum)
        #expect(eventStreams.textInputEventCapacity == minimum)
        #expect(eventStreams.dataTransferEventCapacity == minimum)
        #expect(eventStreams.presentationEventCapacity == minimum)
        #expect(inputPipeline.rawInputQueueCapacity == minimum)
        #expect(inputPipeline.pendingInputEventCapacity == minimum)
        #expect(inputPipeline.motionCoalescing == [.pointerMotion])
        #expect(diagnostics.capacity == minimum)
    }

    @Test
    func inputPipelineDefaultsToAllMotionCoalescing() {
        #expect(InputPipelineConfiguration().motionCoalescing == .all)
    }
}
