import CWaylandProtocols
import Glibc

package struct RawOutputPointerIdentity: Hashable, Sendable {
    package let rawValue: UInt

    @safe
    package init(_ pointer: OpaquePointer) {
        unsafe rawValue = UInt(bitPattern: UnsafeMutableRawPointer(pointer))
    }
}

package struct RawOutputGeometry: Equatable, Sendable {
    package let x: Int32
    package let y: Int32
    package let physicalWidthMillimeters: Int32
    package let physicalHeightMillimeters: Int32
    package let subpixel: Int32
    package let make: String?
    package let model: String?
    package let transform: Int32

    package init(
        x outputX: Int32,
        y outputY: Int32,
        physicalWidthMillimeters outputPhysicalWidthMillimeters: Int32,
        physicalHeightMillimeters outputPhysicalHeightMillimeters: Int32,
        subpixel outputSubpixel: Int32,
        make outputMake: String?,
        model outputModel: String?,
        transform outputTransform: Int32
    ) {
        x = outputX
        y = outputY
        physicalWidthMillimeters = outputPhysicalWidthMillimeters
        physicalHeightMillimeters = outputPhysicalHeightMillimeters
        subpixel = outputSubpixel
        make = outputMake
        model = outputModel
        transform = outputTransform
    }
}

package struct RawOutputMode: Equatable, Sendable {
    package let flags: UInt32
    package let width: Int32
    package let height: Int32
    package let refreshMilliHertz: Int32

    package init(
        flags outputFlags: UInt32,
        width outputWidth: Int32,
        height outputHeight: Int32,
        refreshMilliHertz outputRefreshMilliHertz: Int32
    ) {
        flags = outputFlags
        width = outputWidth
        height = outputHeight
        refreshMilliHertz = outputRefreshMilliHertz
    }

    package var isValidCurrentMode: Bool {
        flags & 0x1 != 0 && width > 0 && height > 0 && refreshMilliHertz >= 0
    }
}

package struct RawOutputLogicalGeometry: Equatable, Sendable {
    package let x: Int32
    package let y: Int32
    package let width: Int32
    package let height: Int32

    package init(
        x outputX: Int32,
        y outputY: Int32,
        width outputWidth: Int32,
        height outputHeight: Int32
    ) {
        x = outputX
        y = outputY
        width = outputWidth
        height = outputHeight
    }
}

package struct RawOutputSnapshot: Equatable, Sendable {
    package let id: RawOutputID
    package let version: RawVersion
    package let geometry: RawOutputGeometry?
    package let logicalGeometry: RawOutputLogicalGeometry?
    package let currentMode: RawOutputMode?
    package let scale: Int32
    package let name: String?
    package let description: String?

    package init(
        id outputID: RawOutputID,
        version outputVersion: RawVersion,
        geometry outputGeometry: RawOutputGeometry?,
        logicalGeometry outputLogicalGeometry: RawOutputLogicalGeometry?,
        currentMode outputCurrentMode: RawOutputMode?,
        scale outputScale: Int32,
        name outputName: String?,
        description outputDescription: String?
    ) {
        id = outputID
        version = outputVersion
        geometry = outputGeometry
        logicalGeometry = outputLogicalGeometry
        currentMode = outputCurrentMode
        scale = outputScale
        name = outputName
        description = outputDescription
    }
}

package enum RawOutputEvent: Equatable, Sendable {
    case changed(RawOutputSnapshot)
    case removed(RawOutputID)
}

@safe
package final class RawOutput {
    package let id: RawOutputID
    package let version: RawVersion

    private var proxy: RawOwnedProxy
    private let listenerOwner: OutputListenerOwner
    private let onChanged: (RawOutputSnapshot) -> Void
    private var state = RawOutputState()
    private var isDestroyed = false

    @safe
    init(
        id outputID: RawOutputID,
        pointer outputPointer: OpaquePointer,
        version outputVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext,
        invariantFailureSink failureSink: RawInvariantFailureSink? = nil,
        onChanged handleChanged: @escaping (RawOutputSnapshot) -> Void = { _ in () }
    ) throws {
        id = outputID
        version = outputVersion
        onChanged = handleChanged
        let destroyOutput: (OpaquePointer) -> Void =
            outputVersion >= 3
            ? { unsafe swl_output_release($0) }
            : { unsafe swl_output_destroy($0) }
        proxy = try RawOwnedProxy(
            adopting: outputPointer,
            interface: "wl_output",
            proxyAdoption: adoptionContext,
            destroy: destroyOutput
        )
        listenerOwner = OutputListenerOwner(invariantFailureSink: failureSink)

        try unsafe listenerOwner.install(on: pointer) { [weak self] event in
            self?.handle(event)
        }
    }

    package var snapshot: RawOutputSnapshot {
        state.snapshot(id: id, version: version)
    }

    @safe package var pointer: OpaquePointer {
        proxy.pointer
    }

    #if DEBUG
        package var pointerAddressForTesting: UInt {
            unsafe UInt(bitPattern: UnsafeMutableRawPointer(pointer))
        }
    #endif

    @safe package var pointerIdentity: RawOutputPointerIdentity {
        RawOutputPointerIdentity(pointer)
    }

    package func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        listenerOwner.cancel()
        proxy.destroy()
    }

    private func handle(_ event: RawOutputCoreEvent) {
        if state.applyCoreEvent(event, version: version) {
            onChanged(snapshot)
        }
    }

    package func handleXDGOutputEvent(
        _ event: RawXDGOutputEvent,
        xdgOutputVersion: RawVersion
    ) {
        if state.applyXDGOutputEvent(
            event,
            outputVersion: version,
            xdgOutputVersion: xdgOutputVersion
        ) {
            onChanged(snapshot)
        }
    }

    deinit {
        destroy()
    }
}

@safe
private final class OutputListenerOwner {
    private let invariantFailureSink: RawInvariantFailureSink?
    private var onEvent: ((RawOutputCoreEvent) -> Void)?
    private var isCanceled = false
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_output_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks: UnsafeMutablePointer<swl_output_listener_callbacks> {
        listenerStorage.callbacks
    }

    init(invariantFailureSink failureSink: RawInvariantFailureSink? = nil) {
        invariantFailureSink = failureSink

        installGeometryCallback()
        installModeCallback()
        installDoneCallback()
        installScaleCallback()
        installNameCallback()
        installDescriptionCallback()
    }

    private func installGeometryCallback() {
        unsafe callbacks.pointee.geometry = { dt, _, x, y, pw, ph, sp, make, model, transform in
            OutputListenerOwner.withOwner(
                dt,
                message: "wl_output geometry fired without Swift state"
            ) { owner in
                guard !owner.isCanceled else { return }
                let makeString = unsafe make.map { unsafe String(cString: $0) }
                let modelString = unsafe model.map { unsafe String(cString: $0) }

                owner.onEvent?(
                    .geometry(
                        RawOutputGeometry(
                            x: x,
                            y: y,
                            physicalWidthMillimeters: pw,
                            physicalHeightMillimeters: ph,
                            subpixel: sp,
                            make: makeString,
                            model: modelString,
                            transform: transform
                        )
                    )
                )
            }
        }
    }

    private func installModeCallback() {
        unsafe callbacks.pointee.mode = { data, _, flags, width, height, refresh in
            OutputListenerOwner.withOwner(
                data,
                message: "wl_output mode fired without Swift state"
            ) { owner in
                guard !owner.isCanceled else { return }

                owner.onEvent?(
                    .mode(
                        RawOutputMode(
                            flags: flags,
                            width: width,
                            height: height,
                            refreshMilliHertz: refresh
                        )
                    )
                )
            }
        }
    }

    private func installDoneCallback() {
        unsafe callbacks.pointee.done = { data, _ in
            OutputListenerOwner.withOwner(
                data,
                message: "wl_output done fired without Swift state"
            ) { owner in
                guard !owner.isCanceled else { return }

                owner.onEvent?(.done)
            }
        }
    }

    private func installScaleCallback() {
        unsafe callbacks.pointee.scale = { data, _, factor in
            OutputListenerOwner.withOwner(
                data,
                message: "wl_output scale fired without Swift state"
            ) { owner in
                guard !owner.isCanceled else { return }

                owner.onEvent?(.scale(factor))
            }
        }
    }

    private func installNameCallback() {
        unsafe callbacks.pointee.name = { data, _, name in
            OutputListenerOwner.withOwner(
                data,
                message: "wl_output name fired without Swift state"
            ) { owner in
                guard !owner.isCanceled, let name = unsafe name else { return }

                owner.onEvent?(.name(unsafe String(cString: name)))
            }
        }
    }

    private func installDescriptionCallback() {
        unsafe callbacks.pointee.description = { data, _, description in
            OutputListenerOwner.withOwner(
                data,
                message: "wl_output description fired without Swift state"
            ) { owner in
                guard !owner.isCanceled, let description = unsafe description else { return }

                owner.onEvent?(.description(unsafe String(cString: description)))
            }
        }
    }

    func install(
        on output: OpaquePointer,
        onEvent handleEvent: @escaping (RawOutputCoreEvent) -> Void
    ) throws {
        onEvent = handleEvent
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer

        let result = unsafe swl_output_add_listener(output, callbacks)
        guard result == 0 else {
            throw RuntimeError.outputListenerInstallationFailed
        }
    }

    func cancel() {
        isCanceled = true
        onEvent = nil
        listenerStorage.invalidate()
    }

    deinit {
        cancel()
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (OutputListenerOwner) -> Void
    ) {
        CListenerStorage<OutputListenerOwner, swl_output_listener_callbacks>
            .withOwner(from: data, message: message(), body)
    }
}
