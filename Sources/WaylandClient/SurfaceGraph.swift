import WaylandRaw

package struct SurfaceID: Hashable, Sendable, CustomStringConvertible {
    package let rawValue: UInt64

    package init(rawValue surfaceRawValue: UInt64) {
        rawValue = surfaceRawValue
    }

    package init(rawObjectID objectID: RawObjectID) {
        rawValue = UInt64(objectID.value)
    }

    package var description: String {
        "surface-\(rawValue)"
    }
}

package enum SurfaceRole: Equatable, Sendable {
    case toplevel(windowID: WindowID)
    case popup(popupID: PopupID, parent: SurfaceID)
}

package struct SurfaceNode: Equatable, Sendable {
    package let id: SurfaceID
    package let windowID: WindowID
    package let root: SurfaceID
    package var role: SurfaceRole
    package var children: [SurfaceID]

    package init(
        id surfaceID: SurfaceID,
        windowID surfaceWindowID: WindowID,
        root rootSurfaceID: SurfaceID,
        role surfaceRole: SurfaceRole,
        children surfaceChildren: [SurfaceID] = []
    ) {
        id = surfaceID
        windowID = surfaceWindowID
        root = rootSurfaceID
        role = surfaceRole
        children = surfaceChildren
    }
}

package enum SurfaceGraphError: Error, Equatable, Sendable {
    case duplicateSurface(SurfaceID)
    case duplicatePopup(PopupID)
    case unknownSurface(SurfaceID)
    case unknownParent(SurfaceID)
    case nonTopmostPopupDestroy(requested: SurfaceID, topmost: SurfaceID?)
    case toplevelDestroyedWithLivePopups(WindowID)
}

package struct PopupStack: Equatable, Sendable {
    private(set) package var stack: [SurfaceID] = []

    package init() {
        // Starts with no active popup roles.
    }

    package var topmost: SurfaceID? {
        stack.last
    }

    package mutating func push(_ popupSurfaceID: SurfaceID) {
        stack.append(popupSurfaceID)
    }

    package mutating func destroyTopmost(_ popupSurfaceID: SurfaceID) throws -> SurfaceID {
        guard topmost == popupSurfaceID else {
            throw SurfaceGraphError.nonTopmostPopupDestroy(
                requested: popupSurfaceID,
                topmost: topmost
            )
        }

        return stack.removeLast()
    }

    package mutating func dismissFromCompositor(_ popupSurfaceID: SurfaceID) throws -> [SurfaceID] {
        guard let index = stack.firstIndex(of: popupSurfaceID) else {
            throw SurfaceGraphError.unknownSurface(popupSurfaceID)
        }

        let dismissed = Array(stack[index...].reversed())
        stack.removeSubrange(index...)
        return dismissed
    }

    package mutating func destroyCascade(from popupSurfaceID: SurfaceID) throws -> [SurfaceID] {
        guard let index = stack.firstIndex(of: popupSurfaceID) else {
            throw SurfaceGraphError.unknownSurface(popupSurfaceID)
        }

        let destroyed = Array(stack[index...].reversed())
        stack.removeSubrange(index...)
        return destroyed
    }
}

package struct SurfaceGraph: Equatable, Sendable {
    private(set) package var nodes: [SurfaceID: SurfaceNode] = [:]
    private(set) package var popupStacksByRoot: [SurfaceID: PopupStack] = [:]
    private(set) package var livePopupSurfacesByID: [PopupID: SurfaceID] = [:]

    package init() {
        // Starts with no role surfaces registered.
    }

    package mutating func registerTopLevel(
        surfaceID: SurfaceID,
        windowID: WindowID
    ) throws {
        guard nodes[surfaceID] == nil else {
            throw SurfaceGraphError.duplicateSurface(surfaceID)
        }

        nodes[surfaceID] = SurfaceNode(
            id: surfaceID,
            windowID: windowID,
            root: surfaceID,
            role: .toplevel(windowID: windowID)
        )
        popupStacksByRoot[surfaceID] = PopupStack()
    }

    package mutating func registerPopup(
        surfaceID: SurfaceID,
        popupID: PopupID,
        parent parentID: SurfaceID
    ) throws {
        guard nodes[surfaceID] == nil else {
            throw SurfaceGraphError.duplicateSurface(surfaceID)
        }
        guard livePopupSurfacesByID[popupID] == nil else {
            throw SurfaceGraphError.duplicatePopup(popupID)
        }
        guard let parent = nodes[parentID] else {
            throw SurfaceGraphError.unknownParent(parentID)
        }
        var stack = try requirePopupStack(for: parent.root)

        nodes[surfaceID] = SurfaceNode(
            id: surfaceID,
            windowID: parent.windowID,
            root: parent.root,
            role: .popup(popupID: popupID, parent: parentID)
        )
        nodes[parentID]?.children.append(surfaceID)
        livePopupSurfacesByID[popupID] = surfaceID
        stack.push(surfaceID)
        popupStacksByRoot[parent.root] = stack
    }

    @discardableResult
    package mutating func destroyClientRequestedPopup(
        _ surfaceID: SurfaceID
    ) throws -> SurfaceNode {
        let node = try requirePopupNode(surfaceID)
        var stack = try requirePopupStack(for: node.root)
        let destroyedID = try stack.destroyTopmost(surfaceID)
        popupStacksByRoot[node.root] = stack
        return try removePopupNode(destroyedID)
    }

    @discardableResult
    package mutating func destroyClientRequestedPopupCascade(
        _ surfaceID: SurfaceID
    ) throws -> [SurfaceNode] {
        let node = try requirePopupNode(surfaceID)
        var stack = try requirePopupStack(for: node.root)
        let destroyedIDs = try stack.destroyCascade(from: surfaceID)
        popupStacksByRoot[node.root] = stack
        return try destroyedIDs.map { destroyedID in
            try removePopupNode(destroyedID)
        }
    }

    @discardableResult
    package mutating func dismissPopupFromCompositor(
        _ surfaceID: SurfaceID
    ) throws -> [SurfaceNode] {
        let node = try requirePopupNode(surfaceID)
        var stack = try requirePopupStack(for: node.root)
        let dismissedIDs = try stack.dismissFromCompositor(surfaceID)
        popupStacksByRoot[node.root] = stack
        return try dismissedIDs.map { dismissedID in
            try removePopupNode(dismissedID)
        }
    }

    package mutating func unregisterTopLevel(_ surfaceID: SurfaceID) throws {
        guard let node = nodes[surfaceID] else {
            throw SurfaceGraphError.unknownSurface(surfaceID)
        }
        guard case .toplevel(let windowID) = node.role else {
            throw SurfaceGraphError.unknownSurface(surfaceID)
        }
        guard node.children.isEmpty else {
            throw SurfaceGraphError.toplevelDestroyedWithLivePopups(windowID)
        }

        nodes.removeValue(forKey: surfaceID)
        popupStacksByRoot.removeValue(forKey: surfaceID)
    }

    package func windowID(for surfaceID: SurfaceID) throws -> WindowID {
        guard let node = nodes[surfaceID] else {
            throw SurfaceGraphError.unknownSurface(surfaceID)
        }

        return node.windowID
    }

    package func popupNodesTopDown(parentedBy windowID: WindowID) -> [SurfaceNode] {
        popupStacksByRoot
            .filter { root, _ in nodes[root]?.windowID == windowID }
            .flatMap { _, stack in stack.stack.reversed() }
            .compactMap { surfaceID in nodes[surfaceID] }
    }

    private func requirePopupNode(_ surfaceID: SurfaceID) throws -> SurfaceNode {
        guard let node = nodes[surfaceID] else {
            throw SurfaceGraphError.unknownSurface(surfaceID)
        }
        guard case .popup = node.role else {
            throw SurfaceGraphError.unknownSurface(surfaceID)
        }

        return node
    }

    private func requirePopupStack(for root: SurfaceID) throws -> PopupStack {
        guard let stack = popupStacksByRoot[root] else {
            throw SurfaceGraphError.unknownSurface(root)
        }

        return stack
    }

    private mutating func removePopupNode(_ surfaceID: SurfaceID) throws -> SurfaceNode {
        let node = try requirePopupNode(surfaceID)
        guard case .popup(let popupID, let parentID) = node.role else {
            throw SurfaceGraphError.unknownSurface(surfaceID)
        }

        nodes.removeValue(forKey: surfaceID)
        livePopupSurfacesByID.removeValue(forKey: popupID)
        nodes[parentID]?.children.removeAll { childID in
            childID == surfaceID
        }
        return node
    }
}
