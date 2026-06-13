import Foundation
import Testing
import WaylandClient
import WaylandGraphicsPreview

@Suite
struct WaylandTinyUIPrototypeTests {
    @Test
    func tinyRetainedTreeCanLayoutAndDrawThroughPublicSoftwareFrame() throws {
        let view = TinyView.vstack([
            .colorRect(ColorRect(color: 0x0024_3448)),
            .label(LabelPlaceholder(text: "WaylandClientKit")),
            .colorRect(ColorRect(color: 0x0050_3020)),
        ])
        let layout = try TinyLayout().layout(
            view,
            in: try PositiveLogicalSize(width: 180, height: 90)
        )

        #expect(layout.rects.count == 3)
        #expect(layout.rects.first?.rect.origin == .zero)
    }

    @Test
    func tinyPrototypeHostShapeUsesGraphicsPreviewSoftwareSubmission() async throws {
        func render(display: WaylandDisplay) async throws {
            let backing = try await display.createGraphicsWindowBacking(
                windowConfiguration: try WindowConfiguration(
                    title: "Tiny UI Prototype",
                    appID: "tiny-ui-prototype",
                    initialWidth: 160,
                    initialHeight: 100
                ),
                graphicsConfiguration: WaylandGraphicsConfiguration(
                    fallbackPolicy: .forceSoftware,
                    presentationFeedbackPolicy: .requestWhenAvailable
                )
            )
            let view = TinyView.vstack([
                .colorRect(ColorRect(color: 0x0020_2020)),
                .label(LabelPlaceholder(text: "prototype")),
            ])
            let lease = try await backing.nextFrame()
            let result = try await lease.submitSoftware { frame in
                try TinyRenderer().draw(view, into: frame)
            }

            #expect(result.operation == .show || result.operation == .redraw)
            try await backing.close()
        }

        _ = render
    }
}

enum TinyView: Equatable, Sendable {
    case colorRect(ColorRect)
    case label(LabelPlaceholder)
    indirect case vstack([TinyView])
}

struct ColorRect: Equatable, Sendable {
    var color: UInt32
}

struct LabelPlaceholder: Equatable, Sendable {
    var text: String
}

struct TinyLayout: Sendable {
    struct PlacedRect: Equatable, Sendable {
        var rect: LogicalRect
        var color: UInt32
    }

    struct Result: Equatable, Sendable {
        var rects: [PlacedRect]
    }

    func layout(_ view: TinyView, in size: PositiveLogicalSize) throws -> Result {
        switch view {
        case .colorRect(let rect):
            return Result(
                rects: [
                    PlacedRect(
                        rect: LogicalRect(origin: .zero, size: size),
                        color: rect.color
                    )
                ]
            )
        case .label:
            return Result(
                rects: [
                    PlacedRect(
                        rect: LogicalRect(origin: .zero, size: size),
                        color: 0x0018_1820
                    )
                ]
            )
        case .vstack(let children):
            guard !children.isEmpty else { return Result(rects: []) }
            let childHeight = max(size.height.rawValue / Int32(children.count), 1)
            var y: Int32 = 0
            var rects: [PlacedRect] = []
            for child in children {
                let height = min(childHeight, size.height.rawValue - y)
                guard height > 0 else { break }
                let childSize = try PositiveLogicalSize(
                    width: size.width.rawValue,
                    height: height
                )
                let childLayout = try layout(child, in: childSize)
                rects.append(
                    contentsOf: childLayout.rects.map { placed in
                        PlacedRect(
                            rect: LogicalRect(
                                origin: LogicalOffset(
                                    x: placed.rect.origin.x,
                                    y: placed.rect.origin.y + y
                                ),
                                size: placed.rect.size
                            ),
                            color: placed.color
                        )
                    }
                )
                y += height
            }
            return Result(rects: rects)
        }
    }
}

struct TinyRenderer: Sendable {
    func draw(_ view: TinyView, into frame: borrowing SoftwareFrame) throws {
        let layout = try TinyLayout().layout(view, in: frame.geometry.logicalSize)
        frame.withXRGB8888Rows { row, pixels in
            for index in 0..<pixels.count {
                pixels[unchecked: index] = 0x0010_1010
            }
            for placed in layout.rects where rowIsInside(row, placed.rect, frame.geometry) {
                fillRow(
                    &pixels,
                    rect: placed.rect,
                    geometry: frame.geometry,
                    color: placed.color
                )
            }
        }
    }

    private func rowIsInside(
        _ row: Int,
        _ rect: LogicalRect,
        _ geometry: SoftwareFrameGeometry
    ) -> Bool {
        let top = geometry.bufferPixelPoint(logicalX: 0, logicalY: Double(rect.origin.y)).y
        let bottom = geometry.bufferPixelPoint(
            logicalX: 0,
            logicalY: Double(rect.origin.y + rect.size.height.rawValue)
        ).y
        return row >= top && row < bottom
    }

    private func fillRow(
        _ pixels: inout MutableSpan<UInt32>,
        rect: LogicalRect,
        geometry: SoftwareFrameGeometry,
        color: UInt32
    ) {
        let start = geometry.bufferPixelPoint(logicalX: Double(rect.origin.x), logicalY: 0).x
        let end = geometry.bufferPixelPoint(
            logicalX: Double(rect.origin.x + rect.size.width.rawValue),
            logicalY: 0
        ).x
        let clampedStart = max(0, min(start, pixels.count))
        let clampedEnd = max(clampedStart, min(end, pixels.count))
        guard clampedStart < clampedEnd else { return }
        for index in clampedStart..<clampedEnd {
            pixels[unchecked: index] = color
        }
    }
}
