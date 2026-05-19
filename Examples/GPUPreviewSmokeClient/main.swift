import WaylandClient
import WaylandGraphicsPreview

@main
struct GPUPreviewSmokeClient {
    static func main() async throws {
        try await WaylandDisplay.withConnection { display in
            let runtimePath = try await display.graphicsRuntimePath()
            print("graphics backing: \(runtimePath.backing)")
            print("dmabuf: \(runtimePath.dmabuf)")
            print("presentation feedback: \(runtimePath.presentationFeedback)")

            let window = try await display.createTopLevelWindow(
                configuration: WindowConfiguration(
                    title: "SwiftWayland Graphics Preview",
                    appID: "swift-wayland-graphics-preview",
                    initialWidth: 96,
                    initialHeight: 96,
                    bufferCount: 2
                )
            )
            try await window.show { frame in
                clear(frame)
            }
            await window.close()
        }
    }

    nonisolated private static func clear(_ frame: borrowing SoftwareFrame) {
        frame.withXRGB8888Rows { row, pixels in
            for column in 0..<pixels.count {
                let red = UInt32((column * 255) / max(pixels.count, 1))
                let blue = UInt32((row * 255) / max(Int(frame.height), 1))
                unsafe pixels[unchecked: column] = (red << 16) | 0x3F00 | blue
            }
        }
    }
}
