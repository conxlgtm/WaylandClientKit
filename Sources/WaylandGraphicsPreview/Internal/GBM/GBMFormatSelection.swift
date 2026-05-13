import WaylandRaw

package struct GBMFormatSelectionPolicy: Equatable, Sendable {
    package let preferredFormats: [UInt32]
    package let allowedModifiers: Set<UInt64>?

    package init(
        preferredFormats formatPreference: [UInt32],
        allowedModifiers modifierSet: Set<UInt64>? = nil
    ) throws(GBMFormatSelectionError) {
        guard !formatPreference.isEmpty else {
            throw GBMFormatSelectionError.emptyPreferredFormats
        }

        preferredFormats = formatPreference
        allowedModifiers = modifierSet
    }

    func allows(_ formatModifier: RawLinuxDmabufFormatModifier) -> Bool {
        guard let allowedModifiers else { return true }

        return allowedModifiers.contains(formatModifier.modifier)
    }
}

package struct GBMFormatModifierSelection: Equatable, Sendable {
    package let formatModifier: RawLinuxDmabufFormatModifier
    package let targetDevice: RawLinuxDmabufDevice
    package let trancheFlags: RawLinuxDmabufTrancheFlags
    package let trancheIndex: Int

    package init(
        formatModifier selectedFormatModifier: RawLinuxDmabufFormatModifier,
        targetDevice selectedTargetDevice: RawLinuxDmabufDevice,
        trancheFlags selectedTrancheFlags: RawLinuxDmabufTrancheFlags,
        trancheIndex selectedTrancheIndex: Int
    ) {
        formatModifier = selectedFormatModifier
        targetDevice = selectedTargetDevice
        trancheFlags = selectedTrancheFlags
        trancheIndex = selectedTrancheIndex
    }
}

package enum GBMFormatSelectionError: Error, Equatable, Sendable, CustomStringConvertible {
    case emptyPreferredFormats
    case noFeedbackTranches
    case noCompatibleFormat(preferredFormats: [UInt32])
    case noCompatibleModifier(format: UInt32, modifiers: [UInt64])

    package var description: String {
        switch self {
        case .emptyPreferredFormats:
            "GBM format selection requires at least one preferred format"
        case .noFeedbackTranches:
            "linux-dmabuf feedback did not advertise any tranches"
        case .noCompatibleFormat(let preferredFormats):
            "linux-dmabuf feedback has no compatible format from \(preferredFormats)"
        case .noCompatibleModifier(let format, let modifiers):
            "linux-dmabuf feedback has no compatible modifier for format \(format): \(modifiers)"
        }
    }
}

package enum GBMFormatSelector {
    package static func selectFormatModifier(
        from feedback: RawLinuxDmabufFeedbackSnapshot,
        policy: GBMFormatSelectionPolicy
    ) throws(GBMFormatSelectionError) -> GBMFormatModifierSelection {
        guard !feedback.tranches.isEmpty else {
            throw GBMFormatSelectionError.noFeedbackTranches
        }

        var rejectedModifiersByFormat: [UInt32: Set<UInt64>] = [:]
        for (trancheIndex, tranche) in feedback.tranches.enumerated() {
            for preferredFormat in policy.preferredFormats {
                let candidates = tranche.formats.filter { $0.format == preferredFormat }
                if candidates.isEmpty { continue }

                if let selected = candidates.first(where: policy.allows) {
                    return GBMFormatModifierSelection(
                        formatModifier: selected,
                        targetDevice: tranche.targetDevice,
                        trancheFlags: tranche.flags,
                        trancheIndex: trancheIndex
                    )
                }

                rejectedModifiersByFormat[preferredFormat, default: []]
                    .formUnion(candidates.map(\.modifier))
            }
        }

        for preferredFormat in policy.preferredFormats {
            if let rejectedModifiers = rejectedModifiersByFormat[preferredFormat] {
                throw GBMFormatSelectionError.noCompatibleModifier(
                    format: preferredFormat,
                    modifiers: rejectedModifiers.sorted()
                )
            }
        }

        throw GBMFormatSelectionError.noCompatibleFormat(
            preferredFormats: policy.preferredFormats
        )
    }
}
