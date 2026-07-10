public enum DisplayEvent: Equatable, Sendable {
    case input(InputEvent)
    case diagnostic(DisplayDiagnostic)
    case windowCloseRequested(WindowID)
    case windowClosed(WindowID)
    case popupDismissed(PopupLifecycleEvent)
    case popupClosed(PopupLifecycleEvent)
    case redrawRequested(WindowID)
    case popupRedrawRequested(PopupLifecycleEvent)
    case outputChanged(OutputSnapshot)
    case outputRemoved(OutputID)
    case windowOutputsChanged(WindowOutputMembershipEvent)
    case keyboardShortcutsInhibitorChanged(KeyboardShortcutsInhibitorEvent)
}

public struct PopupLifecycleEvent: Equatable, Sendable {
    public let popup: PopupSurfaceIdentity
    public let parentWindowID: WindowID

    package init(popup popupID: PopupID, parentWindowID popupParentWindowID: WindowID) {
        popup = PopupSurfaceIdentity(popupID)
        parentWindowID = popupParentWindowID
    }
}

public struct WindowOutputMembershipEvent: Equatable, Sendable {
    public let windowID: WindowID
    public let outputs: [OutputID]

    public init(windowID eventWindowID: WindowID, outputs eventOutputs: [OutputID]) {
        windowID = eventWindowID
        outputs = eventOutputs
    }
}

public enum DiagnosticSeverity: Equatable, Sendable {
    case warning
    case degraded
    case error
}

public struct DiagnosticID: Equatable, Hashable, Sendable {
    package let rawValue: UInt64

    package init(rawValue diagnosticRawValue: UInt64) {
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
    case dataTransfer(DataTransferDiagnostic)
    case textInput(TextInputDiagnostic)
    case diagnosticsDropped(count: Int)
}

public enum EventStreamIdentity: Equatable, Sendable, CustomStringConvertible {
    case displayEvents
    case inputEvents
    case dataTransferEvents
    case textInputEvents
    case presentationEvents
    case diagnostics

    public var description: String {
        switch self {
        case .displayEvents:
            "display events"
        case .inputEvents:
            "input events"
        case .dataTransferEvents:
            "data transfer events"
        case .textInputEvents:
            "text input events"
        case .presentationEvents:
            "presentation events"
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

    package func nextForTesting(
        beforeImmediateResume: @escaping () -> Void
    ) async throws(WaylandDisplayError) -> Element? {
        try await subscription.next(
            isolation: nil,
            beforeImmediateResumeForTesting: beforeImmediateResume
        )
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
public struct DataTransferEvents: AsyncSequence, Sendable {
    public typealias Element = DataTransferEvent
    public typealias Failure = WaylandDisplayError

    private let subscription: InternalEventSubscription<DataTransferEvent>

    package init(_ eventSubscription: InternalEventSubscription<DataTransferEvent>) {
        subscription = eventSubscription
    }

    public func makeAsyncIterator() -> DataTransferEventsIterator {
        DataTransferEventsIterator(base: subscription.makeAsyncIterator())
    }
}

@safe
public struct DataTransferEventsIterator: AsyncIteratorProtocol {
    public typealias Element = DataTransferEvent
    public typealias Failure = WaylandDisplayError

    private var base: InternalEventSubscriptionIterator<DataTransferEvent>

    package init(base iterator: InternalEventSubscriptionIterator<DataTransferEvent>) {
        base = iterator
    }

    public mutating func next() async throws(WaylandDisplayError) -> DataTransferEvent? {
        try await next(isolation: nil)
    }

    public mutating func next(
        isolation actor: isolated (any Actor)?
    ) async throws(WaylandDisplayError) -> DataTransferEvent? {
        try await base.next(isolation: actor)
    }
}

@safe
public struct TextInputEvents: AsyncSequence, Sendable {
    public typealias Element = TextInputEvent
    public typealias Failure = WaylandDisplayError

    private let subscription: InternalEventSubscription<TextInputEvent>

    package init(_ eventSubscription: InternalEventSubscription<TextInputEvent>) {
        subscription = eventSubscription
    }

    public func makeAsyncIterator() -> TextInputEventsIterator {
        TextInputEventsIterator(base: subscription.makeAsyncIterator())
    }
}

@safe
public struct TextInputEventsIterator: AsyncIteratorProtocol {
    public typealias Element = TextInputEvent
    public typealias Failure = WaylandDisplayError

    private var base: InternalEventSubscriptionIterator<TextInputEvent>

    package init(base iterator: InternalEventSubscriptionIterator<TextInputEvent>) {
        base = iterator
    }

    public mutating func next() async throws(WaylandDisplayError) -> TextInputEvent? {
        try await next(isolation: nil)
    }

    public mutating func next(
        isolation actor: isolated (any Actor)?
    ) async throws(WaylandDisplayError) -> TextInputEvent? {
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
