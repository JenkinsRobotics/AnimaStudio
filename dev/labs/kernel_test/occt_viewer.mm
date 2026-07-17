// Standalone native OCCT viewer — Open CASCADE's BUILT-IN visualization
// (AIS/V3d/OpenGl) in a plain Cocoa window. No Qt, no web stack, no Rust.
//
//   ./occt_viewer ["/path/to/part.stl"]
//
// Displays: the STL (left) + an exact B-rep box-with-bore-and-fillets (right)
// so tessellated-mesh and exact-geometry rendering are shown side by side.
// Mouse: left-drag orbit · middle-drag pan · scroll zoom.
#import <Cocoa/Cocoa.h>

#include <AIS_InteractiveContext.hxx>
#include <AIS_Shape.hxx>
#include <Aspect_DisplayConnection.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRep_Builder.hxx>
#include <Bnd_Box.hxx>
#include <Cocoa_Window.hxx>
#include <OpenGl_GraphicDriver.hxx>
#include <Poly_Triangulation.hxx>
#include <Quantity_Color.hxx>
#include <RWStl.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <V3d_View.hxx>
#include <V3d_Viewer.hxx>
#include <gp_Trsf.hxx>

static Handle(V3d_View) gView;
static Handle(AIS_InteractiveContext) gContext;

@interface OcctView : NSView
@end

@implementation OcctView {
  NSPoint _lastPoint;
}
- (BOOL)acceptsFirstResponder { return YES; }
- (void)drawRect:(NSRect)rect {
  if (!gView.IsNull()) gView->Redraw();
}
- (void)setFrameSize:(NSSize)newSize {
  [super setFrameSize:newSize];
  if (!gView.IsNull()) gView->MustBeResized();
}
- (void)mouseDown:(NSEvent *)e {
  _lastPoint = [self convertPoint:e.locationInWindow fromView:nil];
  if (!gView.IsNull())
    gView->StartRotation((Standard_Integer)_lastPoint.x,
                         (Standard_Integer)(self.bounds.size.height - _lastPoint.y));
}
- (void)mouseDragged:(NSEvent *)e {
  NSPoint p = [self convertPoint:e.locationInWindow fromView:nil];
  if (!gView.IsNull())
    gView->Rotation((Standard_Integer)p.x,
                    (Standard_Integer)(self.bounds.size.height - p.y));
  _lastPoint = p;
}
- (void)otherMouseDragged:(NSEvent *)e {
  if (!gView.IsNull()) gView->Pan((Standard_Integer)e.deltaX, (Standard_Integer)-e.deltaY);
}
- (void)scrollWheel:(NSEvent *)e {
  if (gView.IsNull()) return;
  Standard_Real zoom = 1.0 + (e.deltaY > 0 ? 0.1 : -0.1);
  gView->SetZoom(zoom, true);
}
@end

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property(strong) NSWindow *window;
@property(copy) NSString *stlPath;
@end

@implementation AppDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)note {
  NSRect frame = NSMakeRect(120, 120, 1100, 760);
  self.window = [[NSWindow alloc]
      initWithContentRect:frame
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                          NSWindowStyleMaskResizable
                  backing:NSBackingStoreBuffered
                    defer:NO];
  self.window.title = [NSString
      stringWithFormat:@"OCCT Native Viewer — %@", self.stlPath.lastPathComponent];
  OcctView *view = [[OcctView alloc] initWithFrame:frame];
  view.wantsBestResolutionOpenGLSurface = NO;
  self.window.contentView = view;
  [self.window makeKeyAndOrderFront:nil];
  [NSApp activateIgnoringOtherApps:YES];

  // --- OCCT's built-in renderer wired straight to the NSView -------------
  Handle(Aspect_DisplayConnection) display = new Aspect_DisplayConnection();
  Handle(OpenGl_GraphicDriver) driver = new OpenGl_GraphicDriver(display, false);
  Handle(V3d_Viewer) viewer = new V3d_Viewer(driver);
  viewer->SetDefaultLights();
  viewer->SetLightOn();
  gView = viewer->CreateView();
  Handle(Cocoa_Window) occtWindow = new Cocoa_Window((__bridge NSView *)view);
  gView->SetWindow(occtWindow);
  if (!occtWindow->IsMapped()) occtWindow->Map();
  gView->SetBackgroundColor(Quantity_Color(0.08, 0.09, 0.11, Quantity_TOC_RGB));
  gView->TriedronDisplay(Aspect_TOTP_LEFT_LOWER, Quantity_NOC_WHITE, 0.08);
  gContext = new AIS_InteractiveContext(viewer);
  gContext->SetDisplayMode(AIS_Shaded, false);

  // --- The user's STL: a face carrying only triangulation renders shaded --
  Handle(Poly_Triangulation) mesh =
      RWStl::ReadFile(self.stlPath.fileSystemRepresentation);
  double stlWidth = 100.0;
  if (!mesh.IsNull()) {
    TopoDS_Face meshFace;
    BRep_Builder builder;
    builder.MakeFace(meshFace);
    builder.UpdateFace(meshFace, mesh, TopLoc_Location(), false);
    Handle(AIS_Shape) stlShape = new AIS_Shape(meshFace);
    stlShape->SetColor(Quantity_Color(0.32, 0.75, 0.72, Quantity_TOC_RGB));
    gContext->Display(stlShape, AIS_Shaded, -1, false);
    Bnd_Box box;
    BRepBndLib::Add(meshFace, box);
    Standard_Real x0, y0, z0, x1, y1, z1;
    box.Get(x0, y0, z0, x1, y1, z1);
    stlWidth = x1 - x0;
    printf("STL displayed: %d triangles, %.1f x %.1f x %.1f mm\n",
           mesh->NbTriangles(), x1 - x0, y1 - y0, z1 - z0);
  } else {
    printf("STL READ FAILED: %s\n", self.stlPath.UTF8String);
  }

  // --- Exact B-rep neighbor: bored + filleted block (true CAD geometry) ---
  TopoDS_Shape block = BRepPrimAPI_MakeBox(40.0, 30.0, 20.0).Shape();
  gp_Ax2 boreAxis(gp_Pnt(20.0, 15.0, -1.0), gp_Dir(0, 0, 1));
  TopoDS_Shape bored =
      BRepAlgoAPI_Cut(block, BRepPrimAPI_MakeCylinder(boreAxis, 6.0, 22.0).Shape())
          .Shape();
  BRepFilletAPI_MakeFillet fillet(bored);
  for (TopExp_Explorer it(bored, TopAbs_EDGE); it.More(); it.Next())
    fillet.Add(2.0, TopoDS::Edge(it.Current()));
  gp_Trsf offset;
  offset.SetTranslation(gp_Vec(stlWidth * 0.75, 0, 0));
  TopoDS_Shape part = BRepBuilderAPI_Transform(fillet.Shape(), offset).Shape();
  Handle(AIS_Shape) partShape = new AIS_Shape(part);
  partShape->SetColor(Quantity_Color(0.85, 0.55, 0.20, Quantity_TOC_RGB));
  gContext->Display(partShape, AIS_Shaded, -1, false);
  printf("B-rep part displayed (exact geometry, tessellated by the kernel)\n");

  gView->FitAll(0.02, false);
  gView->Redraw();
  printf("Viewer up. left-drag orbit / middle-drag pan / scroll zoom\n");
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app {
  return YES;
}
@end

int main(int argc, char **argv) {
  @autoreleasepool {
    NSString *stl =
        argc > 1
            ? [NSString stringWithUTF8String:argv[1]]
            : @"/Users/jonathanjenkins/Documents/AnimaStudio/single part/"
              @"characters/test-part/assets/ARCADA001 - Part 1 (2).stl";
    NSApplication *app = [NSApplication sharedApplication];
    [app setActivationPolicy:NSApplicationActivationPolicyRegular];
    AppDelegate *delegate = [[AppDelegate alloc] init];
    delegate.stlPath = stl;
    app.delegate = delegate;
    [app run];
  }
  return 0;
}
