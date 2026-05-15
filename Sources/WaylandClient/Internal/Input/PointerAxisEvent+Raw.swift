import WaylandRaw

extension PointerAxisEvent {
    package init(_ raw: RawPointerAxisEvent) {
        switch raw {
        case .axis(let time, let rawAxis, let value):
            self = .axis(
                time: WaylandTimestampMilliseconds(rawValue: time),
                axis: PointerAxis(rawAxis),
                value: value.doubleValue
            )
        case .source(let source):
            self = .source(PointerAxisSource(source))
        case .stop(let time, let axis):
            self = .stop(
                time: WaylandTimestampMilliseconds(rawValue: time),
                axis: PointerAxis(axis)
            )
        case .discrete(let axis, let value):
            self = .discrete(
                axis: PointerAxis(axis),
                value: PointerAxisDiscreteStep(rawValue: value)
            )
        case .value120(let axis, let value120):
            self = .value120(
                axis: PointerAxis(axis),
                value120: PointerAxisValue120(rawValue: value120)
            )
        case .relativeDirection(let axis, let direction):
            self = .relativeDirection(
                axis: PointerAxis(axis),
                direction: PointerAxisRelativeDirection(direction)
            )
        case .frame:
            self = .frame
        }
    }
}
