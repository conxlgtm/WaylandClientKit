import WaylandGraphicsPreview

func useFrameLeaseTwice(_ frameLease: consuming WaylandGraphicsFrameLease) async {
    let duplicate = frameLease
    await frameLease.cancel()
    await duplicate.cancel()
}
