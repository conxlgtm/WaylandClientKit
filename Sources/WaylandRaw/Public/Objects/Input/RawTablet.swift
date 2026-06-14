import CWaylandProtocols

// swiftlint:disable file_length type_body_length
@safe
package final class RawTabletManager {
    package let version: RawVersion

    private var proxy: RawOwnedProxy
    private let proxyAdoption: RawProxyAdoptionContext

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    package init(
        pointer managerPointer: OpaquePointer,
        version managerVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        version = managerVersion
        proxyAdoption = adoptionContext
        proxy = try RawOwnedProxy(
            adopting: managerPointer,
            interface: "zwp_tablet_manager_v2",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_zwp_tablet_manager_v2_destroy
        )
    }

    package func tabletSeat(
        for seat: RawSeat,
        eventSink: RawInputEventSink
    ) throws -> RawTabletSeat {
        guard
            let tabletSeat = unsafe swl_zwp_tablet_manager_v2_get_tablet_seat(
                pointer,
                seat.pointer
            )
        else {
            throw RuntimeError.bindFailed("zwp_tablet_seat_v2")
        }

        let adoptedSeat = try unsafe proxyAdoption.adoptOrDestroy(
            tabletSeat,
            interface: "zwp_tablet_seat_v2",
            destroy: unsafe swl_zwp_tablet_seat_v2_destroy
        )

        return try RawTabletSeat(
            pointer: adoptedSeat,
            version: version,
            seatID: seat.id,
            eventSink: eventSink,
            proxyAdoption: proxyAdoption
        )
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawTabletSeat {
    package let version: RawVersion
    package let seatID: RawSeatID

    private let proxyAdoption: RawProxyAdoptionContext
    private let eventSink: RawInputEventSink
    private let listenerOwner: RawTabletSeatOwner
    private var proxy: RawOwnedProxy
    private var tablets: [RawObjectID: RawTablet] = [:]
    private var tools: [RawObjectID: RawTabletTool] = [:]
    private var pads: [RawObjectID: RawTabletPad] = [:]

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(
        pointer tabletSeat: OpaquePointer,
        version tabletVersion: RawVersion,
        seatID tabletSeatID: RawSeatID,
        eventSink tabletEventSink: RawInputEventSink,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        version = tabletVersion
        seatID = tabletSeatID
        eventSink = tabletEventSink
        proxyAdoption = adoptionContext
        proxy = RawOwnedProxy(
            pointer: tabletSeat,
            destroy: unsafe swl_zwp_tablet_seat_v2_destroy
        )
        listenerOwner = RawTabletSeatOwner(
            seatID: tabletSeatID,
            invariantFailureSink: adoptionContext.invariantFailureSink
        )
        unsafe listenerOwner.onTabletAdded = { [weak self] tabletPointer in
            self?.handleTabletAdded(tabletPointer)
        }
        unsafe listenerOwner.onToolAdded = { [weak self] toolPointer in
            self?.handleToolAdded(toolPointer)
        }
        unsafe listenerOwner.onPadAdded = { [weak self] padPointer in
            self?.handlePadAdded(padPointer)
        }
        try unsafe listenerOwner.install(on: tabletSeat)
    }

    package func destroy() {
        listenerOwner.cancel()

        for pad in pads.values {
            pad.destroy()
        }
        pads.removeAll()
        for tool in tools.values {
            tool.destroy()
        }
        tools.removeAll()
        for tablet in tablets.values {
            tablet.destroy()
        }
        tablets.removeAll()

        proxy.destroy()
    }

    @safe
    private func handleTabletAdded(_ tabletPointer: OpaquePointer) {
        do {
            let tablet = try RawTablet(
                pointer: unsafe proxyAdoption.adoptOrDestroy(
                    tabletPointer,
                    interface: "zwp_tablet_v2",
                    destroy: unsafe swl_zwp_tablet_v2_destroy
                ),
                version: version,
                seatID: seatID,
                eventSink: eventSink,
                proxyAdoption: proxyAdoption
            )
            tablets[tablet.identity.objectID] = tablet
            append(.tabletAdded(tablet.identity))
        } catch {
            appendListenerDiagnostic(listener: "zwp_tablet_v2", error: error)
        }
    }

    @safe
    private func handleToolAdded(_ toolPointer: OpaquePointer) {
        do {
            let tool = try RawTabletTool(
                pointer: unsafe proxyAdoption.adoptOrDestroy(
                    toolPointer,
                    interface: "zwp_tablet_tool_v2",
                    destroy: unsafe swl_zwp_tablet_tool_v2_destroy
                ),
                version: version,
                seatID: seatID,
                eventSink: eventSink,
                proxyAdoption: proxyAdoption
            )
            tools[tool.identity.objectID] = tool
            append(.toolAdded(tool.identity))
        } catch {
            appendListenerDiagnostic(listener: "zwp_tablet_tool_v2", error: error)
        }
    }

    @safe
    private func handlePadAdded(_ padPointer: OpaquePointer) {
        do {
            let pad = try RawTabletPad(
                pointer: unsafe proxyAdoption.adoptOrDestroy(
                    padPointer,
                    interface: "zwp_tablet_pad_v2",
                    destroy: unsafe swl_zwp_tablet_pad_v2_destroy
                ),
                version: version,
                seatID: seatID,
                eventSink: eventSink,
                proxyAdoption: proxyAdoption
            )
            pads[pad.identity.objectID] = pad
            append(.padAdded(pad.identity))
        } catch {
            appendListenerDiagnostic(listener: "zwp_tablet_pad_v2", error: error)
        }
    }

    private func append(_ event: RawTabletEvent) {
        eventSink.append(
            RawInputEventDraft(
                seatID: seatID,
                deviceID: RawInputDeviceID(seatID: seatID, kind: .tablet, generation: 1),
                kind: .tablet(event)
            )
        )
    }

    private func appendListenerDiagnostic(listener: String, error: any Error) {
        eventSink.append(
            RawInputEventDraft.diagnostic(
                seatID: seatID,
                deviceID: RawInputDeviceID(seatID: seatID, kind: .tablet, generation: 1),
                .listener(
                    RawListenerDiagnostic(
                        listener: listener,
                        message: String(describing: error)
                    )
                )
            )
        )
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawTablet {
    package let version: RawVersion
    package let identity: RawTabletIdentity

    private let listenerOwner: RawTabletOwner
    private var proxy: RawOwnedProxy

    @safe
    init(
        pointer tabletPointer: OpaquePointer,
        version tabletVersion: RawVersion,
        seatID tabletSeatID: RawSeatID,
        eventSink tabletEventSink: RawInputEventSink,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        version = tabletVersion
        identity = RawTabletIdentity(objectID: unsafe objectID(of: tabletPointer))
        proxy = RawOwnedProxy(pointer: tabletPointer, destroy: unsafe swl_zwp_tablet_v2_destroy)
        listenerOwner = RawTabletOwner(
            identity: identity,
            seatID: tabletSeatID,
            eventSink: tabletEventSink,
            invariantFailureSink: adoptionContext.invariantFailureSink
        )
        try unsafe listenerOwner.install(on: tabletPointer)
    }

    package func destroy() {
        listenerOwner.cancel()
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawTabletTool {
    package let version: RawVersion
    package let identity: RawTabletToolIdentity

    private let listenerOwner: RawTabletToolOwner
    private var proxy: RawOwnedProxy

    @safe
    init(
        pointer toolPointer: OpaquePointer,
        version toolVersion: RawVersion,
        seatID toolSeatID: RawSeatID,
        eventSink toolEventSink: RawInputEventSink,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        version = toolVersion
        identity = RawTabletToolIdentity(objectID: unsafe objectID(of: toolPointer))
        proxy = RawOwnedProxy(pointer: toolPointer, destroy: unsafe swl_zwp_tablet_tool_v2_destroy)
        listenerOwner = RawTabletToolOwner(
            identity: identity,
            seatID: toolSeatID,
            eventSink: toolEventSink,
            invariantFailureSink: adoptionContext.invariantFailureSink
        )
        try unsafe listenerOwner.install(on: toolPointer)
    }

    package func destroy() {
        listenerOwner.cancel()
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawTabletPad {
    package let version: RawVersion
    package let identity: RawTabletPadIdentity

    private let listenerOwner: RawTabletPadOwner
    private var proxy: RawOwnedProxy
    private var groups: [RawTabletPadGroup] = []

    @safe
    init(
        pointer padPointer: OpaquePointer,
        version padVersion: RawVersion,
        seatID padSeatID: RawSeatID,
        eventSink padEventSink: RawInputEventSink,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        version = padVersion
        identity = RawTabletPadIdentity(objectID: unsafe objectID(of: padPointer))
        proxy = RawOwnedProxy(pointer: padPointer, destroy: unsafe swl_zwp_tablet_pad_v2_destroy)
        listenerOwner = RawTabletPadOwner(
            identity: identity,
            seatID: padSeatID,
            eventSink: padEventSink,
            proxyAdoption: adoptionContext
        )
        unsafe listenerOwner.onGroupAdded = { [weak self] groupPointer in
            self?.adoptGroup(groupPointer)
        }
        try unsafe listenerOwner.install(on: padPointer)
    }

    package func destroy() {
        listenerOwner.cancel()
        for group in groups {
            group.destroy()
        }
        groups.removeAll()
        proxy.destroy()
    }

    @safe
    private func adoptGroup(_ groupPointer: OpaquePointer) {
        do {
            let group = try unsafe RawTabletPadGroup(
                pointer: groupPointer,
                proxyAdoption: listenerOwner.proxyAdoption
            )
            groups.append(group)
        } catch {
            listenerOwner.appendListenerDiagnostic(listener: "zwp_tablet_pad_group_v2", error: error)
        }
    }

    deinit {
        destroy()
    }
}

private func objectID(of pointer: OpaquePointer) -> RawObjectID {
    unsafe RawObjectID(swl_proxy_get_id(UnsafeMutableRawPointer(pointer)))
}

private func combineHighLow(_ high: UInt32, _ low: UInt32) -> UInt64 {
    (UInt64(high) << 32) | UInt64(low)
}

@safe
private final class RawTabletPadGroup {
    private var proxy: RawOwnedProxy

    init(
        pointer groupPointer: OpaquePointer,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        proxy = try RawOwnedProxy(
            adopting: groupPointer,
            interface: "zwp_tablet_pad_group_v2",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_zwp_tablet_pad_group_v2_destroy
        )
    }

    func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

@safe
private final class RawTabletSeatOwner {
    let seatID: RawSeatID
    var onTabletAdded: ((OpaquePointer) -> Void)?
    var onToolAdded: ((OpaquePointer) -> Void)?
    var onPadAdded: ((OpaquePointer) -> Void)?

    private let invariantFailureSink: RawInvariantFailureSink?
    private var isCanceled = false
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_zwp_tablet_seat_v2_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks:
        UnsafeMutablePointer<swl_zwp_tablet_seat_v2_listener_callbacks>
    {
        listenerStorage.callbacks
    }

    init(seatID ownerSeatID: RawSeatID, invariantFailureSink failureSink: RawInvariantFailureSink?) {
        seatID = ownerSeatID
        invariantFailureSink = failureSink

        unsafe callbacks.pointee.tablet_added = { data, _, tablet in
            RawTabletSeatOwner.withOwner(data, message: "tablet_added without Swift state") {
                owner in
                guard !owner.isCanceled, let tablet = unsafe tablet else { return }
                unsafe owner.onTabletAdded?(tablet)
            }
        }
        unsafe callbacks.pointee.tool_added = { data, _, tool in
            RawTabletSeatOwner.withOwner(data, message: "tool_added without Swift state") {
                owner in
                guard !owner.isCanceled, let tool = unsafe tool else { return }
                unsafe owner.onToolAdded?(tool)
            }
        }
        unsafe callbacks.pointee.pad_added = { data, _, pad in
            RawTabletSeatOwner.withOwner(data, message: "pad_added without Swift state") {
                owner in
                guard !owner.isCanceled, let pad = unsafe pad else { return }
                unsafe owner.onPadAdded?(pad)
            }
        }
    }

    func install(on tabletSeat: OpaquePointer) throws(RuntimeError) {
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer
        let result = unsafe swl_zwp_tablet_seat_v2_add_listener(tabletSeat, callbacks)
        guard result == 0 else {
            throw RuntimeError.listenerInstallFailed("zwp_tablet_seat_v2")
        }
    }

    func cancel() {
        isCanceled = true
        listenerStorage.invalidate()
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (RawTabletSeatOwner) -> Void
    ) {
        CListenerStorage<RawTabletSeatOwner, swl_zwp_tablet_seat_v2_listener_callbacks>
            .withOwner(from: data, message: message(), body)
    }
}

@safe
private final class RawTabletOwner {
    private let identity: RawTabletIdentity
    private let seatID: RawSeatID
    private let eventSink: RawInputEventSink
    private let invariantFailureSink: RawInvariantFailureSink?
    private var isCanceled = false
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_zwp_tablet_v2_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks: UnsafeMutablePointer<swl_zwp_tablet_v2_listener_callbacks> {
        listenerStorage.callbacks
    }

    init(
        identity tabletIdentity: RawTabletIdentity,
        seatID tabletSeatID: RawSeatID,
        eventSink tabletEventSink: RawInputEventSink,
        invariantFailureSink failureSink: RawInvariantFailureSink?
    ) {
        identity = tabletIdentity
        seatID = tabletSeatID
        eventSink = tabletEventSink
        invariantFailureSink = failureSink

        unsafe callbacks.pointee.name = { data, _, name in
            RawTabletOwner.withOwner(data, message: "tablet name without Swift state") { owner in
                guard let name = unsafe name else { return }
                owner.append(.tablet(.name(owner.identity, unsafe String(cString: name))))
            }
        }
        unsafe callbacks.pointee.id = { data, _, vendorID, productID in
            RawTabletOwner.withOwner(data, message: "tablet id without Swift state") { owner in
                owner.append(.tablet(.id(owner.identity, vendorID: vendorID, productID: productID)))
            }
        }
        unsafe callbacks.pointee.path = { data, _, path in
            RawTabletOwner.withOwner(data, message: "tablet path without Swift state") { owner in
                guard let path = unsafe path else { return }
                owner.append(.tablet(.path(owner.identity, unsafe String(cString: path))))
            }
        }
        unsafe callbacks.pointee.done = { data, _ in
            RawTabletOwner.withOwner(data, message: "tablet done without Swift state") { owner in
                owner.append(.tablet(.done(owner.identity)))
            }
        }
        unsafe callbacks.pointee.removed = { data, _ in
            RawTabletOwner.withOwner(data, message: "tablet removed without Swift state") { owner in
                owner.append(.tablet(.removed(owner.identity)))
            }
        }
        unsafe callbacks.pointee.bustype = { data, _, busType in
            RawTabletOwner.withOwner(data, message: "tablet bustype without Swift state") {
                owner in
                owner.append(.tablet(.busType(owner.identity, RawTabletBusType(rawValue: busType))))
            }
        }
    }

    func install(on tablet: OpaquePointer) throws(RuntimeError) {
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer
        let result = unsafe swl_zwp_tablet_v2_add_listener(tablet, callbacks)
        guard result == 0 else {
            throw RuntimeError.listenerInstallFailed("zwp_tablet_v2")
        }
    }

    func cancel() {
        isCanceled = true
        listenerStorage.invalidate()
    }

    func append(_ event: RawTabletEvent) {
        guard !isCanceled else { return }
        eventSink.append(
            RawInputEventDraft(
                seatID: seatID,
                deviceID: RawInputDeviceID(seatID: seatID, kind: .tablet, generation: 1),
                kind: .tablet(event)
            )
        )
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (RawTabletOwner) -> Void
    ) {
        CListenerStorage<RawTabletOwner, swl_zwp_tablet_v2_listener_callbacks>
            .withOwner(from: data, message: message(), body)
    }
}

@safe
private final class RawTabletToolOwner {
    private let identity: RawTabletToolIdentity
    private let seatID: RawSeatID
    private let eventSink: RawInputEventSink
    private let invariantFailureSink: RawInvariantFailureSink?
    private var isCanceled = false
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_zwp_tablet_tool_v2_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks:
        UnsafeMutablePointer<swl_zwp_tablet_tool_v2_listener_callbacks>
    {
        listenerStorage.callbacks
    }

    // swiftlint:disable:next function_body_length
    init(
        identity toolIdentity: RawTabletToolIdentity,
        seatID toolSeatID: RawSeatID,
        eventSink toolEventSink: RawInputEventSink,
        invariantFailureSink failureSink: RawInvariantFailureSink?
    ) {
        identity = toolIdentity
        seatID = toolSeatID
        eventSink = toolEventSink
        invariantFailureSink = failureSink

        unsafe callbacks.pointee.type = { data, _, type in
            RawTabletToolOwner.withOwner(data, message: "tablet tool type without Swift state") {
                owner in
                owner.append(.tool(.type(owner.identity, RawTabletToolType(rawValue: type))))
            }
        }
        unsafe callbacks.pointee.hardware_serial = { data, _, high, low in
            RawTabletToolOwner.withOwner(
                data,
                message: "tablet tool hardware serial without Swift state"
            ) { owner in
                owner.append(.tool(.hardwareSerial(owner.identity, combineHighLow(high, low))))
            }
        }
        unsafe callbacks.pointee.hardware_id_wacom = { data, _, high, low in
            RawTabletToolOwner.withOwner(
                data,
                message: "tablet tool hardware id without Swift state"
            ) { owner in
                owner.append(.tool(.hardwareIDWacom(owner.identity, combineHighLow(high, low))))
            }
        }
        unsafe callbacks.pointee.capability = { data, _, capability in
            RawTabletToolOwner.withOwner(
                data,
                message: "tablet tool capability without Swift state"
            ) { owner in
                owner.append(
                    .tool(
                        .capability(
                            owner.identity,
                            RawTabletToolCapability(rawValue: capability)
                        )
                    )
                )
            }
        }
        unsafe callbacks.pointee.done = { data, _ in
            RawTabletToolOwner.withOwner(data, message: "tablet tool done without Swift state") {
                owner in
                owner.append(.tool(.done(owner.identity)))
            }
        }
        unsafe callbacks.pointee.removed = { data, _ in
            RawTabletToolOwner.withOwner(data, message: "tablet tool removed without Swift state") {
                owner in
                owner.append(.tool(.removed(owner.identity)))
            }
        }
        unsafe callbacks.pointee.proximity_in = { data, _, serial, tablet, surface in
            RawTabletToolOwner.withOwner(
                data,
                message: "tablet tool proximity_in without Swift state"
            ) { owner in
                guard let tablet = unsafe tablet else { return }
                owner.append(
                    .tool(
                        .proximityIn(
                            RawTabletToolProximityIn(
                                tool: owner.identity,
                                serial: serial,
                                tablet: RawTabletIdentity(objectID: unsafe objectID(of: tablet)),
                                surfaceID: unsafe surface.map { unsafe objectID(of: $0) }
                            )
                        )
                    )
                )
            }
        }
        unsafe callbacks.pointee.proximity_out = { data, _ in
            RawTabletToolOwner.withOwner(
                data,
                message: "tablet tool proximity_out without Swift state"
            ) { owner in
                owner.append(.tool(.proximityOut(owner.identity)))
            }
        }
        unsafe callbacks.pointee.down = { data, _, serial in
            RawTabletToolOwner.withOwner(data, message: "tablet tool down without Swift state") {
                owner in
                owner.append(.tool(.down(owner.identity, serial: serial)))
            }
        }
        unsafe callbacks.pointee.up = { data, _ in
            RawTabletToolOwner.withOwner(data, message: "tablet tool up without Swift state") {
                owner in
                owner.append(.tool(.up(owner.identity)))
            }
        }
        unsafe callbacks.pointee.motion = { data, _, x, y in
            RawTabletToolOwner.withOwner(data, message: "tablet tool motion without Swift state") {
                owner in
                owner.append(
                    .tool(
                        .motion(
                            owner.identity,
                            x: WaylandFixed(rawValue: x),
                            y: WaylandFixed(rawValue: y)
                        )
                    )
                )
            }
        }
        unsafe callbacks.pointee.pressure = { data, _, pressure in
            RawTabletToolOwner.withOwner(data, message: "tablet tool pressure without Swift state") {
                owner in
                owner.append(.tool(.pressure(owner.identity, pressure)))
            }
        }
        unsafe callbacks.pointee.distance = { data, _, distance in
            RawTabletToolOwner.withOwner(data, message: "tablet tool distance without Swift state") {
                owner in
                owner.append(.tool(.distance(owner.identity, distance)))
            }
        }
        unsafe callbacks.pointee.tilt = { data, _, x, y in
            RawTabletToolOwner.withOwner(data, message: "tablet tool tilt without Swift state") {
                owner in
                owner.append(
                    .tool(
                        .tilt(
                            owner.identity,
                            x: WaylandFixed(rawValue: x),
                            y: WaylandFixed(rawValue: y)
                        )
                    )
                )
            }
        }
        unsafe callbacks.pointee.rotation = { data, _, degrees in
            RawTabletToolOwner.withOwner(data, message: "tablet tool rotation without Swift state") {
                owner in
                owner.append(.tool(.rotation(owner.identity, degrees: WaylandFixed(rawValue: degrees))))
            }
        }
        unsafe callbacks.pointee.slider = { data, _, position in
            RawTabletToolOwner.withOwner(data, message: "tablet tool slider without Swift state") {
                owner in
                owner.append(.tool(.slider(owner.identity, position: position)))
            }
        }
        unsafe callbacks.pointee.wheel = { data, _, degrees, clicks in
            RawTabletToolOwner.withOwner(data, message: "tablet tool wheel without Swift state") {
                owner in
                owner.append(
                    .tool(
                        .wheel(
                            owner.identity,
                            degrees: WaylandFixed(rawValue: degrees),
                            clicks: clicks
                        )
                    )
                )
            }
        }
        unsafe callbacks.pointee.button = { data, _, serial, button, state in
            RawTabletToolOwner.withOwner(data, message: "tablet tool button without Swift state") {
                owner in
                owner.append(
                    .tool(
                        .button(
                            RawTabletToolButton(
                                tool: owner.identity,
                                serial: serial,
                                button: button,
                                state: RawPointerButtonState(rawValue: state)
                            )
                        )
                    )
                )
            }
        }
        unsafe callbacks.pointee.frame = { data, _, time in
            RawTabletToolOwner.withOwner(data, message: "tablet tool frame without Swift state") {
                owner in
                owner.append(.tool(.frame(owner.identity, time: time)))
            }
        }
    }

    func install(on tool: OpaquePointer) throws(RuntimeError) {
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer
        let result = unsafe swl_zwp_tablet_tool_v2_add_listener(tool, callbacks)
        guard result == 0 else {
            throw RuntimeError.listenerInstallFailed("zwp_tablet_tool_v2")
        }
    }

    func cancel() {
        isCanceled = true
        listenerStorage.invalidate()
    }

    func append(_ event: RawTabletEvent) {
        guard !isCanceled else { return }
        eventSink.append(
            RawInputEventDraft(
                seatID: seatID,
                deviceID: RawInputDeviceID(seatID: seatID, kind: .tablet, generation: 1),
                kind: .tablet(event)
            )
        )
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (RawTabletToolOwner) -> Void
    ) {
        CListenerStorage<RawTabletToolOwner, swl_zwp_tablet_tool_v2_listener_callbacks>
            .withOwner(from: data, message: message(), body)
    }
}

@safe
private final class RawTabletPadOwner {
    let proxyAdoption: RawProxyAdoptionContext
    var onGroupAdded: ((OpaquePointer) -> Void)?

    private let identity: RawTabletPadIdentity
    private let seatID: RawSeatID
    private let eventSink: RawInputEventSink
    private var isCanceled = false
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_zwp_tablet_pad_v2_listener_callbacks(),
        invariantFailureSink: proxyAdoption.invariantFailureSink
    )

    @safe private var callbacks: UnsafeMutablePointer<swl_zwp_tablet_pad_v2_listener_callbacks> {
        listenerStorage.callbacks
    }

    // swiftlint:disable:next function_body_length
    init(
        identity padIdentity: RawTabletPadIdentity,
        seatID padSeatID: RawSeatID,
        eventSink padEventSink: RawInputEventSink,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) {
        identity = padIdentity
        seatID = padSeatID
        eventSink = padEventSink
        proxyAdoption = adoptionContext

        unsafe callbacks.pointee.group = { data, _, group in
            RawTabletPadOwner.withOwner(data, message: "tablet pad group without Swift state") {
                owner in
                guard !owner.isCanceled, let group = unsafe group else { return }
                owner.append(.pad(.groupAdded(owner.identity)))
                unsafe owner.onGroupAdded?(group)
            }
        }
        unsafe callbacks.pointee.path = { data, _, path in
            RawTabletPadOwner.withOwner(data, message: "tablet pad path without Swift state") {
                owner in
                guard let path = unsafe path else { return }
                owner.append(.pad(.path(owner.identity, unsafe String(cString: path))))
            }
        }
        unsafe callbacks.pointee.buttons = { data, _, buttons in
            RawTabletPadOwner.withOwner(data, message: "tablet pad buttons without Swift state") {
                owner in
                owner.append(.pad(.buttons(owner.identity, buttons)))
            }
        }
        unsafe callbacks.pointee.done = { data, _ in
            RawTabletPadOwner.withOwner(data, message: "tablet pad done without Swift state") {
                owner in
                owner.append(.pad(.done(owner.identity)))
            }
        }
        unsafe callbacks.pointee.button = { data, _, time, button, state in
            RawTabletPadOwner.withOwner(data, message: "tablet pad button without Swift state") {
                owner in
                owner.append(
                    .pad(
                        .button(
                            RawTabletPadButton(
                                pad: owner.identity,
                                time: time,
                                button: button,
                                state: RawPointerButtonState(rawValue: state)
                            )
                        )
                    )
                )
            }
        }
        unsafe callbacks.pointee.enter = { data, _, serial, tablet, surface in
            RawTabletPadOwner.withOwner(data, message: "tablet pad enter without Swift state") {
                owner in
                guard let tablet = unsafe tablet else { return }
                owner.append(
                    .pad(
                        .enter(
                            RawTabletPadEnter(
                                pad: owner.identity,
                                serial: serial,
                                tablet: RawTabletIdentity(objectID: unsafe objectID(of: tablet)),
                                surfaceID: unsafe surface.map { unsafe objectID(of: $0) }
                            )
                        )
                    )
                )
            }
        }
        unsafe callbacks.pointee.leave = { data, _, serial, surface in
            RawTabletPadOwner.withOwner(data, message: "tablet pad leave without Swift state") {
                owner in
                owner.append(
                    .pad(
                        .leave(
                            RawTabletPadLeave(
                                pad: owner.identity,
                                serial: serial,
                                surfaceID: unsafe surface.map { unsafe objectID(of: $0) }
                            )
                        )
                    )
                )
            }
        }
        unsafe callbacks.pointee.removed = { data, _ in
            RawTabletPadOwner.withOwner(data, message: "tablet pad removed without Swift state") {
                owner in
                owner.append(.pad(.removed(owner.identity)))
            }
        }
    }

    func install(on pad: OpaquePointer) throws(RuntimeError) {
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer
        let result = unsafe swl_zwp_tablet_pad_v2_add_listener(pad, callbacks)
        guard result == 0 else {
            throw RuntimeError.listenerInstallFailed("zwp_tablet_pad_v2")
        }
    }

    func cancel() {
        isCanceled = true
        listenerStorage.invalidate()
    }

    func append(_ event: RawTabletEvent) {
        guard !isCanceled else { return }
        eventSink.append(
            RawInputEventDraft(
                seatID: seatID,
                deviceID: RawInputDeviceID(seatID: seatID, kind: .tablet, generation: 1),
                kind: .tablet(event)
            )
        )
    }

    func appendListenerDiagnostic(listener: String, error: any Error) {
        guard !isCanceled else { return }
        eventSink.append(
            RawInputEventDraft.diagnostic(
                seatID: seatID,
                deviceID: RawInputDeviceID(seatID: seatID, kind: .tablet, generation: 1),
                .listener(
                    RawListenerDiagnostic(
                        listener: listener,
                        message: String(describing: error)
                    )
                )
            )
        )
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (RawTabletPadOwner) -> Void
    ) {
        CListenerStorage<RawTabletPadOwner, swl_zwp_tablet_pad_v2_listener_callbacks>
            .withOwner(from: data, message: message(), body)
    }
}
