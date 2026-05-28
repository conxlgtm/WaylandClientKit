import WaylandCursor

package struct ResolvedPointerCursorImage {
    let cursor: PointerCursor
    let size: CursorSize
    let image: CursorImage
}

package enum PointerCursorResolutionState {
    case unresolved
    case resolved(ResolvedPointerCursorImage)
    case unavailable(CursorDiagnostic)

    var resolvedImage: ResolvedPointerCursorImage? {
        switch self {
        case .unresolved, .unavailable:
            nil
        case .resolved(let resolved):
            resolved
        }
    }

    func resolvedImage(size: CursorSize) -> ResolvedPointerCursorImage? {
        guard let resolvedImage, resolvedImage.size == size else { return nil }

        return resolvedImage
    }

    var unavailableDiagnostic: CursorDiagnostic? {
        switch self {
        case .unresolved, .resolved:
            nil
        case .unavailable(let diagnostic):
            diagnostic
        }
    }
}

package enum DesiredPointerCursorState {
    case hidden
    case named(requested: PointerCursor, resolution: PointerCursorResolutionState)

    init(cursor: PointerCursor, resolved: ResolvedPointerCursorImage? = nil) {
        switch cursor.kind {
        case .hidden:
            self = .hidden
        case .named:
            self = .named(
                requested: cursor,
                resolution: resolved.map(PointerCursorResolutionState.resolved) ?? .unresolved
            )
        }
    }

    var cursor: PointerCursor {
        switch self {
        case .hidden:
            .hidden
        case .named(let requested, _):
            requested
        }
    }

    var resolvedImage: ResolvedPointerCursorImage? {
        switch self {
        case .hidden:
            nil
        case .named(_, let resolution):
            resolution.resolvedImage
        }
    }

    func resolvedImage(size: CursorSize) -> ResolvedPointerCursorImage? {
        switch self {
        case .hidden:
            nil
        case .named(_, let resolution):
            resolution.resolvedImage(size: size)
        }
    }

    var unavailableDiagnostic: CursorDiagnostic? {
        switch self {
        case .hidden:
            nil
        case .named(_, let resolution):
            resolution.unavailableDiagnostic
        }
    }

    mutating func cache(_ resolved: ResolvedPointerCursorImage) {
        switch self {
        case .hidden:
            preconditionFailure("hidden cursor cannot cache a cursor image")
        case .named(let requested, _):
            self = .named(requested: requested, resolution: .resolved(resolved))
        }
    }

    mutating func cacheUnavailable(_ diagnostic: CursorDiagnostic) {
        switch self {
        case .hidden:
            preconditionFailure("hidden cursor cannot cache a cursor failure")
        case .named(let requested, _):
            self = .named(requested: requested, resolution: .unavailable(diagnostic))
        }
    }
}
