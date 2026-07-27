import WaylandGraphicsPreview

func useRenderLeaseTwice(_ lease: WaylandGraphicsExternalBufferRenderLease) async {
    let duplicate = lease
    await lease.cancel()
    await duplicate.cancel()
}
