import WaylandRaw

extension InputRouter {
    func routeTablet(_ rawEvent: RawInputEvent, _ tabletEvent: RawTabletEvent) -> InputEvent {
        switch tabletEvent {
        case .tabletAdded(let tablet):
            return routedTabletEvent(rawEvent, target: .display, .tabletAdded(TabletID(tablet)))
        case .toolAdded(let tool):
            return routedTabletEvent(rawEvent, target: .display, .toolAdded(TabletToolID(tool)))
        case .padAdded(let pad):
            return routedTabletEvent(rawEvent, target: .display, .padAdded(TabletPadID(pad)))
        case .tablet(let event):
            return routeTabletDeviceEvent(rawEvent, event)
        case .tool(let event):
            return routeTabletToolEvent(rawEvent, event)
        case .pad(let event):
            return routeTabletPadEvent(rawEvent, event)
        }
    }

    func routeTabletDeviceEvent(
        _ rawEvent: RawInputEvent,
        _ event: RawTabletDeviceEvent
    ) -> InputEvent {
        let routed: TabletDeviceEvent =
            switch event {
            case .name(let tablet, let name):
                .name(TabletID(tablet), name)
            case .id(let tablet, let vendorID, let productID):
                .id(TabletID(tablet), vendorID: vendorID, productID: productID)
            case .path(let tablet, let path):
                .path(TabletID(tablet), path)
            case .done(let tablet):
                .done(TabletID(tablet))
            case .removed(let tablet):
                .removed(TabletID(tablet))
            case .busType(let tablet, let busType):
                .busType(TabletID(tablet), TabletBusType(busType))
            }

        return routedTabletEvent(rawEvent, target: .display, .tablet(routed))
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func routeTabletToolEvent(
        _ rawEvent: RawInputEvent,
        _ event: RawTabletToolEvent
    ) -> InputEvent {
        switch event {
        case .type(let tool, let type):
            return routedTabletToolEvent(
                rawEvent, tool, .type(TabletToolID(tool), TabletToolType(type)))
        case .hardwareSerial(let tool, let serial):
            return routedTabletToolEvent(
                rawEvent, tool, .hardwareSerial(TabletToolID(tool), serial))
        case .hardwareIDWacom(let tool, let hardwareID):
            return routedTabletToolEvent(
                rawEvent, tool, .hardwareIDWacom(TabletToolID(tool), hardwareID))
        case .capability(let tool, let capability):
            return routedTabletToolEvent(
                rawEvent,
                tool,
                .capability(TabletToolID(tool), TabletToolCapability(capability))
            )
        case .done(let tool):
            return routedTabletToolEvent(rawEvent, tool, .done(TabletToolID(tool)))
        case .removed(let tool):
            tabletToolFocusByObjectID[tool.objectID] = nil
            return routedTabletToolEvent(rawEvent, tool, .removed(TabletToolID(tool)))
        case .proximityIn(let proximity):
            if let surfaceID = proximity.surfaceID {
                tabletToolFocusByObjectID[proximity.tool.objectID] = surfaceID
            }
            return routedTabletEvent(
                rawEvent,
                target: target(for: proximity.surfaceID),
                .tool(
                    .proximityIn(
                        TabletToolProximityIn(
                            tool: TabletToolID(proximity.tool),
                            serial: InputSerial(rawValue: proximity.serial),
                            tablet: TabletID(proximity.tablet)
                        )
                    )
                )
            )
        case .proximityOut(let tool):
            let surfaceID = tabletToolFocusByObjectID[tool.objectID]
            tabletToolFocusByObjectID[tool.objectID] = nil
            return routedTabletEvent(
                rawEvent,
                target: target(forFocusedSurface: surfaceID),
                .tool(.proximityOut(TabletToolID(tool)))
            )
        case .down(let tool, let serial):
            return routedTabletToolEvent(
                rawEvent,
                tool,
                .down(TabletToolID(tool), serial: InputSerial(rawValue: serial))
            )
        case .up(let tool):
            return routedTabletToolEvent(rawEvent, tool, .up(TabletToolID(tool)))
        case .motion(let tool, let x, let y):
            return routedTabletToolEvent(
                rawEvent,
                tool,
                .motion(TabletToolID(tool), PointerLocation(waylandX: x, waylandY: y))
            )
        case .pressure(let tool, let pressure):
            return routedTabletToolEvent(rawEvent, tool, .pressure(TabletToolID(tool), pressure))
        case .distance(let tool, let distance):
            return routedTabletToolEvent(rawEvent, tool, .distance(TabletToolID(tool), distance))
        case .tilt(let tool, let x, let y):
            return routedTabletToolEvent(
                rawEvent,
                tool,
                .tilt(TabletToolID(tool), x: x.doubleValue, y: y.doubleValue)
            )
        case .rotation(let tool, let degrees):
            return routedTabletToolEvent(
                rawEvent,
                tool,
                .rotation(TabletToolID(tool), degrees: degrees.doubleValue)
            )
        case .slider(let tool, let position):
            return routedTabletToolEvent(
                rawEvent, tool, .slider(TabletToolID(tool), position: position))
        case .wheel(let tool, let degrees, let clicks):
            return routedTabletToolEvent(
                rawEvent,
                tool,
                .wheel(TabletToolID(tool), degrees: degrees.doubleValue, clicks: clicks)
            )
        case .button(let button):
            return routedTabletToolEvent(
                rawEvent,
                button.tool,
                .button(
                    TabletToolButton(
                        tool: TabletToolID(button.tool),
                        serial: InputSerial(rawValue: button.serial),
                        button: PointerButtonCode(rawValue: button.button),
                        state: ButtonState(button.state)
                    )
                )
            )
        case .frame(let tool, let time):
            return routedTabletToolEvent(
                rawEvent,
                tool,
                .frame(TabletToolID(tool), time: WaylandTimestampMilliseconds(rawValue: time))
            )
        }
    }

    func routeTabletPadEvent(_ rawEvent: RawInputEvent, _ event: RawTabletPadEvent) -> InputEvent {
        switch event {
        case .path(let pad, let path):
            return routedTabletPadEvent(rawEvent, pad, .path(TabletPadID(pad), path))
        case .buttons(let pad, let count):
            return routedTabletPadEvent(rawEvent, pad, .buttons(TabletPadID(pad), count))
        case .done(let pad):
            return routedTabletPadEvent(rawEvent, pad, .done(TabletPadID(pad)))
        case .button(let button):
            return routedTabletPadEvent(
                rawEvent,
                button.pad,
                .button(
                    TabletPadButton(
                        pad: TabletPadID(button.pad),
                        time: WaylandTimestampMilliseconds(rawValue: button.time),
                        button: PointerButtonCode(rawValue: button.button),
                        state: ButtonState(button.state)
                    )
                )
            )
        case .enter(let enter):
            if let surfaceID = enter.surfaceID {
                tabletPadFocusByObjectID[enter.pad.objectID] = surfaceID
            }
            return routedTabletEvent(
                rawEvent,
                target: target(for: enter.surfaceID),
                .pad(
                    .enter(
                        TabletPadEnter(
                            pad: TabletPadID(enter.pad),
                            serial: InputSerial(rawValue: enter.serial),
                            tablet: TabletID(enter.tablet)
                        )
                    )
                )
            )
        case .leave(let leave):
            let surfaceID = tabletPadFocusByObjectID[leave.pad.objectID] ?? leave.surfaceID
            tabletPadFocusByObjectID[leave.pad.objectID] = nil
            return routedTabletEvent(
                rawEvent,
                target: target(forFocusedSurface: surfaceID),
                .pad(
                    .leave(
                        TabletPadLeave(
                            pad: TabletPadID(leave.pad),
                            serial: InputSerial(rawValue: leave.serial)
                        )
                    )
                )
            )
        case .removed(let pad):
            tabletPadFocusByObjectID[pad.objectID] = nil
            return routedTabletPadEvent(rawEvent, pad, .removed(TabletPadID(pad)))
        case .groupAdded(let pad):
            return routedTabletPadEvent(rawEvent, pad, .groupAdded(TabletPadID(pad)))
        }
    }

    func routedTabletToolEvent(
        _ rawEvent: RawInputEvent,
        _ tool: RawTabletToolIdentity,
        _ event: TabletToolEvent
    ) -> InputEvent {
        routedTabletEvent(
            rawEvent,
            target: target(forFocusedSurface: tabletToolFocusByObjectID[tool.objectID]),
            .tool(event)
        )
    }

    func routedTabletPadEvent(
        _ rawEvent: RawInputEvent,
        _ pad: RawTabletPadIdentity,
        _ event: TabletPadEvent
    ) -> InputEvent {
        routedTabletEvent(
            rawEvent,
            target: target(forFocusedSurface: tabletPadFocusByObjectID[pad.objectID]),
            .pad(event)
        )
    }

    func routedTabletEvent(
        _ rawEvent: RawInputEvent,
        target: InputEventTarget,
        _ event: TabletEvent
    ) -> InputEvent {
        routedEvent(rawEvent, target: target, kind: .tablet(event))
    }

    func clearTabletFocuses() {
        tabletToolFocusByObjectID.removeAll()
        tabletPadFocusByObjectID.removeAll()
    }

    func removeTabletFocuses(matching surfaceID: RawObjectID) {
        tabletToolFocusByObjectID = tabletToolFocusByObjectID.filter { _, focused in
            focused != surfaceID
        }
        tabletPadFocusByObjectID = tabletPadFocusByObjectID.filter { _, focused in
            focused != surfaceID
        }
    }
}
