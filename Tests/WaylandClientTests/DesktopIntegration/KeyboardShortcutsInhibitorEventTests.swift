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

        @Test
        func seatRemovalClosesShortcutInhibitorsForSeat() throws {
            let core = DisplayCore(eventHub: DisplayEventHub())
            let removedSeatID = SeatID(rawValue: 33)
            let keptSeatID = SeatID(rawValue: 44)
            let firstID = KeyboardShortcutsInhibitorID(rawValue: 1)
            let secondID = KeyboardShortcutsInhibitorID(rawValue: 2)
            let keptID = KeyboardShortcutsInhibitorID(rawValue: 3)
            let firstWindowID = WindowID(rawValue: 10)
            let secondWindowID = WindowID(rawValue: 11)
            let keptWindowID = WindowID(rawValue: 12)

            try installKeyboardShortcutInhibitorForTesting(
                firstID,
                windowID: firstWindowID,
                seatID: removedSeatID,
                in: core
            )
            try installKeyboardShortcutInhibitorForTesting(
                secondID,
                windowID: secondWindowID,
                seatID: removedSeatID,
                in: core
            )
            try installKeyboardShortcutInhibitorForTesting(
                keptID,
                windowID: keptWindowID,
                seatID: keptSeatID,
                in: core
            )

            core.closeKeyboardShortcutsInhibitors(forSeat: removedSeatID)

            #expect(core.keyboardShortcutsInhibitorsByID[firstID] == nil)
            #expect(core.keyboardShortcutsInhibitorsByID[secondID] == nil)
            #expect(core.keyboardShortcutsInhibitorIDsBySeatID[removedSeatID] == nil)
            #expect(core.keyboardShortcutsInhibitorIDsByWindowID[firstWindowID] == nil)
            #expect(core.keyboardShortcutsInhibitorIDsByWindowID[secondWindowID] == nil)
            #expect(core.closedKeyboardShortcutsInhibitorIDs.contains(firstID))
            #expect(core.closedKeyboardShortcutsInhibitorIDs.contains(secondID))
            #expect(core.keyboardShortcutsInhibitorsByID[keptID] != nil)
            #expect(core.keyboardShortcutsInhibitorIDsBySeatID[keptSeatID] == [keptID])
            #expect(core.keyboardShortcutsInhibitorIDsByWindowID[keptWindowID] == [keptID])
        }
    }

    private func installKeyboardShortcutInhibitorForTesting(
        _ inhibitorID: KeyboardShortcutsInhibitorID,
        windowID: WindowID,
        seatID: SeatID,
        in core: DisplayCore
    ) throws {
        core.keyboardShortcutsInhibitorsByID[inhibitorID] =
            DisplayKeyboardShortcutsInhibitorRecord(
                id: inhibitorID,
                windowID: windowID,
                seatID: seatID,
                rawInhibitor: try rawKeyboardShortcutsInhibitorForTesting()
            )
        core.keyboardShortcutsInhibitorIDsByWindowID[windowID, default: []]
            .append(inhibitorID)
        core.keyboardShortcutsInhibitorIDsBySeatID[seatID, default: []].append(inhibitorID)
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
