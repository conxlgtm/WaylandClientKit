import WaylandClient

public enum SmokeRunner {
    public static func run(configuration: SmokeConfiguration = .init()) throws -> SmokeResult {
        let session = try DisplaySession.connect()
        let window = try session.createTopLevelWindow(
            configuration: WindowConfiguration(
                title: "SwiftWayland Smoke",
                appID: "swift-wayland-smoke",
                initialWidth: 64,
                initialHeight: 64,
                bufferCount: 2
            )
        )
        defer { window.close() }

        try window.show(timeoutMilliseconds: configuration.timeoutMilliseconds) { frame in
            fill(frame)
        }

        try session.pumpEvents(
            timeoutMilliseconds: configuration.postCommitPumpMilliseconds
        )
        _ = session.drainInputEvents()

        if window.needsRedraw {
            return .frameCallbackObserved
        }

        return .committedFrame
    }

    private static func fill(_ frame: SoftwareFrame) {
        frame.withXRGB8888Rows { row, pixels in
            for column in 0..<pixels.count {
                let red = UInt32((column * 255) / max(pixels.count, 1))
                let green = UInt32((row * 255) / max(Int(frame.height), 1))
                pixels[unchecked: column] = (red << 16) | (green << 8) | 0x40
            }
        }
    }
}
