extension Sequence where Element == WindowRedrawEffect {
    func mapRedrawRequested<Effect>(
        _ makeEffect: () -> Effect
    ) -> [Effect] {
        map { effect in
            switch effect {
            case .publishRedrawRequested:
                makeEffect()
            }
        }
    }
}
