import WaylandRaw

extension PointerLocation {
    package init(waylandX positionX: WaylandFixed, waylandY positionY: WaylandFixed) {
        self.init(x: positionX.doubleValue, y: positionY.doubleValue)
    }
}
