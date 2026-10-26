import WaylandGraphicsPreview

func borrowAcrossCancel(_ renderLease: consuming WaylandGraphicsExternalBufferRenderLease) async {
    let buffer = Ref(renderLease.buffer)
    await renderLease.cancel()
    print(buffer.value.id)
}
