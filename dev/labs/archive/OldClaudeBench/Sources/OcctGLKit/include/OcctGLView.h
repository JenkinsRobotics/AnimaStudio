// Pipeline 3: OCCT's built-in V3d/AIS viewer (TKOpenGl, desktop OpenGL)
// hosted in an NSView, for wrapping in SwiftUI via NSViewRepresentable.
// Native OCCT face hover-highlight + click selection included.
#import <Cocoa/Cocoa.h>

@interface OcctGLView : NSView

/// Load and display a STEP file. Returns load seconds, or -1 on failure.
- (double)loadStepAtPath:(NSString *)path;

/// Redraws since last query (drives the FPS counter), then resets.
- (NSInteger)takeRedrawCount;

@end
