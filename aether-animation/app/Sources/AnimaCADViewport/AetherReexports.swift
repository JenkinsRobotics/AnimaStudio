// The renderer-neutral contracts moved into Aether Core (AetherKernel +
// AetherViewport). Re-export them so existing `import AnimaCADViewport`
// call sites keep resolving the shared types during the incremental split.
@_exported import AetherKernel
@_exported import AetherViewport
