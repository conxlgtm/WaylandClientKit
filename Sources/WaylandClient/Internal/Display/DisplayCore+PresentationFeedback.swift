extension DisplayCore {
    func requestPresentationFeedback(_ windowID: WindowID) throws {
        try withFatalFailureFinalization {
            let session = try requireSession()
            let presentation = try session.presentationOnOwnerThread()
            let window = try requireOpenWindow(windowID)
            _ = try window.requestPresentationFeedbackOnOwnerThread(
                presentation: presentation,
                outputIDForPresentationSyncOutput: { output in
                    try session.outputIDForPresentationSyncOutput(output)
                },
                onFeedback: { [weak self] feedback in
                    self?.eventHub.publishPresentation(
                        WindowPresentationEvent(windowID: windowID, feedback: feedback)
                    )
                }
            )
        }
    }

    func presentationFeedbackCommitRequest(
        for window: TopLevelWindow,
        windowID: WindowID,
        isRequested: Bool,
        onFeedback: (@Sendable (SurfacePresentationFeedback) -> Void)? = nil
    ) throws -> WindowPresentationFeedbackCommitRequest? {
        guard isRequested else { return nil }

        let session = try requireSession()
        let presentation = try session.presentationOnOwnerThread()
        return WindowPresentationFeedbackCommitRequest(
            request: {
                try window.requestPresentationFeedbackOnOwnerThread(
                    presentation: presentation,
                    outputIDForPresentationSyncOutput: { output in
                        try session.outputIDForPresentationSyncOutput(output)
                    },
                    onFeedback: { [weak self] feedback in
                        self?.eventHub.publishPresentation(
                            WindowPresentationEvent(
                                windowID: windowID,
                                feedback: feedback
                            )
                        )
                        onFeedback?(feedback)
                    }
                )
            },
            cancel: { identity in
                window.cancelPresentationFeedbackOnOwnerThread(identity)
            }
        )
    }
}
