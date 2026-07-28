import WaylandClient

extension ManagedSurfaceSmokeRun {
    func presentWindow(_ window: Window, requestsFeedback: Bool) async throws {
        var feedback = window.presentationEvents.makeAsyncIterator()
        let outcome = try await retryPresentation(label: "window initial presentation") {
            try await window.show(requestPresentationFeedback: requestsFeedback) { frame in
                drawManagedSurfaceFrame(frame, color: 0x0030_6090)
            }
        }
        try requirePresented(outcome, label: "window initial presentation")
        if requestsFeedback {
            try await requireFeedback(from: &feedback, label: "window")
        }
        print("window initial presentation: presented")
    }

    func presentPopup(_ popup: PopupSurface, requestsFeedback: Bool) async throws {
        var feedback = popup.presentationEvents.makeAsyncIterator()
        let outcome = try await retryPresentation(label: "popup initial presentation") {
            try await popup.show(
                requestPresentationFeedback: requestsFeedback,
                preparing: { reservation in reservation.id },
                { _, frame in drawManagedSurfaceFrame(frame, color: 0x0080_4080) }
            )
        }
        try requirePresented(outcome, label: "popup initial presentation")
        if requestsFeedback {
            try await requireFeedback(from: &feedback, label: "popup")
        }
        print("popup initial presentation: presented")
    }

    func presentSubsurface(
        _ subsurface: Subsurface,
        label: String,
        color: UInt32,
        requestsFeedback: Bool
    ) async throws {
        var feedback = subsurface.presentationEvents.makeAsyncIterator()
        let outcome = try await retryPresentation(label: label) {
            try await subsurface.show(
                requestPresentationFeedback: requestsFeedback,
                preparing: { reservation in reservation.id },
                { _, frame in drawManagedSurfaceFrame(frame, color: color) }
            )
        }
        try requirePresented(outcome, label: label)
        if requestsFeedback {
            try await requireFeedback(from: &feedback, label: label)
        }
        print("\(label): presented")
    }

    private func requirePresented(
        _ outcome: SoftwarePresentationOutcome,
        label: String
    ) throws {
        guard outcome == .presented else {
            throw ManagedSurfaceSmokeError.unexpectedPresentationOutcome(label, outcome)
        }
    }

    func retryPresentation(
        label: String,
        operation: () async throws -> SoftwarePresentationOutcome
    ) async throws -> SoftwarePresentationOutcome {
        var latestOutcome = SoftwarePresentationOutcome.deferred
        for _ in 0..<8 {
            latestOutcome = try await operation()
            switch latestOutcome {
            case .presented:
                return latestOutcome
            case .superseded, .deferred:
                try await Task.sleep(for: .milliseconds(10))
            case .closed:
                throw ManagedSurfaceSmokeError.unexpectedPresentationOutcome(
                    label,
                    latestOutcome
                )
            }
        }
        return latestOutcome
    }

    private func requireFeedback(
        from iterator: inout ManagedSurfacePresentationEvents.AsyncIterator,
        label: String
    ) async throws {
        guard let feedback = try await iterator.next() else {
            throw ManagedSurfaceSmokeError.presentationStreamEnded(label)
        }
        print("\(label) feedback: \(feedback)")
    }
}
