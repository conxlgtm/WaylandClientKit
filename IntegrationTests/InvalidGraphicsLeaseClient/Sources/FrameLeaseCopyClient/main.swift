import WaylandGraphicsPreview

func useFrameLeaseTwice(_ lease: WaylandGraphicsFrameLease) async {
    let duplicate = lease
    await lease.cancel()
    await duplicate.cancel()
}
