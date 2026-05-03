extension WindowModel {
    var isDestroyed: Bool {
        lifecycle == .destroyed
    }

    mutating func markPublished() {
        guard publication == .notPublished else { return }
        publication = .published(id)
    }
}
