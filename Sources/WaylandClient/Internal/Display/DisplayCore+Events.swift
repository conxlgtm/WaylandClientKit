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
        publishOutputEvents(activeSession.drainOutputEventsOnOwnerThread())
        publishDataTransferDiagnostics(activeSession.drainDataTransferDiagnosticsOnOwnerThread())
        publishDataTransferEvents(activeSession.drainDataTransferEventsOnOwnerThread())
        publishInputEvents(activeSession.drainInputEventsOnOwnerThread())
    }
}
