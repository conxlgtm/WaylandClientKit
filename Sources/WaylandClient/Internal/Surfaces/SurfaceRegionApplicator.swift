import WaylandRaw

package enum SurfaceRegionApplicator {
    package static func makeRawRegion(
        _ region: SurfaceRegion?,
        compositor: RawCompositor
    ) throws -> RawRegion? {
        try makeRawRegion(region) {
            try compositor.createRegion()
        }
    }

    package static func makeRawRegion(
        _ region: SurfaceRegion?,
        createRegion: () throws -> RawRegion
    ) throws -> RawRegion? {
        guard let region else { return nil }

        let rawRegion = try createRegion()
        for rectangle in region.rectangles {
            rawRegion.add(
                x: rectangle.origin.x,
                y: rectangle.origin.y,
                width: rectangle.size.width.rawValue,
                height: rectangle.size.height.rawValue
            )
        }
        return rawRegion
    }

    package static func apply(
        _ region: SurfaceRegion?,
        compositor: RawCompositor,
        setRegion: (RawRegion?) -> Void
    ) throws {
        try apply(
            region,
            createRegion: {
                try compositor.createRegion()
            },
            setRegion: setRegion
        )
    }

    package static func apply(
        _ region: SurfaceRegion?,
        createRegion: () throws -> RawRegion,
        setRegion: (RawRegion?) -> Void
    ) throws {
        let rawRegion = try makeRawRegion(region, createRegion: createRegion)
        defer { rawRegion?.destroy() }

        setRegion(rawRegion)
    }
}
