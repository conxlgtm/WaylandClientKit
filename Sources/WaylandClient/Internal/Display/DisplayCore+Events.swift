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
        let outputEvents = activeSession.drainOutputEventsOnOwnerThread()
        publishOutputEvents(outputEvents)
        publishWindowOutputMembershipEvents(after: outputEvents)
        let dataTransfer = activeSession.drainDataTransferEventsAndDiagnosticsOnOwnerThread()
        publishDataTransferDiagnostics(dataTransfer.diagnostics)
        publishDataTransferEvents(dataTransfer.events)
        publishInputEvents(activeSession.drainInputEventsOnOwnerThread())
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
