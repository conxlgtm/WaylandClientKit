package enum DisplayResourceTableError<ID: Hashable & Sendable>: Error, Equatable {
    case duplicateID(ID)
}

package struct DisplayResourceTable<ID: Hashable & Sendable, Resource> {
    private var resourcesByID: [ID: Resource]

    package init() {
        resourcesByID = [:]
    }

    package var ids: [ID] {
        Array(resourcesByID.keys)
    }

    package var isEmpty: Bool {
        resourcesByID.isEmpty
    }

    package mutating func insert(_ resource: Resource, id: ID) throws {
        guard resourcesByID[id] == nil else {
            throw DisplayResourceTableError<ID>.duplicateID(id)
        }

        resourcesByID[id] = resource
    }

    package func get(_ id: ID) -> Resource? {
        resourcesByID[id]
    }

    package mutating func remove(_ id: ID) -> Resource? {
        resourcesByID.removeValue(forKey: id)
    }

    package mutating func removeAll() -> [Resource] {
        let resources = Array(resourcesByID.values)
        resourcesByID.removeAll()
        return resources
    }
}
