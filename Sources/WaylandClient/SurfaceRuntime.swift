import WaylandRaw

struct SurfaceRuntime<RoleResources> {
    var roleResources: RoleResources?
    var buffers: RawSharedMemoryPool?
    var retiredBufferPools: [RawSharedMemoryPool] = []
    var scaleInstallation = SurfaceScaleInstallation()
}
