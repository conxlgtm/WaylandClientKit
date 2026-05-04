import Synchronization

public enum DisplayEvent: Equatable, Sendable {
    case input(InputEvent)
    case diagnostic(DisplayDiagnostic)
    case windowCloseRequested(WindowID)
    case windowClosed(WindowID)
    case popupDismissed(PopupLifecycleEvent)
    case popupClosed(PopupLifecycleEvent)
    case redrawRequested(WindowID)
    case popupRedrawRequested(PopupLifecycleEvent)
}

public struct PopupLifecycleEvent: Equatable, Sendable {
    public let popup: PopupSurfaceIdentity
    public let parentWindowID: WindowID

    package init(popup popupID: PopupID, parentWindowID popupParentWindowID: WindowID) {
        popup = PopupSurfaceIdentity(popupID)
        parentWindowID = popupParentWindowID
    }
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

public enum EventStreamIdentity: Equatable, Sendable, CustomStringConvertible {
    case displayEvents
    case inputEvents
    case diagnostics

    public var description: String {
        switch self {
        case .displayEvents:
            "display events"
        case .inputEvents:
            "input events"
        case .diagnostics:
            "diagnostics"
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
            stream: .displayEvents,
            capacity: configuration.displayEventCapacity.rawValue
        )
        inputBroker = TypedEventBroker<InputEvent>(
            stream: .inputEvents,
            capacity: configuration.inputEventCapacity.rawValue
        )
        diagnosticsBroker = TypedEventBroker<DisplayDiagnostic>(
            stream: .diagnostics,
            capacity: diagnosticsConfiguration.capacity.rawValue,
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
        case .windowCloseRequested, .windowClosed, .popupDismissed, .popupClosed,
            .redrawRequested, .popupRedrawRequested:
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
        case .inputPipelineOverflow:
            .error
        case .keyboardKeymap, .listener, .cursor:
            .degraded
        }
    }

    private func displaySeverity(for diagnostic: WindowDiagnostic) -> DiagnosticSeverity {
        switch diagnostic.operation {
        case .callback, .lifecycle, .decoration, .presentation, .scale:
            .degraded
        }
    }

    private func inputPipelineOverflow(for diagnostic: InputDiagnostic) -> InputPipelineOverflow? {
        switch diagnostic.operation {
        case .inputPipelineOverflow(let overflow):
            overflow
        case .keyboardKeymap, .listener, .cursor:
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
