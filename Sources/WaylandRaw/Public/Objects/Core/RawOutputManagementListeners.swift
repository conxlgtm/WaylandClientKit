import CWaylandProtocols

private final class WeakOutputModeBox {
    weak var value: RawWlrOutputMode?
}

@safe
package final class RawWlrOutputHeadListenerOwner {
    private let version: RawVersion
    private let invariantFailureSink: RawInvariantFailureSink?
    private let onEvent: (RawWlrOutputHeadEvent) -> Void
    private var isCanceled = false
    private var modes: [RawWlrOutputMode] = []
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_zwlr_output_head_v1_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks: UnsafeMutablePointer<swl_zwlr_output_head_v1_listener_callbacks> {
        listenerStorage.callbacks
    }

    init(
        version headVersion: RawVersion,
        invariantFailureSink failureSink: RawInvariantFailureSink?,
        onEvent eventHandler: @escaping (RawWlrOutputHeadEvent) -> Void
    ) {
        version = headVersion
        invariantFailureSink = failureSink
        onEvent = eventHandler

        installStringCallbacks()
        installModeCallbacks()
        installScalarCallbacks()
    }

    private func installStringCallbacks() {
        unsafe callbacks.pointee.name = { data, _, name in
            RawWlrOutputHeadListenerOwner.withOwner(
                data,
                message: "zwlr_output_head_v1 name fired without Swift state"
            ) { owner in
                guard let name = stringFromNullableCString(name) else { return }
                owner.append(.name(name))
            }
        }
        unsafe callbacks.pointee.description = { data, _, description in
            RawWlrOutputHeadListenerOwner.withOwner(
                data,
                message: "zwlr_output_head_v1 description fired without Swift state"
            ) { owner in
                guard let description = stringFromNullableCString(description)
                else { return }
                owner.append(.description(description))
            }
        }
        unsafe callbacks.pointee.make = { data, _, make in
            RawWlrOutputHeadListenerOwner.withOwner(
                data,
                message: "zwlr_output_head_v1 make fired without Swift state"
            ) { owner in
                guard let make = stringFromNullableCString(make) else { return }
                owner.append(.make(make))
            }
        }
        unsafe callbacks.pointee.model = { data, _, model in
            RawWlrOutputHeadListenerOwner.withOwner(
                data,
                message: "zwlr_output_head_v1 model fired without Swift state"
            ) { owner in
                guard let model = stringFromNullableCString(model) else { return }
                owner.append(.model(model))
            }
        }
        unsafe callbacks.pointee.serial_number = { data, _, serialNumber in
            RawWlrOutputHeadListenerOwner.withOwner(
                data,
                message: "zwlr_output_head_v1 serial_number fired without Swift state"
            ) { owner in
                guard let serialNumber = stringFromNullableCString(serialNumber)
                else { return }
                owner.append(.serialNumber(serialNumber))
            }
        }
    }

    private func installModeCallbacks() {
        unsafe callbacks.pointee.mode = { data, _, modePointer in
            RawWlrOutputHeadListenerOwner.withOwner(
                data,
                message: "zwlr_output_head_v1 mode fired without Swift state"
            ) { owner in
                guard !owner.isCanceled, let modePointer = unsafe modePointer
                else { return }
                do {
                    let modeBox = WeakOutputModeBox()
                    let mode = try RawWlrOutputMode(
                        pointer: modePointer,
                        version: owner.version,
                        invariantFailureSink: owner.invariantFailureSink
                    ) { [weak owner, modeBox] modeEvent in
                        guard let owner, let mode = modeBox.value else { return }
                        owner.append(.modeEvent(mode, modeEvent))
                    }
                    modeBox.value = mode
                    owner.modes.append(mode)
                    owner.append(.mode(mode))
                } catch {
                    return
                }
            }
        }
        unsafe callbacks.pointee.current_mode = { data, _, mode in
            RawWlrOutputHeadListenerOwner.withOwner(
                data,
                message: "zwlr_output_head_v1 current_mode fired without Swift state"
            ) { owner in
                guard !owner.isCanceled, let mode = unsafe mode else { return }
                guard let currentMode = owner.modes.first(where: { $0.pointer == mode })
                else { return }
                owner.append(.currentMode(currentMode))
            }
        }
    }

    private func installScalarCallbacks() {
        unsafe callbacks.pointee.physical_size = { data, _, width, height in
            RawWlrOutputHeadListenerOwner.withOwner(
                data,
                message: "zwlr_output_head_v1 physical_size fired without Swift state"
            ) { owner in
                owner.append(.physicalSize(width: width, height: height))
            }
        }
        unsafe callbacks.pointee.enabled = { data, _, enabled in
            RawWlrOutputHeadListenerOwner.withOwner(
                data,
                message: "zwlr_output_head_v1 enabled fired without Swift state"
            ) { owner in
                owner.append(.enabled(enabled != 0))
            }
        }
        unsafe callbacks.pointee.position = { data, _, x, y in
            RawWlrOutputHeadListenerOwner.withOwner(
                data,
                message: "zwlr_output_head_v1 position fired without Swift state"
            ) { owner in
                owner.append(.position(x: x, y: y))
            }
        }
        unsafe callbacks.pointee.transform = { data, _, transform in
            RawWlrOutputHeadListenerOwner.withOwner(
                data,
                message: "zwlr_output_head_v1 transform fired without Swift state"
            ) { owner in
                owner.append(.transform(transform))
            }
        }
        unsafe callbacks.pointee.scale = { data, _, scale in
            RawWlrOutputHeadListenerOwner.withOwner(
                data,
                message: "zwlr_output_head_v1 scale fired without Swift state"
            ) { owner in
                owner.append(.scale(WaylandFixed(rawValue: scale)))
            }
        }
        unsafe callbacks.pointee.finished = { data, _ in
            RawWlrOutputHeadListenerOwner.withOwner(
                data,
                message: "zwlr_output_head_v1 finished fired without Swift state"
            ) { owner in
                owner.append(.finished)
            }
        }
        unsafe callbacks.pointee.adaptive_sync = { data, _, state in
            RawWlrOutputHeadListenerOwner.withOwner(
                data,
                message: "zwlr_output_head_v1 adaptive_sync fired without Swift state"
            ) { owner in
                owner.append(.adaptiveSync(state))
            }
        }
    }

    func install(on head: OpaquePointer) throws(RuntimeError) {
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer
        let result = unsafe swl_zwlr_output_head_v1_add_listener(head, callbacks)
        guard result == 0 else {
            throw RuntimeError.listenerInstallFailed("zwlr_output_head_v1")
        }
    }

    func cancel() {
        isCanceled = true
        listenerStorage.invalidate()
    }

    private func append(_ event: RawWlrOutputHeadEvent) {
        guard !isCanceled else { return }
        onEvent(event)
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (RawWlrOutputHeadListenerOwner) -> Void
    ) {
        CListenerStorage<
            RawWlrOutputHeadListenerOwner,
            swl_zwlr_output_head_v1_listener_callbacks
        >
        .withOwner(from: data, message: message(), body)
    }
}

@safe
package final class RawWlrOutputModeListenerOwner {
    private let invariantFailureSink: RawInvariantFailureSink?
    private let onEvent: (RawWlrOutputModeEvent) -> Void
    private var isCanceled = false
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_zwlr_output_mode_v1_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks: UnsafeMutablePointer<swl_zwlr_output_mode_v1_listener_callbacks> {
        listenerStorage.callbacks
    }

    init(
        invariantFailureSink failureSink: RawInvariantFailureSink?,
        onEvent eventHandler: @escaping (RawWlrOutputModeEvent) -> Void
    ) {
        invariantFailureSink = failureSink
        onEvent = eventHandler

        unsafe callbacks.pointee.size = { data, _, width, height in
            RawWlrOutputModeListenerOwner.withOwner(
                data,
                message: "zwlr_output_mode_v1 size fired without Swift state"
            ) { owner in
                owner.append(.size(width: width, height: height))
            }
        }
        unsafe callbacks.pointee.refresh = { data, _, refresh in
            RawWlrOutputModeListenerOwner.withOwner(
                data,
                message: "zwlr_output_mode_v1 refresh fired without Swift state"
            ) { owner in
                owner.append(.refresh(refresh))
            }
        }
        unsafe callbacks.pointee.preferred = { data, _ in
            RawWlrOutputModeListenerOwner.withOwner(
                data,
                message: "zwlr_output_mode_v1 preferred fired without Swift state"
            ) { owner in
                owner.append(.preferred)
            }
        }
        unsafe callbacks.pointee.finished = { data, _ in
            RawWlrOutputModeListenerOwner.withOwner(
                data,
                message: "zwlr_output_mode_v1 finished fired without Swift state"
            ) { owner in
                owner.append(.finished)
            }
        }
    }

    func install(on mode: OpaquePointer) throws(RuntimeError) {
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer
        let result = unsafe swl_zwlr_output_mode_v1_add_listener(mode, callbacks)
        guard result == 0 else {
            throw RuntimeError.listenerInstallFailed("zwlr_output_mode_v1")
        }
    }

    func cancel() {
        isCanceled = true
        listenerStorage.invalidate()
    }

    private func append(_ event: RawWlrOutputModeEvent) {
        guard !isCanceled else { return }
        onEvent(event)
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (RawWlrOutputModeListenerOwner) -> Void
    ) {
        CListenerStorage<
            RawWlrOutputModeListenerOwner,
            swl_zwlr_output_mode_v1_listener_callbacks
        >
        .withOwner(from: data, message: message(), body)
    }
}
