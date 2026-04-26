import WaylandClient
import WaylandRaw

@main
enum SwiftWaylandDemo {
    static func main() throws {
        let connection = try RawDisplayConnection.connect()
        try connection.completeInitialDiscovery()

        let window = try TopLevelWindow(connection: connection)
        try window.show(drawDemoFrame)

        while !window.isClosed {
            try connection.pumpEvents(timeoutMilliseconds: 16)
            if window.needsRedraw {
                try window.redraw(drawDemoFrame)
            }
        }
    }

    private static func drawDemoFrame(_ frame: SoftwareFrame) {
        frame.withXRGB8888Rows { row, pixels in
            for x in 0..<Int(frame.width) {
                let red = UInt32((x * 255) / max(Int(frame.width), 1))
                let green = UInt32((row * 255) / max(Int(frame.height), 1))
                let blue = UInt32(0x80)
                pixels[unchecked: x] = (red << 16) | (green << 8) | blue
            }
        }
    }
}
