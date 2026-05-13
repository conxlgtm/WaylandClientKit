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
        let feedback = feedbackSnapshot(
            tranches: [
                tranche(
                    deviceByte: 1,
                    formats: [format(argb8888, modifier: 10)]
                ),
                tranche(
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
        let feedback = feedbackSnapshot(
            tranches: [
                tranche(
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
            allowedModifiers: [30]
        )
        let feedback = feedbackSnapshot(
            tranches: [
                tranche(
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
        let policy = try GBMFormatSelectionPolicy(preferredFormats: [xrgb8888])
        let feedback = feedbackSnapshot(tranches: [])

        #expect(throws: GBMFormatSelectionError.noFeedbackTranches) {
            _ = try GBMFormatSelector.selectFormatModifier(
                from: feedback,
                policy: policy
            )
        }
    }

    @Test
    func missingFormatReportsPreferredFormats() throws {
        let policy = try GBMFormatSelectionPolicy(
            preferredFormats: [xrgb8888, argb8888]
        )
        let feedback = feedbackSnapshot(
            tranches: [
                tranche(deviceByte: 1, formats: [format(1, modifier: 10)])
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
            allowedModifiers: [99]
        )
        let feedback = feedbackSnapshot(
            tranches: [
                tranche(
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

    private func feedbackSnapshot(
        tranches: [RawLinuxDmabufTranche]
    ) -> RawLinuxDmabufFeedbackSnapshot {
        RawLinuxDmabufFeedbackSnapshot(
            scope: .defaultFeedback,
            mainDevice: RawLinuxDmabufDevice(bytes: [0]),
            formatTable: [],
            tranches: tranches
        )
    }

    private func tranche(
        deviceByte: UInt8,
        formats: [RawLinuxDmabufFormatModifier]
    ) -> RawLinuxDmabufTranche {
        RawLinuxDmabufTranche(
            targetDevice: RawLinuxDmabufDevice(bytes: [deviceByte]),
            flags: [],
            formats: formats
        )
    }

    private func format(
        _ drmFormat: UInt32,
        modifier: UInt64
    ) -> RawLinuxDmabufFormatModifier {
        RawLinuxDmabufFormatModifier(format: drmFormat, modifier: modifier)
    }
}
