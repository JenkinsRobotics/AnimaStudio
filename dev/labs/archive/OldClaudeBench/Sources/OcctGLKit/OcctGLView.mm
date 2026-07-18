// OCCT built-in viewer in an NSView. Mouse: left/right-drag orbit,
// middle-drag pan, scroll zoom, click select face (OCCT-native highlight).
#import "include/OcctGLView.h"

#include <chrono>

#include <AIS_InteractiveContext.hxx>
#include <AIS_Shape.hxx>
#include <Aspect_DisplayConnection.hxx>
#include <Cocoa_Window.hxx>
#include <OpenGl_GraphicDriver.hxx>
#include <Quantity_Color.hxx>
#include <STEPControl_Reader.hxx>
#include <TopAbs_ShapeEnum.hxx>
#include <TopoDS_Shape.hxx>
#include <V3d_View.hxx>
#include <V3d_Viewer.hxx>

@implementation OcctGLView {
  Handle(V3d_View) _view;
  Handle(AIS_InteractiveContext) _context;
  NSInteger _redraws;
  BOOL _dragged;
}

- (BOOL)acceptsFirstResponder {
  return YES;
}

- (void)ensureViewer {
  if (!_view.IsNull()) return;
  Handle(Aspect_DisplayConnection) display = new Aspect_DisplayConnection();
  Handle(OpenGl_GraphicDriver) driver = new OpenGl_GraphicDriver(display, false);
  Handle(V3d_Viewer) viewer = new V3d_Viewer(driver);
  viewer->SetDefaultLights();
  viewer->SetLightOn();
  _view = viewer->CreateView();
  Handle(Cocoa_Window) window = new Cocoa_Window((NSView *)self);
  _view->SetWindow(window);
  if (!window->IsMapped()) window->Map();
  _view->SetBackgroundColor(Quantity_Color(0.08, 0.09, 0.11, Quantity_TOC_RGB));
  _view->TriedronDisplay(Aspect_TOTP_LEFT_LOWER, Quantity_NOC_WHITE, 0.08);
  _context = new AIS_InteractiveContext(viewer);
  _context->SetDisplayMode(AIS_Shaded, false);
}

- (double)loadStepAtPath:(NSString *)path {
  [self ensureViewer];
  auto t0 = std::chrono::steady_clock::now();
  STEPControl_Reader reader;
  if (reader.ReadFile(path.fileSystemRepresentation) != IFSelect_RetDone) {
    return -1;
  }
  reader.TransferRoots();
  TopoDS_Shape shape = reader.OneShape();
  if (shape.IsNull()) return -1;
  _context->RemoveAll(false);
  Handle(AIS_Shape) ais = new AIS_Shape(shape);
  ais->SetColor(Quantity_Color(0.34, 0.62, 0.85, Quantity_TOC_RGB));
  _context->Display(ais, AIS_Shaded, -1, false);
  _context->Deactivate(ais);
  _context->Activate(ais, AIS_Shape::SelectionMode(TopAbs_FACE));
  _view->FitAll(0.02, false);
  [self redrawCounted];
  return std::chrono::duration<double>(std::chrono::steady_clock::now() - t0)
      .count();
}

- (void)redrawCounted {
  if (_view.IsNull()) return;
  _view->Redraw();
  _redraws += 1;
}

- (NSInteger)takeRedrawCount {
  NSInteger count = _redraws;
  _redraws = 0;
  return count;
}

- (void)drawRect:(NSRect)rect {
  [self ensureViewer];
  [self redrawCounted];
}

- (void)setFrameSize:(NSSize)newSize {
  [super setFrameSize:newSize];
  if (!_view.IsNull()) {
    _view->MustBeResized();
    [self redrawCounted];
  }
}

- (NSPoint)occtPoint:(NSEvent *)event {
  NSPoint p = [self convertPoint:event.locationInWindow fromView:nil];
  return NSMakePoint(p.x, self.bounds.size.height - p.y);
}

- (void)mouseDown:(NSEvent *)event {
  _dragged = NO;
  NSPoint p = [self occtPoint:event];
  if (!_view.IsNull()) _view->StartRotation((int)p.x, (int)p.y);
}

- (void)rightMouseDown:(NSEvent *)event {
  NSPoint p = [self occtPoint:event];
  if (!_view.IsNull()) _view->StartRotation((int)p.x, (int)p.y);
}

- (void)mouseDragged:(NSEvent *)event {
  _dragged = YES;
  NSPoint p = [self occtPoint:event];
  if (!_view.IsNull()) {
    _view->Rotation((int)p.x, (int)p.y);
    [self redrawCounted];
  }
}

- (void)rightMouseDragged:(NSEvent *)event {
  [self mouseDragged:event];
}

- (void)otherMouseDragged:(NSEvent *)event {
  if (_view.IsNull()) return;
  _view->Pan((int)event.deltaX, (int)-event.deltaY);
  [self redrawCounted];
}

- (void)mouseMoved:(NSEvent *)event {
  if (_view.IsNull() || _context.IsNull()) return;
  NSPoint p = [self occtPoint:event];
  _context->MoveTo((int)p.x, (int)p.y, _view, true);
  _redraws += 1;
}

- (void)mouseUp:(NSEvent *)event {
  if (_dragged || _view.IsNull() || _context.IsNull()) return;
  NSPoint p = [self occtPoint:event];
  _context->MoveTo((int)p.x, (int)p.y, _view, false);
  _context->SelectDetected(AIS_SelectionScheme_XOR);
  [self redrawCounted];
}

- (void)scrollWheel:(NSEvent *)event {
  if (_view.IsNull()) return;
  _view->SetZoom(event.scrollingDeltaY > 0 ? 1.08 : 0.92, true);
  _redraws += 1;
}

- (void)viewDidMoveToWindow {
  [super viewDidMoveToWindow];
  // Hover highlight needs move events.
  NSTrackingArea *area = [[NSTrackingArea alloc]
      initWithRect:NSZeroRect
           options:NSTrackingMouseMoved | NSTrackingActiveInKeyWindow
                   | NSTrackingInVisibleRect
             owner:self
          userInfo:nil];
  [self addTrackingArea:area];
}

@end
