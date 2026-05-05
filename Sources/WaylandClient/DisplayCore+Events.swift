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

    func publishSessionEvents(_ activeSession: DisplaySession) {
        publishDataTransferEvents(activeSession.drainDataTransferEventsOnOwnerThread())
        publishInputEvents(activeSession.drainInputEventsOnOwnerThread())
    }
}
