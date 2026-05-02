import Synchronization
import WaylandRaw

public enum DisplayEvent: Equatable, Sendable {
    case input(InputEvent)
    case diagnostic(DisplayDiagnostic)
    case windowCloseRequested(WindowID)
    case windowClosed(WindowID)
    case redrawRequested(WindowID)
}

public enum DiagnosticSeverity: Equatable, Sendable {
    case warning
    case degraded
    case error
}

public struct DiagnosticID: Equatable, Hashable, Sendable {
    public let rawValue: UInt64

    public init(rawValue diagnosticRawValue: UInt64) {
        rawValue = diagnosticRawValue
    }
}

public struct DisplayDiagnostic: Equatable, Sendable {
    public let id: DiagnosticID
    public let severity: DiagnosticSeverity
    public let payload: DisplayDiagnosticPayload

    public init(
        id diagnosticID: DiagnosticID,
        severity diagnosticSeverity: DiagnosticSeverity,
        payload diagnosticPayload: DisplayDiagnosticPayload
    ) {
        id = diagnosticID
        severity = diagnosticSeverity
        payload = diagnosticPayload
    }
}

public enum DisplayDiagnosticPayload: Equatable, Sendable {
    case input(InputDiagnostic)
    case window(WindowDiagnostic)
    case diagnosticsDropped(count: Int)
}

public enum WaylandProtocolError: Equatable, Sendable, CustomStringConvertible {
    case display(interface: String?, objectID: UInt32, code: Int32)
    case invalidXDGConfigureDimensions(windowID: WindowID, width: Int32, height: Int32)
    case invalidConfigureSerial(windowID: WindowID, serial: UInt32)
    case proxyQueueMismatch(interface: String, objectID: UInt32?)

    public var description: String {
        switch self {
        case .display(let interface, let objectID, let code):
            "Wayland protocol error interface=\(interface ?? "?") object=\(objectID) code=\(code)"
        case .invalidXDGConfigureDimensions(let windowID, let width, let height):
            "Window \(windowID) received invalid XDG configure dimensions "
                + "width=\(width) height=\(height)"
        case .invalidConfigureSerial(let windowID, let serial):
            "Window \(windowID) received invalid configure serial \(serial)"
        case .proxyQueueMismatch(let interface, let objectID):
            "Wayland proxy queue mismatch interface=\(interface) object="
                + "\(objectID.map(String.init) ?? "?")"
        }
    }
}

public enum InternalInvariantViolation: Equatable, Sendable, CustomStringConvertible {
    case message(String)
    case rawListenerFiredAfterInvalidation(String)
    case frameCallbackAfterLocalDestroy(WindowID)
    case bufferReleaseWithoutBufferState(WindowID)
    case invalidWindowTransition(WindowID, transition: WindowLifecycleTransitionError)
    case effectInterpreterInvariant(WindowID, String)
    case unexpectedWindowCallbackError(
        WindowID,
        operation: WindowCallbackOperation,
        detail: String
    )
    case eventSubscriberAwaitedTwice

    public var description: String {
        switch self {
        case .message(let detail):
            detail
        case .rawListenerFiredAfterInvalidation(let detail):
            "Raw listener fired after invalidation: \(detail)"
        case .frameCallbackAfterLocalDestroy(let windowID):
            "Frame callback fired after local destroy for window \(windowID)"
        case .bufferReleaseWithoutBufferState(let windowID):
            "Buffer release arrived without buffer state for window \(windowID)"
        case .invalidWindowTransition(let windowID, let transition):
            "Window \(windowID) invalid transition: \(transition.description)"
        case .effectInterpreterInvariant(let windowID, let detail):
            "Window \(windowID) effect interpreter invariant failed: \(detail)"
        case .unexpectedWindowCallbackError(let windowID, let operation, let detail):
            "Window \(windowID) callback \(operation) failed unexpectedly: \(detail)"
        case .eventSubscriberAwaitedTwice:
            "event subscriber awaited twice"
        }
    }
}

public enum WaylandDisplayError: Error, Equatable, Sendable, CustomStringConvertible {
    case closed
    case protocolError(WaylandProtocolError)
    case systemError(errno: Int32)
    case runtime(String)
    case eventSubscriberOverflow(stream: String, capacity: Int)
    case inputPipelineOverflow(InputPipelineOverflow)
    case internalInvariantViolation(InternalInvariantViolation)

    init(_ error: any Error) {
        if let displayError = error as? WaylandDisplayError {
            self = displayError
            return
        }

        if let runtimeError = error as? RuntimeError {
            self = Self(runtimeError)
            return
        }

        self = .runtime(String(describing: error))
    }

    init(_ runtimeError: RuntimeError) {
        switch runtimeError {
        case .protocolError(let interfaceName, let objectID, let code):
            self = .protocolError(
                .display(interface: interfaceName, objectID: objectID, code: code)
            )
        case .proxyQueueMismatch(let interface):
            self = .protocolError(.proxyQueueMismatch(interface: interface, objectID: nil))
        case .pollFailed(let errno), .systemError(let errno):
            self = .systemError(errno: errno)
        default:
            self = .runtime(runtimeError.description)
        }
    }

    public var description: String {
        switch self {
        case .closed:
            "Wayland display is closed"
        case .protocolError(let error):
            error.description
        case .systemError(let errno):
            "Wayland display failed with errno \(errno)"
        case .runtime(let detail):
            "Wayland display failed: \(detail)"
        case .eventSubscriberOverflow(let stream, let capacity):
            "Wayland \(stream) subscriber exceeded buffer capacity \(capacity)"
        case .inputPipelineOverflow(let overflow):
            "Wayland input pipeline overflowed in \(overflow.stage.description) "
                + "at capacity \(overflow.capacity)"
        case .internalInvariantViolation(let violation):
            "Wayland display internal invariant failed: \(violation.description)"
        }
    }
}

@safe
package struct InternalEventSubscription<Element: Sendable>: Sendable {
    private let subscription: EventSubscription<Element>

    init(_ eventSubscription: EventSubscription<Element>) {
        subscription = eventSubscription
    }

    package func makeAsyncIterator() -> InternalEventSubscriptionIterator<Element> {
        InternalEventSubscriptionIterator(subscription: subscription)
    }
}

@safe
package struct InternalEventSubscriptionIterator<Element: Sendable>: AsyncIteratorProtocol {
    package typealias Failure = WaylandDisplayError

    private let subscription: EventSubscription<Element>

    init(subscription eventSubscription: EventSubscription<Element>) {
        subscription = eventSubscription
    }

    package mutating func next() async throws(WaylandDisplayError) -> Element? {
        try await next(isolation: nil)
    }

    package mutating func next(
        isolation actor: isolated (any Actor)?
    ) async throws(WaylandDisplayError) -> Element? {
        try await subscription.next(isolation: actor)
    }
}

@safe
public struct DisplayEvents: AsyncSequence, Sendable {
    public typealias Element = DisplayEvent
    public typealias Failure = WaylandDisplayError

    private let subscription: InternalEventSubscription<DisplayEvent>

    package init(_ eventSubscription: InternalEventSubscription<DisplayEvent>) {
        subscription = eventSubscription
    }

    public func makeAsyncIterator() -> DisplayEventsIterator {
        DisplayEventsIterator(base: subscription.makeAsyncIterator())
    }
}

@safe
public struct DisplayEventsIterator: AsyncIteratorProtocol {
    public typealias Element = DisplayEvent
    public typealias Failure = WaylandDisplayError

    private var base: InternalEventSubscriptionIterator<DisplayEvent>

    package init(base iterator: InternalEventSubscriptionIterator<DisplayEvent>) {
        base = iterator
    }

    public mutating func next() async throws(WaylandDisplayError) -> DisplayEvent? {
        try await next(isolation: nil)
    }

    public mutating func next(
        isolation actor: isolated (any Actor)?
    ) async throws(WaylandDisplayError) -> DisplayEvent? {
        try await base.next(isolation: actor)
    }
}

@safe
public struct InputEvents: AsyncSequence, Sendable {
    public typealias Element = InputEvent
    public typealias Failure = WaylandDisplayError

    private let subscription: InternalEventSubscription<InputEvent>

    package init(_ eventSubscription: InternalEventSubscription<InputEvent>) {
        subscription = eventSubscription
    }

    public func makeAsyncIterator() -> InputEventsIterator {
        InputEventsIterator(base: subscription.makeAsyncIterator())
    }
}

@safe
public struct InputEventsIterator: AsyncIteratorProtocol {
    public typealias Element = InputEvent
    public typealias Failure = WaylandDisplayError

    private var base: InternalEventSubscriptionIterator<InputEvent>

    package init(base iterator: InternalEventSubscriptionIterator<InputEvent>) {
        base = iterator
    }

    public mutating func next() async throws(WaylandDisplayError) -> InputEvent? {
        try await next(isolation: nil)
    }

    public mutating func next(
        isolation actor: isolated (any Actor)?
    ) async throws(WaylandDisplayError) -> InputEvent? {
        try await base.next(isolation: actor)
    }
}

@safe
public struct DisplayDiagnostics: AsyncSequence, Sendable {
    public typealias Element = DisplayDiagnostic
    public typealias Failure = WaylandDisplayError

    private let subscription: InternalEventSubscription<DisplayDiagnostic>

    package init(_ eventSubscription: InternalEventSubscription<DisplayDiagnostic>) {
        subscription = eventSubscription
    }

    public func makeAsyncIterator() -> DisplayDiagnosticsIterator {
        DisplayDiagnosticsIterator(base: subscription.makeAsyncIterator())
    }
}

@safe
public struct DisplayDiagnosticsIterator: AsyncIteratorProtocol {
    public typealias Element = DisplayDiagnostic
    public typealias Failure = WaylandDisplayError

    private var base: InternalEventSubscriptionIterator<DisplayDiagnostic>

    package init(base iterator: InternalEventSubscriptionIterator<DisplayDiagnostic>) {
        base = iterator
    }

    public mutating func next() async throws(WaylandDisplayError) -> DisplayDiagnostic? {
        try await next(isolation: nil)
    }

    public mutating func next(
        isolation actor: isolated (any Actor)?
    ) async throws(WaylandDisplayError) -> DisplayDiagnostic? {
        try await base.next(isolation: actor)
    }
}

@safe
private final class DiagnosticIDGenerator: Sendable {
    private let state = Mutex<UInt64>(1)

    func next() -> DiagnosticID {
        state.withLock { nextID in
            defer { nextID += 1 }
            return DiagnosticID(rawValue: nextID)
        }
    }
}

@safe
final class DisplayEventHub: Sendable {
    private let displayBroker: TypedEventBroker<DisplayEvent>
    private let inputBroker: TypedEventBroker<InputEvent>
    private let diagnosticsBroker: TypedEventBroker<DisplayDiagnostic>
    private let diagnosticIDGenerator: DiagnosticIDGenerator

    init(
        configuration: EventStreamConfiguration = .init(),
        diagnosticsConfiguration: DiagnosticsConfiguration = .init()
    ) {
        let idGenerator = DiagnosticIDGenerator()
        diagnosticIDGenerator = idGenerator
        displayBroker = TypedEventBroker<DisplayEvent>(
            streamName: "display event",
            capacity: configuration.displayEventCapacity
        )
        inputBroker = TypedEventBroker<InputEvent>(
            streamName: "input event",
            capacity: configuration.inputEventCapacity
        )
        diagnosticsBroker = TypedEventBroker<DisplayDiagnostic>(
            streamName: "diagnostic",
            capacity: diagnosticsConfiguration.capacity,
            overflowStrategy: .dropOldest { count in
                DisplayDiagnostic(
                    id: idGenerator.next(),
                    severity: .warning,
                    payload: .diagnosticsDropped(count: count)
                )
            }
        )
    }

    func displayEvents() -> DisplayEvents {
        DisplayEvents(displayBroker.subscribe())
    }

    func inputEvents() -> InputEvents {
        InputEvents(inputBroker.subscribe())
    }

    func diagnostics() -> DisplayDiagnostics {
        DisplayDiagnostics(diagnosticsBroker.subscribe())
    }

    func publish(_ event: DisplayEvent) {
        switch event {
        case .input(let inputEvent):
            publishInput(inputEvent)
        case .diagnostic(let diagnostic):
            publishDiagnostic(diagnostic)
        case .windowCloseRequested, .windowClosed, .redrawRequested:
            displayBroker.publish(event)
        }
    }

    func publishInput(_ inputEvent: InputEvent) {
        switch inputEvent.kind {
        case .diagnostic(let diagnostic):
            let displayDiagnostic = makeDisplayDiagnostic(
                payload: .input(diagnostic),
                severity: displaySeverity(for: diagnostic)
            )
            publishDiagnostic(displayDiagnostic)
            if let overflow = inputPipelineOverflow(for: diagnostic) {
                inputBroker.finish(
                    throwing: .inputPipelineOverflow(overflow)
                )
                return
            }
        case .seat, .pointer, .keyboard, .touch:
            guard !inputBroker.isTerminal else { return }
            displayBroker.publish(.input(inputEvent))
        }

        inputBroker.publish(inputEvent)
    }

    func publishWindowDiagnostic(_ diagnostic: WindowDiagnostic) {
        publishDiagnostic(
            makeDisplayDiagnostic(
                payload: .window(diagnostic),
                severity: displaySeverity(for: diagnostic)
            )
        )
    }

    func finish(throwing error: WaylandDisplayError? = nil) {
        displayBroker.finish(throwing: error)
        inputBroker.finish(throwing: error)
        diagnosticsBroker.finish(throwing: error)
    }

    private func displaySeverity(for diagnostic: InputDiagnostic) -> DiagnosticSeverity {
        switch diagnostic.operation {
        case .queueOverflow, .inputPipelineOverflow:
            .error
        case .keyboardKeymap, .listener, .cursor:
            .degraded
        }
    }

    private func displaySeverity(for diagnostic: WindowDiagnostic) -> DiagnosticSeverity {
        switch diagnostic.operation {
        case .callback, .lifecycle, .presentation:
            .degraded
        }
    }

    private func inputPipelineOverflow(for diagnostic: InputDiagnostic) -> InputPipelineOverflow? {
        switch diagnostic.operation {
        case .inputPipelineOverflow(let overflow):
            overflow
        case .keyboardKeymap, .listener, .queueOverflow, .cursor:
            nil
        }
    }

    private func makeDisplayDiagnostic(
        payload diagnosticPayload: DisplayDiagnosticPayload,
        severity diagnosticSeverity: DiagnosticSeverity
    ) -> DisplayDiagnostic {
        DisplayDiagnostic(
            id: diagnosticIDGenerator.next(),
            severity: diagnosticSeverity,
            payload: diagnosticPayload
        )
    }

    private func publishDiagnostic(_ diagnostic: DisplayDiagnostic) {
        displayBroker.publish(.diagnostic(diagnostic))
        diagnosticsBroker.publish(diagnostic)
    }
}
