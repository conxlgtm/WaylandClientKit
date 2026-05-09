import CXKBCommonSystem

package struct KeyboardInterpreterConfiguration: Equatable, Sendable {
    package var compose: KeyboardComposeMode

    package init(compose composeMode: KeyboardComposeMode = .enabled()) {
        compose = composeMode
    }
}

package enum KeyboardComposeMode: Equatable, Sendable {
    case disabled
    case enabled(
        locale: KeyboardComposeLocale = .processEnvironment,
        cancellationPolicy: KeyboardComposeCancellationPolicy = .passThroughCancellingKey
    )
    case tableBuffer(
        String,
        locale: KeyboardComposeLocale = .identifier(.posixC),
        cancellationPolicy: KeyboardComposeCancellationPolicy = .passThroughCancellingKey
    )
}

package enum KeyboardComposeLocale: Equatable, Sendable {
    case processEnvironment
    case identifier(KeyboardComposeLocaleIdentifier)

    package func resolved(environment: KeyboardComposeEnvironment) -> String {
        switch self {
        case .identifier(let identifier):
            identifier.rawValue
        case .processEnvironment:
            normalized(environment.variables["LC_ALL"])
                ?? normalized(environment.variables["LC_CTYPE"])
                ?? normalized(environment.variables["LANG"])
                ?? KeyboardComposeLocaleIdentifier.posixC.rawValue
        }
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = trimmingXKBASCIIWhitespace(value)
        guard !trimmed.isEmpty, !trimmed.utf8.contains(0) else {
            return nil
        }

        return trimmed
    }
}

package struct KeyboardComposeEnvironment: Equatable, Sendable {
    package var variables: [String: String]

    package init(_ environmentVariables: [String: String] = [:]) {
        variables = environmentVariables
    }
}

package enum KeyboardComposeLocaleError: Error, Equatable, Sendable {
    case emptyIdentifier
    case containsNUL
}

package struct KeyboardComposeLocaleIdentifier: Equatable, Sendable {
    package let rawValue: String

    package init(_ value: String) throws(KeyboardComposeLocaleError) {
        let trimmed = trimmingXKBASCIIWhitespace(value)
        guard !trimmed.isEmpty else {
            throw .emptyIdentifier
        }
        guard !trimmed.utf8.contains(0) else {
            throw .containsNUL
        }

        rawValue = trimmed
    }

    package static let posixC = Self(unchecked: "C")

    package init(unchecked value: String) {
        precondition(!value.isEmpty, "compose locale identifier must not be empty")
        precondition(
            !value.utf8.contains(0),
            "compose locale identifier must not contain NUL bytes"
        )
        rawValue = value
    }
}

package enum KeyboardComposeCancellationPolicy: Equatable, Sendable {
    case passThroughCancellingKey
    case swallowCancellingKey
}

package enum KeyboardComposeFailure: Error, Equatable, Sendable {
    case tableUnavailable(locale: String)
    case emptyTableBuffer
    case tableBufferContainsNUL
    case stateCreationFailed
}

@safe
final class XKBComposeTableOwner {
    @safe let pointer: OpaquePointer

    init(
        context: XKBContextOwner,
        locale: String
    ) throws(KeyboardComposeFailure) {
        guard let createdTable = unsafe context.createComposeTable(locale: locale) else {
            throw .tableUnavailable(locale: locale)
        }

        unsafe pointer = createdTable
    }

    init(
        context: XKBContextOwner,
        buffer: String,
        locale: String = "C"
    ) throws(KeyboardComposeFailure) {
        guard !buffer.isEmpty else {
            throw .emptyTableBuffer
        }

        guard !buffer.utf8.contains(0) else {
            throw .tableBufferContainsNUL
        }

        guard
            let createdTable = unsafe context.createComposeTable(
                buffer: buffer,
                locale: locale
            )
        else {
            throw .tableUnavailable(locale: locale)
        }

        unsafe pointer = createdTable
    }

    deinit {
        unsafe xkb_compose_table_unref(pointer)
    }
}

struct KeyboardTextResolutionInput {
    let feedKeysym: KeyboardKeysym
    let feedKeysymName: String?
    let keyText: String?
    let resultKeysym: KeyboardKeysym?
    let resultKeysymName: String?
}

@safe
final class XKBComposeStateOwner {
    private let table: XKBComposeTableOwner
    @safe private let pointer: OpaquePointer
    private var activeProgress: KeyboardComposeProgress?

    init(table composeTable: XKBComposeTableOwner) throws(KeyboardComposeFailure) {
        guard
            let newPointer = unsafe xkb_compose_state_new(
                composeTable.pointer,
                XKB_COMPOSE_STATE_NO_FLAGS
            )
        else {
            throw .stateCreationFailed
        }

        table = composeTable
        unsafe pointer = newPointer
    }

    func resolve(
        input: KeyboardTextResolutionInput,
        policy: KeyboardComposeCancellationPolicy
    ) -> KeyboardTextResult {
        let feedResult = unsafe xkb_compose_state_feed(pointer, input.feedKeysym.rawValue)
        guard feedResult != XKB_COMPOSE_FEED_IGNORED else {
            return xkbKeyTextResult(
                input.keyText,
                resultKeysym: input.resultKeysym,
                resultKeysymName: input.resultKeysymName
            )
        }

        switch unsafe xkb_compose_state_get_status(pointer) {
        case XKB_COMPOSE_NOTHING:
            activeProgress = nil
            return xkbKeyTextResult(
                input.keyText,
                resultKeysym: input.resultKeysym,
                resultKeysymName: input.resultKeysymName
            )
        case XKB_COMPOSE_COMPOSING:
            if activeProgress == nil {
                activeProgress = KeyboardComposeProgress(
                    startedBy: input.feedKeysym,
                    startedByName: input.feedKeysymName
                )
            }
            guard let activeProgress else { return .none }
            return .composing(activeProgress)
        case XKB_COMPOSE_COMPOSED:
            let text = composedText()
            let resultKeysym = composedKeysym()
            reset()
            guard let text else { return .none }
            return .committed(
                KeyboardTextCommit(
                    string: text,
                    source: .compose,
                    resultKeysym: resultKeysym,
                    resultKeysymName: resultKeysym.flatMap { composedKeysymName(for: $0) }
                )
            )
        case XKB_COMPOSE_CANCELLED:
            reset()
            return .cancelled(
                KeyboardComposeCancellation(
                    cancellingKeysym: input.feedKeysym,
                    cancellingKeysymName: input.feedKeysymName,
                    fallbackCommit: fallbackCommit(
                        input.keyText,
                        resultKeysym: input.resultKeysym,
                        resultKeysymName: input.resultKeysymName,
                        policy: policy
                    )
                )
            )
        default:
            reset()
            return .none
        }
    }

    func reset() {
        unsafe xkb_compose_state_reset(pointer)
        activeProgress = nil
    }

    deinit {
        unsafe xkb_compose_state_unref(pointer)
    }

    private func composedText() -> String? {
        stringFromXKBSizedCall { buffer, count in
            unsafe xkb_compose_state_get_utf8(pointer, buffer, count)
        }
    }

    private func composedKeysym() -> KeyboardKeysym? {
        let rawKeysym = unsafe xkb_compose_state_get_one_sym(pointer)
        guard rawKeysym != XKB_KEY_NoSymbol else { return nil }
        return KeyboardKeysym(rawValue: rawKeysym)
    }

    private func composedKeysymName(for keysym: KeyboardKeysym) -> String? {
        stringFromXKBNameCall { buffer, count in
            unsafe xkb_keysym_get_name(keysym.rawValue, buffer, count)
        }
    }

    private func xkbKeyTextResult(
        _ keyText: String?,
        resultKeysym: KeyboardKeysym?,
        resultKeysymName: String?
    ) -> KeyboardTextResult {
        guard let keyText else { return .none }
        return .committed(
            KeyboardTextCommit(
                string: keyText,
                source: .xkbKey,
                resultKeysym: resultKeysym,
                resultKeysymName: resultKeysymName
            )
        )
    }

    private func fallbackCommit(
        _ keyText: String?,
        resultKeysym: KeyboardKeysym?,
        resultKeysymName: String?,
        policy: KeyboardComposeCancellationPolicy
    ) -> KeyboardTextCommit? {
        guard policy == .passThroughCancellingKey, let keyText else {
            return nil
        }

        return KeyboardTextCommit(
            string: keyText,
            source: .composeCancellationFallback,
            resultKeysym: resultKeysym,
            resultKeysymName: resultKeysymName
        )
    }
}

private func trimmingXKBASCIIWhitespace(_ value: String) -> String {
    let trimmedScalars = value.unicodeScalars.drop { scalar in
        isXKBASCIIWhitespace(scalar)
    }
    .reversed()
    .drop { isXKBASCIIWhitespace($0) }
    .reversed()
    return String(String.UnicodeScalarView(trimmedScalars))
}

private func isXKBASCIIWhitespace(_ scalar: UnicodeScalar) -> Bool {
    switch scalar.value {
    case 0x09...0x0D, 0x20:
        true
    default:
        false
    }
}
