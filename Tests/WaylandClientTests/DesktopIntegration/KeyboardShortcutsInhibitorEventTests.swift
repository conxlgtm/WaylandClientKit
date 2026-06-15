#if SWL_ENABLE_TESTING
    import Testing
    import WaylandRaw

    @testable import WaylandClient

    @Suite
    struct KeyboardShortcutsInhibitorEventTests {
        @Test
        func rawActiveInactiveEventsPublishDisplayFacts() async throws {
            let hub = DisplayEventHub()
            let core = DisplayCore(eventHub: hub)
            let inhibitorID = KeyboardShortcutsInhibitorID(rawValue: 11)
            let windowID = WindowID(rawValue: 22)
            let seatID = SeatID(rawValue: 33)
            let rawInhibitor = try rawKeyboardShortcutsInhibitorForTesting()
            var iterator = hub.displayEvents().makeAsyncIterator()

            core.keyboardShortcutsInhibitorsByID[inhibitorID] =
                DisplayKeyboardShortcutsInhibitorRecord(
                    id: inhibitorID,
                    windowID: windowID,
                    seatID: seatID,
                    rawInhibitor: rawInhibitor
                )

            #expect(
                core.publishKeyboardShortcutsInhibitorEvent(
                    .active,
                    inhibitorID: inhibitorID
                )
            )
            #expect(
                core.publishKeyboardShortcutsInhibitorEvent(
                    .inactive,
                    inhibitorID: inhibitorID
                )
            )
            await expectKeyboardShortcutEvent(
                .keyboardShortcutsInhibitorChanged(
                    KeyboardShortcutsInhibitorEvent(
                        inhibitorID: inhibitorID,
                        windowID: windowID,
                        seatID: seatID,
                        activity: .active
                    )
                ),
                from: &iterator
            )
            await expectKeyboardShortcutEvent(
                .keyboardShortcutsInhibitorChanged(
                    KeyboardShortcutsInhibitorEvent(
                        inhibitorID: inhibitorID,
                        windowID: windowID,
                        seatID: seatID,
                        activity: .inactive
                    )
                ),
                from: &iterator
            )

            core.keyboardShortcutsInhibitorsByID.removeValue(forKey: inhibitorID)
            #expect(
                !core.publishKeyboardShortcutsInhibitorEvent(
                    .active,
                    inhibitorID: inhibitorID
                )
            )
        }
    }

    private func rawKeyboardShortcutsInhibitorForTesting() throws
        -> RawKeyboardShortcutsInhibitor
    {
        let pointer = try unsafe #require(OpaquePointer(bitPattern: 0xB901))
        return unsafe RawKeyboardShortcutsInhibitor(
            pointer: pointer,
            listenerOwner: nil,
            destroy: ignoreKeyboardShortcutsDestroy
        )
    }

    private func ignoreKeyboardShortcutsDestroy(_ pointer: OpaquePointer) {
        unsafe _ = pointer
    }

    private func expectKeyboardShortcutEvent(
        _ expectedEvent: DisplayEvent,
        from iterator: inout DisplayEventsIterator
    ) async {
        do {
            let event = try await iterator.next()
            #expect(event == expectedEvent)
        } catch {
            Issue.record("Expected keyboard shortcut display event, got \(error)")
        }
    }
#endif
