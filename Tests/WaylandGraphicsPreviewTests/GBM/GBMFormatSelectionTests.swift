import Testing

@testable import WaylandGraphicsPreview
@testable import WaylandRaw

@Suite
struct GBMFormatSelectionTests {
    private let xrgb8888: UInt32 = 875_713_112
    private let argb8888: UInt32 = 875_713_089

    @Test
    func trancheOrderTakesPriorityOverClientFormatOrder() throws {
        let policy = try GBMFormatSelectionPolicy(
            preferredFormats: [xrgb8888, argb8888]
        )
        let feedback = try feedbackSnapshot(
            tranches: [
                FixtureTranche(
                    deviceByte: 1,
                    formats: [format(argb8888, modifier: 10)]
                ),
                FixtureTranche(
                    deviceByte: 2,
                    formats: [format(xrgb8888, modifier: 20)]
                ),
            ]
        )

        let selected = try GBMFormatSelector.selectFormatModifier(
            from: feedback,
            policy: policy
        )

        #expect(selected.formatModifier == format(argb8888, modifier: 10))
        #expect(selected.trancheIndex == 0)
        #expect(selected.targetDevice == RawLinuxDmabufDevice(bytes: [1]))
    }

    @Test
    func clientFormatOrderBreaksTiesWithinOneTranche() throws {
        let policy = try GBMFormatSelectionPolicy(
            preferredFormats: [xrgb8888, argb8888]
        )
        let feedback = try feedbackSnapshot(
            tranches: [
                FixtureTranche(
                    deviceByte: 1,
                    formats: [
                        format(argb8888, modifier: 10),
                        format(xrgb8888, modifier: 20),
                    ]
                )
            ]
        )

        let selected = try GBMFormatSelector.selectFormatModifier(
            from: feedback,
            policy: policy
        )

        #expect(selected.formatModifier == format(xrgb8888, modifier: 20))
        #expect(selected.trancheIndex == 0)
    }

    @Test
    func allowedModifiersFilterCandidates() throws {
        let policy = try GBMFormatSelectionPolicy(
            preferredFormats: [xrgb8888],
            modifierPolicy: .only(30)
        )
        let feedback = try feedbackSnapshot(
            tranches: [
                FixtureTranche(
                    deviceByte: 1,
                    formats: [
                        format(xrgb8888, modifier: 20),
                        format(xrgb8888, modifier: 30),
                    ]
                )
            ]
        )

        let selected = try GBMFormatSelector.selectFormatModifier(
            from: feedback,
            policy: policy
        )

        #expect(selected.formatModifier == format(xrgb8888, modifier: 30))
    }

    @Test
    func emptyFormatPreferenceIsRejected() {
        #expect(throws: GBMFormatSelectionError.emptyPreferredFormats) {
            _ = try GBMFormatSelectionPolicy(preferredFormats: [])
        }
    }

    @Test
    func emptyTranchesAreRejected() throws {
        #expect(
            throws: malformedFeedback(event: "done", field: "tranche")
        ) {
            _ = try feedbackSnapshot(tranches: [])
        }
    }

    @Test
    func missingFormatReportsPreferredFormats() throws {
        let policy = try GBMFormatSelectionPolicy(
            preferredFormats: [xrgb8888, argb8888]
        )
        let feedback = try feedbackSnapshot(
            tranches: [
                FixtureTranche(deviceByte: 1, formats: [format(1, modifier: 10)])
            ]
        )

        #expect(
            throws: GBMFormatSelectionError.noCompatibleFormat(
                preferredFormats: [xrgb8888, argb8888]
            )
        ) {
            _ = try GBMFormatSelector.selectFormatModifier(
                from: feedback,
                policy: policy
            )
        }
    }

    @Test
    func missingModifierReportsRejectedModifiers() throws {
        let policy = try GBMFormatSelectionPolicy(
            preferredFormats: [xrgb8888],
            modifierPolicy: .only(99)
        )
        let feedback = try feedbackSnapshot(
            tranches: [
                FixtureTranche(
                    deviceByte: 1,
                    formats: [
                        format(xrgb8888, modifier: 30),
                        format(xrgb8888, modifier: 20),
                    ]
                )
            ]
        )

        #expect(
            throws: GBMFormatSelectionError.noCompatibleModifier(
                format: xrgb8888,
                modifiers: [20, 30]
            )
        ) {
            _ = try GBMFormatSelector.selectFormatModifier(
                from: feedback,
                policy: policy
            )
        }
    }

    @Test
    func emptyModifierAllowListSelectsNoCandidates() throws {
        let policy = try GBMFormatSelectionPolicy(
            preferredFormats: [xrgb8888],
            modifierPolicy: .only()
        )
        let feedback = try feedbackSnapshot(
            tranches: [
                FixtureTranche(
                    deviceByte: 1,
                    formats: [format(xrgb8888, modifier: 20)]
                )
            ]
        )

        #expect(
            throws: GBMFormatSelectionError.noCompatibleModifier(
                format: xrgb8888,
                modifiers: [20]
            )
        ) {
            _ = try GBMFormatSelector.selectFormatModifier(
                from: feedback,
                policy: policy
            )
        }
    }

    private func feedbackSnapshot(
        tranches: [FixtureTranche]
    ) throws -> RawLinuxDmabufFeedbackSnapshot {
        let formats = tranches.reduce(into: [RawLinuxDmabufFormatModifier]()) { result, tranche in
            for format in tranche.formats where !result.contains(format) {
                result.append(format)
            }
        }
        var state = RawLinuxDmabufFeedbackState()

        state.replaceFormatTable(formats)
        try state.setMainDevice(bytes: [0], scope: .defaultFeedback)
        for tranche in tranches {
            try state.setCurrentTrancheTargetDevice(
                bytes: [tranche.deviceByte],
                scope: .defaultFeedback
            )
            try state.setCurrentTrancheFlags(0, scope: .defaultFeedback)
            let formatIndices = try tranche.formats.map { format -> UInt16 in
                guard let index = formats.firstIndex(of: format) else {
                    throw RuntimeError.invalidArgument("dmabuf feedback fixture format")
                }

                return UInt16(index)
            }
            try state.appendCurrentTrancheFormats(
                indices: formatIndices,
                scope: .defaultFeedback
            )
            try state.finishCurrentTranche(scope: .defaultFeedback)
        }

        return try state.finish(scope: .defaultFeedback)
    }

    private struct FixtureTranche {
        let deviceByte: UInt8
        let formats: [RawLinuxDmabufFormatModifier]
    }

    private func format(
        _ drmFormat: UInt32,
        modifier: UInt64
    ) -> RawLinuxDmabufFormatModifier {
        RawLinuxDmabufFormatModifier(format: drmFormat, modifier: modifier)
    }

    private func malformedFeedback(event: String, field: String) -> RuntimeError {
        RuntimeError.malformedDmabufFeedback(
            RawLinuxDmabufMalformedFeedback(
                scope: .defaultFeedback,
                event: event,
                field: field,
                index: nil,
                rawValue: nil,
                discardedStaleState: true
            )
        )
    }
}
