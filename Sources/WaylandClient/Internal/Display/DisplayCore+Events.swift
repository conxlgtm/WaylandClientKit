extension DisplayCore {
    func publishInputEvents(_ inputEvents: [InputEvent]) {
        for inputEvent in inputEvents {
            eventHub.publishInput(inputEvent)
        }
    }

    func publishDataTransferEvents(_ events: [DataTransferEvent]) {
        for event in events {
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
        publishOutputEvents(outputEvents)
        publishWindowOutputMembershipEvents(after: outputEvents)
        publishInputEvents(activeSession.drainInputEventsOnOwnerThread())
        publishTextInputEvents(activeSession.drainTextInputEventsOnOwnerThread())
        let dataTransfer = activeSession.drainDataTransferEventsAndDiagnosticsOnOwnerThread()
        publishDataTransferDiagnostics(dataTransfer.diagnostics)
        publishDataTransferEvents(dataTransfer.events)
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
