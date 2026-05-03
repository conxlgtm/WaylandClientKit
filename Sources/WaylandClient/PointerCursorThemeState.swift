import WaylandCursor

package struct ResolvedPointerCursorImage {
    let cursor: PointerCursor
    let image: CursorImage
}

package enum DesiredPointerCursorState {
    case hidden
    case named(requested: PointerCursor, resolved: ResolvedPointerCursorImage?)

    init(cursor: PointerCursor, resolved: ResolvedPointerCursorImage? = nil) {
        switch cursor.kind {
        case .hidden:
            self = .hidden
        case .named:
            self = .named(requested: cursor, resolved: resolved)
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
        case .named(_, let resolved):
            resolved
        }
    }

    mutating func cache(_ resolved: ResolvedPointerCursorImage) {
        switch self {
        case .hidden:
            preconditionFailure("hidden cursor cannot cache a cursor image")
        case .named(let requested, _):
            self = .named(requested: requested, resolved: resolved)
        }
    }
}
