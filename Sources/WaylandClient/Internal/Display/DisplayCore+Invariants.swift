extension DisplayCore {
    package func checkInvariantsForTesting() throws {
        try surfaces.checkInvariantsForTesting()
    }

    func assertSurfaceStoreInvariants() {
        #if DEBUG
            do {
                try surfaces.checkInvariants()
            } catch {
                preconditionFailure("DisplayCore surface store invariant failed: \(error)")
            }
        #endif
    }
}
