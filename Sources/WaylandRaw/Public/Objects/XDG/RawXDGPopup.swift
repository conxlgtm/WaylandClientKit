import CWaylandProtocols

package struct RawXDGPositionerAnchor: Equatable, Sendable {
    package let rawValue: UInt32

    package init(rawValue anchorRawValue: UInt32) {
        rawValue = anchorRawValue
    }

    package static let none = Self(rawValue: 0)
    package static let top = Self(rawValue: 1)
    package static let bottom = Self(rawValue: 2)
    package static let left = Self(rawValue: 3)
    package static let right = Self(rawValue: 4)
    package static let topLeft = Self(rawValue: 5)
    package static let bottomLeft = Self(rawValue: 6)
    package static let topRight = Self(rawValue: 7)
    package static let bottomRight = Self(rawValue: 8)
}

package struct RawXDGPositionerGravity: Equatable, Sendable {
    package let rawValue: UInt32

    package init(rawValue gravityRawValue: UInt32) {
        rawValue = gravityRawValue
    }

    package static let none = Self(rawValue: 0)
    package static let top = Self(rawValue: 1)
    package static let bottom = Self(rawValue: 2)
    package static let left = Self(rawValue: 3)
    package static let right = Self(rawValue: 4)
    package static let topLeft = Self(rawValue: 5)
    package static let bottomLeft = Self(rawValue: 6)
    package static let topRight = Self(rawValue: 7)
    package static let bottomRight = Self(rawValue: 8)
}

package struct RawXDGPositionerConstraintAdjustment: OptionSet, Sendable {
    package let rawValue: UInt32

    package init(rawValue adjustmentRawValue: UInt32) {
        rawValue = adjustmentRawValue
    }

    package static let none = Self([])
    package static let slideX = Self(rawValue: 1)
    package static let slideY = Self(rawValue: 2)
    package static let flipX = Self(rawValue: 4)
    package static let flipY = Self(rawValue: 8)
    package static let resizeX = Self(rawValue: 16)
    package static let resizeY = Self(rawValue: 32)
}

@safe
package final class RawXDGPositioner {
    @safe let pointer: OpaquePointer
    package let version: RawVersion

    private var isDestroyed = false

    @safe
    init(
        pointer positionerPointer: OpaquePointer,
        version positionerVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        do {
            pointer = try adoptionContext.adopt(positionerPointer, interface: "xdg_positioner")
        } catch {
            unsafe swl_xdg_positioner_destroy(positionerPointer)
            throw error
        }
        version = positionerVersion
    }

    package func setSize(width: Int32, height: Int32) {
        unsafe swl_xdg_positioner_set_size(pointer, width, height)
    }

    package func setAnchorRect(x: Int32, y: Int32, width: Int32, height: Int32) {
        unsafe swl_xdg_positioner_set_anchor_rect(pointer, x, y, width, height)
    }

    package func setAnchor(_ anchor: RawXDGPositionerAnchor) {
        unsafe swl_xdg_positioner_set_anchor(pointer, anchor.rawValue)
    }

    package func setGravity(_ gravity: RawXDGPositionerGravity) {
        unsafe swl_xdg_positioner_set_gravity(pointer, gravity.rawValue)
    }

    package func setConstraintAdjustment(
        _ adjustment: RawXDGPositionerConstraintAdjustment
    ) {
        unsafe swl_xdg_positioner_set_constraint_adjustment(pointer, adjustment.rawValue)
    }

    package func setOffset(x: Int32, y: Int32) {
        unsafe swl_xdg_positioner_set_offset(pointer, x, y)
    }

    package func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        unsafe swl_xdg_positioner_destroy(pointer)
    }

    deinit {
        destroy()
    }
}

package struct RawXDGPopupConfigure: Equatable, Sendable {
    package let x: Int32
    package let y: Int32
    package let width: Int32
    package let height: Int32

    package init(
        x configureX: Int32,
        y configureY: Int32,
        width configureWidth: Int32,
        height configureHeight: Int32
    ) {
        x = configureX
        y = configureY
        width = configureWidth
        height = configureHeight
    }
}

@safe
package final class RawXDGPopup {
    @safe let pointer: OpaquePointer
    package let version: RawVersion

    private var isDestroyed = false

    @safe
    init(
        pointer popupPointer: OpaquePointer,
        version popupVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        do {
            pointer = try adoptionContext.adopt(popupPointer, interface: "xdg_popup")
        } catch {
            unsafe swl_xdg_popup_destroy(popupPointer)
            throw error
        }
        version = popupVersion
    }

    package func grab(seat: RawSeat, serial: UInt32) {
        unsafe swl_xdg_popup_grab(pointer, seat.pointer, serial)
    }

    package func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        unsafe swl_xdg_popup_destroy(pointer)
    }

    deinit {
        destroy()
    }
}

@safe
package final class XDGPopupOwner {
    private let onConfigure: (RawXDGPopupConfigure) -> Void
    private let onPopupDone: () -> Void
    private let onRepositioned: (UInt32) -> Void
    private let invariantFailureSink: RawInvariantFailureSink?
    private var installState = ListenerInstallState.idle
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_xdg_popup_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks: UnsafeMutablePointer<swl_xdg_popup_listener_callbacks> {
        listenerStorage.callbacks
    }

    package init(
        onConfigure configureHandler: @escaping (RawXDGPopupConfigure) -> Void,
        onPopupDone popupDoneHandler: @escaping () -> Void,
        onRepositioned repositionedHandler: @escaping (UInt32) -> Void = { _ in
            // Reposition notifications are optional for callers that only need base popup events.
        },
        invariantFailureSink failureSink: RawInvariantFailureSink? = nil
    ) {
        onConfigure = configureHandler
        onPopupDone = popupDoneHandler
        onRepositioned = repositionedHandler
        invariantFailureSink = failureSink

        unsafe callbacks.pointee.configure = { data, _, x, y, width, height in
            XDGPopupOwner.withOwner(
                data,
                message: "xdg_popup configure fired without Swift state"
            ) { owner in
                owner.onConfigure(
                    RawXDGPopupConfigure(
                        x: x,
                        y: y,
                        width: width,
                        height: height
                    )
                )
            }
        }

        unsafe callbacks.pointee.popup_done = { data, _ in
            XDGPopupOwner.withOwner(
                data,
                message: "xdg_popup popup_done fired without Swift state"
            ) { owner in
                owner.onPopupDone()
            }
        }

        unsafe callbacks.pointee.repositioned = { data, _, token in
            XDGPopupOwner.withOwner(
                data,
                message: "xdg_popup repositioned fired without Swift state"
            ) { owner in
                owner.onRepositioned(token)
            }
        }
    }

    package func install(on popup: RawXDGPopup) throws {
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer

        try installState.install(interface: "xdg_popup") {
            unsafe swl_xdg_popup_add_listener(
                popup.pointer,
                callbacks
            )
        }
    }

    package func cancel() {
        listenerStorage.invalidate()
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (XDGPopupOwner) -> Void
    ) {
        CListenerStorage<XDGPopupOwner, swl_xdg_popup_listener_callbacks>
            .withOwner(from: data, message: message(), body)
    }
}
