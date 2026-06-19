extension DisplayCore {
    func publishInputEvents(_ inputEvents: [InputEvent]) {
        for inputEvent in inputEvents {
            performInputSerialActions(for: inputEvent)
            eventHub.publishInput(inputEvent)
        }
    }

    func publishDataTransferEvents(_ events: [DataTransferEvent]) {
        for event in events {
            cleanupToplevelDrags(after: event)
            eventHub.publishDataTransfer(event)
        }
    }

    func publishDataTransferDiagnostics(_ diagnostics: [DataTransferDiagnostic]) {
        for diagnostic in diagnostics {
            eventHub.publishDataTransferDiagnostic(diagnostic)
        }
    }

    func publishOutputEvents(_ events: [DisplayEvent]) {
        for event in events {
            eventHub.publish(event)
        }
    }

    func publishSessionEvents(_ activeSession: DisplaySession) {
        // Topology changes publish first so later input, text-input, and transfer
        // events can be interpreted against the latest output membership. Input
        // focus then precedes text-input transactions, and data-transfer effects
        // publish last because they may be triggered by the same input pump.
        let outputEvents = activeSession.drainOutputEventsOnOwnerThread()
        updateCursorScalesIfOutputsChanged(outputEvents, activeSession: activeSession)
        publishOutputEvents(outputEvents)
        publishWindowOutputMembershipEvents(after: outputEvents)
        publishInputEvents(activeSession.drainInputEventsOnOwnerThread())
        publishTextInputEvents(activeSession.drainTextInputEventsOnOwnerThread())
        let dataTransfer = activeSession.drainDataTransferEventsAndDiagnosticsOnOwnerThread()
        publishDataTransferDiagnostics(dataTransfer.diagnostics)
        publishDataTransferEvents(dataTransfer.events)
    }

    private func updateCursorScalesIfOutputsChanged(
        _ outputEvents: [DisplayEvent],
        activeSession: DisplaySession
    ) {
        guard outputEvents.contains(where: isOutputChange) else { return }

        do {
            try activeSession.updateAvailableCursorOutputScalesOnOwnerThread()
        } catch {
            markSurfaceStoreInvariantFailed(error)
        }
    }

    private func publishWindowOutputMembershipEvents(after outputEvents: [DisplayEvent]) {
        for event in outputEvents {
            guard case .outputRemoved(let outputID) = event else { continue }

            for windowID in surfaces.allWindowIDs {
                surfaces.window(windowID)?.removeOutputMembershipOnOwnerThread(outputID)
            }
        }
    }
}

extension DisplayCore {
    private func cleanupToplevelDrags(after event: DataTransferEvent) {
        switch event {
        case .dragSourceCancelled(let source),
            .dragSourceDropPerformed(let source):
            closeToplevelDrags(for: source)
        case .dragSourceFinished(let finished):
            closeToplevelDrags(for: finished.source)
        case .clipboardSelectionChanged,
            .primarySelectionChanged,
            .sourceSendRequested,
            .sourceWriteSucceeded,
            .clipboardSourceCancelled,
            .primarySelectionSourceCancelled,
            .dragSourceTargetChanged,
            .dragSourceActionChanged,
            .dragEntered,
            .dragMotion,
            .dragLeft,
            .dragDropped,
            .dragOfferChanged:
            break
        }
    }
}

private func isOutputChange(_ event: DisplayEvent) -> Bool {
    switch event {
    case .outputChanged, .outputRemoved:
        true
    case .input,
        .diagnostic,
        .windowCloseRequested,
        .windowClosed,
        .popupDismissed,
        .popupClosed,
        .redrawRequested,
        .popupRedrawRequested,
        .windowOutputsChanged,
        .keyboardShortcutsInhibitorChanged:
        false
    }
}
