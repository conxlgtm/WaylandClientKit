import WaylandRaw

extension DragLocation {
    package init(x positionX: WaylandFixed, y positionY: WaylandFixed) {
        self.init(x: positionX.doubleValue, y: positionY.doubleValue)
    }
}
