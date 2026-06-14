import WaylandRaw

extension TabletID {
    package init(_ raw: RawTabletIdentity) {
        self.init(rawValue: raw.objectID.value)
    }
}

extension TabletToolID {
    package init(_ raw: RawTabletToolIdentity) {
        self.init(rawValue: raw.objectID.value)
    }
}

extension TabletPadID {
    package init(_ raw: RawTabletPadIdentity) {
        self.init(rawValue: raw.objectID.value)
    }
}

extension TabletBusType {
    package init(_ raw: RawTabletBusType) {
        self.init(rawValue: raw.rawValue)
    }
}

extension TabletToolType {
    package init(_ raw: RawTabletToolType) {
        self.init(rawValue: raw.rawValue)
    }
}

extension TabletToolCapability {
    package init(_ raw: RawTabletToolCapability) {
        self.init(rawValue: raw.rawValue)
    }
}
