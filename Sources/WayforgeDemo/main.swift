import WaylandClient

@main
enum WayforgeDemo {
    static func main() {
        print("Wayforge demo bootstrap")
        _ = WaylandClientBootstrap.ready
    }
}
