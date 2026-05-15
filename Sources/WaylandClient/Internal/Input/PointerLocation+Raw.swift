import WaylandRaw

extension PointerLocation {
    package init(x positionX: WaylandFixed, y positionY: WaylandFixed) {
        self.init(x: positionX.doubleValue, y: positionY.doubleValue)
    }
}
