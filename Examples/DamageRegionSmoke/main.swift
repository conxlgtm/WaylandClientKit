import Foundation
import WaylandClient
import WaylandExampleSupport

@main
enum DamageRegionSmoke {
    static func main() async throws {
        let options = try ExampleRunOptions.parse(CommandLine.arguments.dropFirst())

        try await WaylandDisplay.withConnection(
            applicationID: "org.waylandclientkit.DamageRegionSmoke",
            eventStreamConfiguration: try EventStreamConfiguration(
                displayEventCapacity: 64,
                inputEventCapacity: 16,
                textInputEventCapacity: 16,
                dataTransferEventCapacity: 16,
                presentationEventCapacity: 16
            )
        ) { display in
            log("feature: surface-damage")
            log("capability: wl_surface damage_buffer path")
            let window = try await display.createTopLevelWindow(
                configuration: try WindowConfiguration(
                    title: "WaylandClientKit Damage Region Smoke",
                    appID: "wayland-client-kit-damage-region-smoke",
                    initialWidth: 360,
                    initialHeight: 220,
                    closeRequestPolicy: .requestOnly
                )
            )
            let animation = DamageAnimationState()

            try await window.show { frame in
                draw(frame, phase: 0)
            }
            log("operation: show-initial-frame pass")

            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { try await consumeDisplayEvents(display.events, window: window) }
                group.addTask { try await animate(window: window, animation: animation) }
                if let autoCloseSeconds = options.autoCloseSeconds {
                    group.addTask {
                        try await Task.sleep(for: .seconds(autoCloseSeconds))
                        await window.close()
                    }
                }

                _ = try await group.next()
                group.cancelAll()
            }

            if options.printSummary {
                log(await animation.summary())
            }
            log("result: pass")
            log("cleanup: pass")
        }
    }

    nonisolated private static func consumeDisplayEvents(
        _ events: DisplayEvents,
        window: Window
    ) async throws {
        var iterator = events.makeAsyncIterator()
        while !Task.isCancelled, let event = try await iterator.next() {
            switch event {
            case .windowCloseRequested(let windowID) where windowID == window.id:
                await window.close()
            case .windowClosed(let windowID) where windowID == window.id:
                return
            case .diagnostic(let diagnostic):
                log("display diagnostic \(diagnostic)")
            default:
                break
            }
        }
    }

    nonisolated private static func animate(
        window: Window,
        animation: DamageAnimationState
    ) async throws {
        while !Task.isCancelled {
            try await Task.sleep(for: .milliseconds(100))
            guard try await !window.isClosed else { return }

            let geometry = try await window.geometry
            let frame = try await animation.nextFrame(logicalSize: geometry.logicalSize)
            try await window.redraw(damage: frame.damage) { softwareFrame in
                draw(softwareFrame, phase: frame.phase)
            }
            log("operation: submit-partial-damage pass")
            log(
                "submitted logical damage \(frame.damage.rectangles); mapped buffer estimate \(bufferDamageDescription(frame.damage, geometry: geometry))"
            )
        }
    }

    nonisolated private static func draw(_ frame: borrowing SoftwareFrame, phase: Int) {
        let boxSize = max(min(Int(frame.width), Int(frame.height)) / 5, 8)
        let travel = max(Int(frame.width) - boxSize, 1)
        let boxX = (phase * 9) % travel
        let boxY = max((Int(frame.height) - boxSize) / 2, 0)

        frame.withXRGB8888Rows { row, pixels in
            for x in 0..<Int(frame.width) {
                let inBox = x >= boxX && x < boxX + boxSize && row >= boxY && row < boxY + boxSize
                let base = UInt32((row * 128) / max(Int(frame.height), 1))
                unsafe pixels[unchecked: x] = inBox ? 0x00E0_8030 : 0x0018_1820 | (base << 8)
            }
        }
    }

    nonisolated private static func bufferDamageDescription(
        _ damage: SurfaceDamageRegion,
        geometry: SurfaceGeometry
    ) -> String {
        let scaleNumerator = Int64(geometry.scale.numerator)
        let scaleDenominator = Int64(geometry.scale.denominator)
        let mapped = damage.rectangles.map { rectangle in
            let x = floorScaled(rectangle.origin.x, scaleNumerator, scaleDenominator)
            let y = floorScaled(rectangle.origin.y, scaleNumerator, scaleDenominator)
            let right = ceilScaled(
                rectangle.origin.x + rectangle.size.width.rawValue,
                scaleNumerator,
                scaleDenominator
            )
            let bottom = ceilScaled(
                rectangle.origin.y + rectangle.size.height.rawValue,
                scaleNumerator,
                scaleDenominator
            )
            return "x=\(x) y=\(y) w=\(max(right - x, 1)) h=\(max(bottom - y, 1))"
        }
        return "[\(mapped.joined(separator: "; "))]"
    }

    nonisolated private static func floorScaled(
        _ value: Int32,
        _ numerator: Int64,
        _ denominator: Int64
    ) -> Int64 {
        Int64(value) * numerator / denominator
    }

    nonisolated private static func ceilScaled(
        _ value: Int32,
        _ numerator: Int64,
        _ denominator: Int64
    ) -> Int64 {
        let scaled = Int64(value) * numerator
        return (scaled + denominator - 1) / denominator
    }

    nonisolated private static func log(_ message: String) {
        print("[DamageRegionSmoke] \(message)")
    }
}

struct DamageFrame: Sendable {
    let phase: Int
    let damage: SurfaceDamageRegion
}

actor DamageAnimationState {
    private var phase = 0
    private var previousBox: LogicalRect?
    private var submittedFrames = 0

    func nextFrame(logicalSize: PositiveLogicalSize) throws -> DamageFrame {
        let boxWidth = max(logicalSize.width.rawValue / 5, 8)
        let boxHeight = max(logicalSize.height.rawValue / 5, 8)
        let travel = max(logicalSize.width.rawValue - boxWidth, 1)
        let x = Int32((phase * 9) % Int(travel))
        let y = max((logicalSize.height.rawValue - boxHeight) / 2, 0)
        let box = try LogicalRect(x: x, y: y, width: boxWidth, height: boxHeight)
        var damageRectangles = [box]
        if let previousBox {
            damageRectangles.append(previousBox)
        }

        let frame = try DamageFrame(
            phase: phase,
            damage: SurfaceDamageRegion(damageRectangles)
        )
        previousBox = box
        phase += 1
        submittedFrames += 1
        return frame
    }

    func summary() -> String {
        "damage region summary frames=\(submittedFrames)"
    }
}
