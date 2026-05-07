package enum SmokeConfigurationError: Error, Equatable, Sendable, CustomStringConvertible {
    case nonPositiveMilliseconds(field: SmokeConfigurationField, value: Int32)

    package var description: String {
        switch self {
        case .nonPositiveMilliseconds(let field, let value):
            "\(field.description) must be greater than zero, got \(value)"
        }
    }
}

package enum SmokeConfigurationField: Equatable, Sendable, CustomStringConvertible {
    case timeoutMilliseconds
    case postCommitPumpMilliseconds

    package var description: String {
        switch self {
        case .timeoutMilliseconds:
            "timeoutMilliseconds"
        case .postCommitPumpMilliseconds:
            "postCommitPumpMilliseconds"
        }
    }
}

package struct SmokeMilliseconds: Equatable, Comparable, Sendable, CustomStringConvertible {
    package let rawValue: Int32

    package static let defaultTimeout = SmokeMilliseconds(unchecked: 5_000)
    package static let defaultPostCommitPump = SmokeMilliseconds(unchecked: 16)

    package init(_ value: Int32, field: SmokeConfigurationField)
        throws(SmokeConfigurationError)
    {
        guard value > 0 else {
            throw .nonPositiveMilliseconds(field: field, value: value)
        }

        rawValue = value
    }

    package init(unchecked value: Int32) {
        precondition(value > 0, "smoke milliseconds must be positive")
        rawValue = value
    }

    package var description: String {
        String(rawValue)
    }

    package static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

package struct SmokeConfiguration: Equatable, Sendable {
    package var timeout: SmokeMilliseconds
    package var postCommitPump: SmokeMilliseconds

    package var timeoutMilliseconds: Int32 {
        timeout.rawValue
    }

    package var postCommitPumpMilliseconds: Int32 {
        postCommitPump.rawValue
    }

    package init(
        timeout: SmokeMilliseconds = .defaultTimeout,
        postCommitPump: SmokeMilliseconds = .defaultPostCommitPump
    ) {
        self.timeout = timeout
        self.postCommitPump = postCommitPump
    }

    package init(
        timeoutMilliseconds timeout: Int32,
        postCommitPumpMilliseconds postCommitPump: Int32
    ) throws(SmokeConfigurationError) {
        self.timeout = try SmokeMilliseconds(
            timeout,
            field: .timeoutMilliseconds
        )
        self.postCommitPump = try SmokeMilliseconds(
            postCommitPump,
            field: .postCommitPumpMilliseconds
        )
    }
}

package enum SmokeCommand: Equatable, Sendable {
    case run(SmokeConfiguration)
    case help
}

package enum SmokeResult: Equatable, Sendable, CustomStringConvertible {
    case committedFrame
    case frameCallbackObserved

    package var description: String {
        switch self {
        case .committedFrame:
            "committed frame"
        case .frameCallbackObserved:
            "frame callback observed"
        }
    }
}
