import CXKBCommonSystem
import Foundation
import Synchronization

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

    package func resolved(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String {
        switch self {
        case .identifier(let identifier):
            identifier.rawValue
        case .processEnvironment:
            normalized(environment["LC_ALL"])
                ?? normalized(environment["LC_CTYPE"])
                ?? normalized(environment["LANG"])
                ?? KeyboardComposeLocaleIdentifier.posixC.rawValue
        }
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

package enum KeyboardComposeLocaleError: Error, Equatable, Sendable {
    case emptyIdentifier
}

package struct KeyboardComposeLocaleIdentifier: Equatable, Sendable {
    package let rawValue: String

    package init(_ value: String) throws(KeyboardComposeLocaleError) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw .emptyIdentifier
        }

        rawValue = trimmed
    }

    package static let posixC = Self(unchecked: "C")

    package init(unchecked value: String) {
        rawValue = value
    }
}

package enum KeyboardComposeCancellationPolicy: Equatable, Sendable {
    case passThroughCancellingKey
    case swallowCancellingKey
}

package enum KeyboardComposeFailure: Error, Equatable, Sendable {
    case tableUnavailable(locale: String)
    case tableBufferContainsNUL
    case stateCreationFailed
}

@safe
final class XKBComposeTableOwner {
    // libxkbcommon documents compose tables as immutable after creation, but
    // not concurrent table compilation through shared contexts and locale
    // file parsing. Swift Testing can create interpreters concurrently, so
    // table compilation is serialized before table objects are handed out.
    private static let creationLock = Mutex(())

    @safe let pointer: OpaquePointer

    // SAFETY: This value crosses `Mutex.withLock` only to transfer a newly
    // created compose table pointer to its Swift owner. The pointer is not
    // shared through the carrier after `XKBComposeTableOwner` stores it.
    @safe
    private struct CreatedTablePointer: @unchecked Sendable {
        @safe let pointer: OpaquePointer
    }

    init(
        context: XKBContextOwner,
        locale: String
    ) throws(KeyboardComposeFailure) {
        let createdTable = Self.creationLock.withLock { _ -> CreatedTablePointer? in
            unsafe locale.withCString { localePointer in
                unsafe xkb_compose_table_new_from_locale(
                    context.pointer,
                    localePointer,
                    XKB_COMPOSE_COMPILE_NO_FLAGS
                ).map(CreatedTablePointer.init(pointer:))
            }
        }

        guard let createdTable else {
            throw .tableUnavailable(locale: locale)
        }

        pointer = createdTable.pointer
    }

    init(
        context: XKBContextOwner,
        buffer: String,
        locale: String = "C"
    ) throws(KeyboardComposeFailure) {
        guard !buffer.isEmpty else {
            throw .tableUnavailable(locale: locale)
        }

        guard !buffer.utf8.contains(0) else {
            throw .tableBufferContainsNUL
        }

        let byteCount = buffer.utf8.count
        let createdTable = Self.creationLock.withLock { _ -> CreatedTablePointer? in
            unsafe buffer.withCString { bufferPointer -> OpaquePointer? in
                unsafe locale.withCString { localePointer in
                    unsafe xkb_compose_table_new_from_buffer(
                        context.pointer,
                        bufferPointer,
                        byteCount,
                        localePointer,
                        XKB_COMPOSE_FORMAT_TEXT_V1,
                        XKB_COMPOSE_COMPILE_NO_FLAGS
                    )
                }
            }.map(CreatedTablePointer.init(pointer:))
        }

        guard let createdTable else {
            throw .tableUnavailable(locale: locale)
        }

        pointer = createdTable.pointer
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
        unsafe stringFromXKB { buffer, count in
            unsafe xkb_compose_state_get_utf8(pointer, buffer, count)
        }
    }

    private func composedKeysym() -> KeyboardKeysym? {
        let rawKeysym = unsafe xkb_compose_state_get_one_sym(pointer)
        guard rawKeysym != XKB_KEY_NoSymbol else { return nil }
        return KeyboardKeysym(rawValue: rawKeysym)
    }

    private func composedKeysymName(for keysym: KeyboardKeysym) -> String? {
        var buffer = [CChar](repeating: 0, count: 64)
        let required = unsafe xkb_keysym_get_name(keysym.rawValue, &buffer, buffer.count)
        guard required > 0 else { return nil }

        if Int(required) < buffer.count {
            return stringFromNullTerminatedBuffer(buffer)
        }

        buffer = [CChar](repeating: 0, count: Int(required) + 1)
        let written = unsafe xkb_keysym_get_name(keysym.rawValue, &buffer, buffer.count)
        guard written > 0 else { return nil }

        return stringFromNullTerminatedBuffer(buffer)
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

    private func stringFromXKB(
        _ body: (UnsafeMutablePointer<CChar>?, Int) -> Int32
    ) -> String? {
        let required = body(nil, 0)
        guard required > 0 else { return nil }

        var buffer = [CChar](repeating: 0, count: Int(required) + 1)
        let written = unsafe body(&buffer, buffer.count)
        guard written > 0 else { return nil }

        return stringFromNullTerminatedBuffer(buffer)
    }

    private func stringFromNullTerminatedBuffer(_ buffer: [CChar]) -> String? {
        let endIndex = buffer.firstIndex(of: 0) ?? buffer.endIndex
        return String(
            bytes: buffer[..<endIndex].map { UInt8(bitPattern: $0) },
            encoding: .utf8
        )
    }
}
