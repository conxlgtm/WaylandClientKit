import WaylandGraphicsPreview

// This client must not compile: software presentation cannot carry a GPU requirement.
let invalidConfiguration = WaylandGraphicsConfiguration(
    presentationMode: .software,
    fallbackPolicy: .requireGPU
)

print(invalidConfiguration)
