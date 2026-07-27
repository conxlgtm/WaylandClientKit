import WaylandGraphicsPreview

func useRenderLeaseTwice(
    _ renderLease: consuming WaylandGraphicsExternalBufferRenderLease
) async {
    let duplicate = renderLease
    await renderLease.cancel()
    await duplicate.cancel()
}
