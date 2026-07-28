import WaylandClient

extension ManagedSurfaceSmokeRun {
    func routeRedraw(for window: Window, color: UInt32) async throws {
        let skipsRoutingEvent = CommandLine.arguments.contains("--skip-redraw-routing")
        var events = display.events.makeAsyncIterator()
        try await window.requestRedraw()
        if skipsRoutingEvent {
            try await Task.sleep(for: .milliseconds(20))
        } else {
            try await requireRedraw(
                from: &events,
                surface: .window(window.id),
                label: "window redraw"
            )
        }
        let outcome = try await retryPresentation(label: "window redraw") {
            try await window.redraw { frame in
                drawManagedSurfaceFrame(frame, color: color)
            }
        }
        try requireRedrawPresented(outcome, label: "window redraw")
        print("redraw routing: window")
    }

    func routeRedraw(for popup: PopupSurface, color: UInt32) async throws {
        let skipsRoutingEvent = CommandLine.arguments.contains("--skip-redraw-routing")
        var events = display.events.makeAsyncIterator()
        try await popup.requestRedraw()
        if skipsRoutingEvent {
            try await Task.sleep(for: .milliseconds(20))
        } else {
            try await requireRedraw(
                from: &events,
                surface: .popup(popup.id),
                label: "popup redraw"
            )
        }
        let outcome = try await retryPresentation(label: "popup redraw") {
            try await popup.redraw { frame in
                drawManagedSurfaceFrame(frame, color: color)
            }
        }
        try requireRedrawPresented(outcome, label: "popup redraw")
        print("redraw routing: popup")
    }

    func routeRedraw(for subsurface: Subsurface, color: UInt32) async throws {
        let skipsRoutingEvent = CommandLine.arguments.contains("--skip-redraw-routing")
        var events = display.events.makeAsyncIterator()
        try await subsurface.requestRedraw()
        if skipsRoutingEvent {
            try await Task.sleep(for: .milliseconds(20))
        } else {
            try await requireRedraw(
                from: &events,
                surface: .subsurface(subsurface.identity),
                label: "subsurface redraw"
            )
        }
        let outcome = try await retryPresentation(label: "subsurface redraw") {
            try await subsurface.redraw { frame in
                drawManagedSurfaceFrame(frame, color: color)
            }
        }
        try requireRedrawPresented(outcome, label: "subsurface redraw")
        print("redraw routing: \(subsurface.identity)")
    }

    func finishPopup(_ popup: PopupSurface) async throws {
        var events = display.events.makeAsyncIterator()
        if CommandLine.arguments.contains("--interactive-dismissal") {
            print("popup dismissal: click outside the popup")
            while let event = try await events.next() {
                if case .popupDismissed(let lifecycle) = event,
                    lifecycle.popup == popup.id
                {
                    print("popup dismissal: compositor event observed")
                    await popup.close()
                    return
                }
            }
            throw ManagedSurfaceSmokeError.eventStreamEnded("popup dismissal")
        }

        await popup.close()
        while let event = try await events.next() {
            if case .popupClosed(let lifecycle) = event,
                lifecycle.popup == popup.id
            {
                print("popup cleanup: explicit close observed")
                return
            }
        }
        throw ManagedSurfaceSmokeError.eventStreamEnded("popup close")
    }

    private func requireRedraw(
        from iterator: inout DisplayEventsIterator,
        surface: ManagedSurfaceIdentity,
        label: String
    ) async throws {
        while let event = try await iterator.next() {
            if case .redrawRequested(let candidate) = event,
                candidate == surface
            {
                return
            }
        }
        throw ManagedSurfaceSmokeError.eventStreamEnded(label)
    }

    private func requireRedrawPresented(
        _ outcome: SoftwarePresentationOutcome,
        label: String
    ) throws {
        guard outcome == .presented else {
            throw ManagedSurfaceSmokeError.unexpectedPresentationOutcome(label, outcome)
        }
    }
}

nonisolated func drawManagedSurfaceFrame(
    _ frame: borrowing SoftwareFrame,
    color: UInt32
) {
    frame.withXRGB8888Rows { row, pixels in
        for index in 0..<pixels.count {
            let variation = UInt32((row + index) & 0x1F)
            unsafe pixels[unchecked: index] = color ^ variation
        }
    }
}
