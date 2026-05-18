import Testing

@testable import WaylandClient

@Suite
struct EventStreamConfigurationTests {
    @Test
    func eventStreamConfigurationRejectsInvalidCapacities() {
        #expect(
            throws: DisplayConfigurationError.nonPositiveCapacity(
                field: .displayEventCapacity,
                value: 0
            )
        ) {
            _ = try EventStreamConfiguration(displayEventCapacity: 0)
        }

        #expect(
            throws: DisplayConfigurationError.nonPositiveCapacity(
                field: .inputEventCapacity,
                value: 0
            )
        ) {
            _ = try EventStreamConfiguration(inputEventCapacity: 0)
        }

        #expect(
            throws: DisplayConfigurationError.nonPositiveCapacity(
                field: .dataTransferEventCapacity,
                value: 0
            )
        ) {
            _ = try EventStreamConfiguration(dataTransferEventCapacity: 0)
        }

        #expect(
            throws: DisplayConfigurationError.nonPositiveCapacity(
                field: .textInputEventCapacity,
                value: 0
            )
        ) {
            _ = try EventStreamConfiguration(textInputEventCapacity: 0)
        }

        #expect(
            throws: DisplayConfigurationError.nonPositiveCapacity(
                field: .presentationEventCapacity,
                value: 0
            )
        ) {
            _ = try EventStreamConfiguration(presentationEventCapacity: 0)
        }
    }

    @Test
    func inputPipelineConfigurationRejectsInvalidCapacities() {
        #expect(
            throws: DisplayConfigurationError.nonPositiveCapacity(
                field: .rawInputQueueCapacity,
                value: 0
            )
        ) {
            _ = try InputPipelineConfiguration(rawInputQueueCapacity: 0)
        }

        #expect(
            throws: DisplayConfigurationError.nonPositiveCapacity(
                field: .pendingInputEventCapacity,
                value: 0
            )
        ) {
            _ = try InputPipelineConfiguration(pendingInputEventCapacity: 0)
        }
    }

    @Test
    func diagnosticsConfigurationRejectsInvalidCapacity() {
        #expect(
            throws: DisplayConfigurationError.nonPositiveCapacity(
                field: .diagnosticsCapacity,
                value: 0
            )
        ) {
            _ = try DiagnosticsConfiguration(capacity: 0)
        }
    }

    @Test
    func eventStreamConfigurationAcceptsMinimumValidCapacities() throws {
        let eventStreams = try EventStreamConfiguration(
            displayEventCapacity: 1,
            inputEventCapacity: 1,
            textInputEventCapacity: 1,
            dataTransferEventCapacity: 1,
            presentationEventCapacity: 1
        )
        #expect(
            eventStreams.displayEventCapacity
                == (try EventStreamCapacity(1, field: .displayEventCapacity))
        )
        #expect(
            eventStreams.inputEventCapacity
                == (try EventStreamCapacity(1, field: .inputEventCapacity))
        )
        #expect(
            eventStreams.dataTransferEventCapacity
                == (try EventStreamCapacity(1, field: .dataTransferEventCapacity))
        )
        #expect(
            eventStreams.textInputEventCapacity
                == (try EventStreamCapacity(1, field: .textInputEventCapacity))
        )
        #expect(
            eventStreams.presentationEventCapacity
                == (try EventStreamCapacity(1, field: .presentationEventCapacity))
        )
    }

    @Test
    func inputPipelineAndDiagnosticsAcceptMinimumValidCapacities() throws {
        let inputPipeline = try InputPipelineConfiguration(
            rawInputQueueCapacity: 1,
            pendingInputEventCapacity: 1
        )
        let diagnostics = try DiagnosticsConfiguration(capacity: 1)

        #expect(
            inputPipeline.rawInputQueueCapacity
                == (try InputQueueCapacity(1, field: .rawInputQueueCapacity))
        )
        #expect(
            inputPipeline.pendingInputEventCapacity
                == (try InputQueueCapacity(1, field: .pendingInputEventCapacity))
        )
        #expect(diagnostics.capacity == (try DiagnosticsCapacity(1)))
    }
}
