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

package enum SmokeOptionalProtocol: Equatable, Sendable, CustomStringConvertible {
    case linuxDmabuf
    case linuxDrmSyncobj
    case fifo
    case commitTiming
    case contentType
    case alphaModifier
    case tearingControl
    case colorRepresentation
    case colorManagement

    package var interfaceName: String {
        switch self {
        case .linuxDmabuf:
            "zwp_linux_dmabuf_v1"
        case .linuxDrmSyncobj:
            "wp_linux_drm_syncobj_manager_v1"
        case .fifo:
            "wp_fifo_manager_v1"
        case .commitTiming:
            "wp_commit_timing_manager_v1"
        case .contentType:
            "wp_content_type_manager_v1"
        case .alphaModifier:
            "wp_alpha_modifier_v1"
        case .tearingControl:
            "wp_tearing_control_manager_v1"
        case .colorRepresentation:
            "wp_color_representation_manager_v1"
        case .colorManagement:
            "wp_color_manager_v1"
        }
    }

    package var liveTestName: String {
        switch self {
        case .linuxDmabuf:
            "linux-dmabuf"
        case .linuxDrmSyncobj:
            "syncobj"
        case .fifo:
            "FIFO"
        case .commitTiming:
            "commit-timing"
        case .contentType:
            "content-type"
        case .alphaModifier:
            "alpha-modifier"
        case .tearingControl:
            "tearing-control"
        case .colorRepresentation:
            "color-representation"
        case .colorManagement:
            "color-management"
        }
    }

    package var description: String {
        liveTestName
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
    package var requestedOptionalProtocols: [SmokeOptionalProtocol]

    package var timeoutMilliseconds: Int32 {
        timeout.rawValue
    }

    package var postCommitPumpMilliseconds: Int32 {
        postCommitPump.rawValue
    }

    package init(
        timeout: SmokeMilliseconds = .defaultTimeout,
        postCommitPump: SmokeMilliseconds = .defaultPostCommitPump,
        requestedOptionalProtocols optionalProtocols: [SmokeOptionalProtocol] = []
    ) {
        self.timeout = timeout
        self.postCommitPump = postCommitPump
        requestedOptionalProtocols = optionalProtocols
    }

    package init(
        timeoutMilliseconds timeout: Int32,
        postCommitPumpMilliseconds postCommitPump: Int32,
        requestedOptionalProtocols optionalProtocols: [SmokeOptionalProtocol] = []
    ) throws(SmokeConfigurationError) {
        self.timeout = try SmokeMilliseconds(
            timeout,
            field: .timeoutMilliseconds
        )
        self.postCommitPump = try SmokeMilliseconds(
            postCommitPump,
            field: .postCommitPumpMilliseconds
        )
        requestedOptionalProtocols = optionalProtocols
    }
}

package enum SmokePathStatus: String, Equatable, Sendable, CustomStringConvertible {
    case unavailable
    case advertised
    case configured
    case active
    case fallback
    case requested
    case observed

    package var description: String {
        rawValue
    }
}

package struct SmokeRuntimeFacts: Equatable, Sendable, CustomStringConvertible {
    package var syncobj: SmokePathStatus
    package var fifo: SmokePathStatus
    package var commitTiming: SmokePathStatus
    package var dmabuf: SmokePathStatus
    package var gbm: SmokePathStatus
    package var egl: SmokePathStatus
    package var presentationFeedback: SmokePathStatus
    package var contentType: SmokePathStatus
    package var alphaModifier: SmokePathStatus
    package var tearingControl: SmokePathStatus
    package var colorRepresentation: SmokePathStatus
    package var colorManagement: SmokePathStatus

    package static let unavailable = Self(
        syncobj: .unavailable,
        fifo: .unavailable,
        commitTiming: .unavailable,
        dmabuf: .unavailable,
        gbm: .unavailable,
        egl: .unavailable,
        presentationFeedback: .unavailable,
        contentType: .unavailable,
        alphaModifier: .unavailable,
        tearingControl: .unavailable,
        colorRepresentation: .unavailable,
        colorManagement: .unavailable
    )

    package init(
        syncobj: SmokePathStatus,
        fifo: SmokePathStatus,
        commitTiming: SmokePathStatus,
        dmabuf: SmokePathStatus,
        gbm: SmokePathStatus,
        egl: SmokePathStatus,
        presentationFeedback: SmokePathStatus,
        contentType: SmokePathStatus,
        alphaModifier: SmokePathStatus,
        tearingControl: SmokePathStatus,
        colorRepresentation: SmokePathStatus,
        colorManagement: SmokePathStatus
    ) {
        self.syncobj = syncobj
        self.fifo = fifo
        self.commitTiming = commitTiming
        self.dmabuf = dmabuf
        self.gbm = gbm
        self.egl = egl
        self.presentationFeedback = presentationFeedback
        self.contentType = contentType
        self.alphaModifier = alphaModifier
        self.tearingControl = tearingControl
        self.colorRepresentation = colorRepresentation
        self.colorManagement = colorManagement
    }

    package var description: String {
        [
            "syncobj: \(syncobj)",
            "fifo: \(fifo)",
            "commitTiming: \(commitTiming)",
            "dmabuf: \(dmabuf)",
            "gbm: \(gbm)",
            "egl: \(egl)",
            "presentationFeedback: \(presentationFeedback)",
            "contentType: \(contentType)",
            "alphaModifier: \(alphaModifier)",
            "tearingControl: \(tearingControl)",
            "colorRepresentation: \(colorRepresentation)",
            "colorManagement: \(colorManagement)",
        ].joined(separator: "\n")
    }
}

package enum SmokeCommand: Equatable, Sendable {
    case run(SmokeConfiguration)
    case help
}

package enum SmokeResult: Equatable, Sendable, CustomStringConvertible {
    case committedFrame(SmokeRuntimeFacts)
    case frameCallbackObserved(SmokeRuntimeFacts)
    case skippedOptionalProtocol(SmokeOptionalProtocol)

    package var description: String {
        switch self {
        case .committedFrame(let facts):
            "committed frame\n\(facts)"
        case .frameCallbackObserved(let facts):
            "frame callback observed\n\(facts)"
        case .skippedOptionalProtocol(let optionalProtocol):
            "Skipping \(optionalProtocol.liveTestName) live test: compositor did not advertise "
                + "\(optionalProtocol.interfaceName)."
        }
    }
}
