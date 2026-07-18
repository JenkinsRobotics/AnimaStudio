// PIPELINE 3 bench — Qt + Open CASCADE's BUILT-IN AIS viewer.
// The OCCT V3d/AIS renderer draws straight into the Qt widget's NSView via
// Cocoa_Window. Face hover-highlight and click-selection are OCCT built-ins.
// Deliberately NO MetalANGLE: this runs on Apple's deprecated-but-working
// system OpenGL — experiencing that trade-off first-hand is the point of
// this bench. Mouse: right/left-drag orbit · middle-drag pan · wheel zoom ·
// click select face.
#import <Cocoa/Cocoa.h>

#include <QtWidgets/QApplication>
#include <QtWidgets/QFileDialog>
#include <QtWidgets/QLabel>
#include <QtWidgets/QMainWindow>
#include <QtWidgets/QToolBar>
#include <QtWidgets/QVBoxLayout>
#include <QtGui/QMouseEvent>
#include <QtGui/QWheelEvent>

#include <AIS_InteractiveContext.hxx>
#include <AIS_Shape.hxx>
#include <Aspect_DisplayConnection.hxx>
#include <Cocoa_Window.hxx>
#include <OpenGl_GraphicDriver.hxx>
#include <Quantity_Color.hxx>
#include <STEPControl_Reader.hxx>
#include <StdSelect_BRepOwner.hxx>
#include <TopAbs_ShapeEnum.hxx>
#include <TopoDS_Shape.hxx>
#include <V3d_View.hxx>
#include <V3d_Viewer.hxx>

#include <chrono>

class OcctWidget : public QWidget {
public:
  Handle(V3d_View) view;
  Handle(AIS_InteractiveContext) context;
  QLabel *statusLabel = nullptr;

  OcctWidget(QWidget *parent = nullptr) : QWidget(parent) {
    setAttribute(Qt::WA_NativeWindow);
    setAttribute(Qt::WA_PaintOnScreen);
    setAttribute(Qt::WA_NoSystemBackground);
    setMouseTracking(true);  // hover highlight needs move events
  }

  QPaintEngine *paintEngine() const override { return nullptr; }

  void initViewer() {
    if (!view.IsNull()) return;
    Handle(Aspect_DisplayConnection) display = new Aspect_DisplayConnection();
    Handle(OpenGl_GraphicDriver) driver = new OpenGl_GraphicDriver(display, false);
    Handle(V3d_Viewer) viewer = new V3d_Viewer(driver);
    viewer->SetDefaultLights();
    viewer->SetLightOn();
    view = viewer->CreateView();
    NSView *nsView = reinterpret_cast<NSView *>(winId());
    Handle(Cocoa_Window) window = new Cocoa_Window(nsView);
    view->SetWindow(window);
    if (!window->IsMapped()) window->Map();
    view->SetBackgroundColor(Quantity_Color(0.08, 0.09, 0.11, Quantity_TOC_RGB));
    view->TriedronDisplay(Aspect_TOTP_LEFT_LOWER, Quantity_NOC_WHITE, 0.08);
    context = new AIS_InteractiveContext(viewer);
    context->SetDisplayMode(AIS_Shaded, false);
  }

  void loadStep(const QString &path) {
    initViewer();
    auto t0 = std::chrono::steady_clock::now();
    STEPControl_Reader reader;
    if (reader.ReadFile(path.toUtf8().constData()) != IFSelect_RetDone) {
      statusLabel->setText("STEP READ FAILED: " + path);
      return;
    }
    reader.TransferRoots();
    TopoDS_Shape shape = reader.OneShape();
    if (shape.IsNull()) {
      statusLabel->setText("STEP produced no shape: " + path);
      return;
    }
    context->RemoveAll(false);
    Handle(AIS_Shape) ais = new AIS_Shape(shape);
    ais->SetColor(Quantity_Color(0.34, 0.62, 0.85, Quantity_TOC_RGB));
    context->Display(ais, AIS_Shaded, -1, false);
    // OCCT-native FACE picking: hover highlight + click selection built in.
    context->Deactivate(ais);
    context->Activate(ais, AIS_Shape::SelectionMode(TopAbs_FACE));
    view->FitAll(0.02, false);
    view->Redraw();
    double seconds =
        std::chrono::duration<double>(std::chrono::steady_clock::now() - t0)
            .count();
    statusLabel->setText(QString("%1 — loaded in %2s · OCCT GL viewer · hover a face, click to select")
                             .arg(QFileInfo(path).fileName())
                             .arg(seconds, 0, 'f', 2));
  }

protected:
  void showEvent(QShowEvent *event) override {
    QWidget::showEvent(event);
    initViewer();
  }
  void resizeEvent(QResizeEvent *event) override {
    QWidget::resizeEvent(event);
    if (!view.IsNull()) view->MustBeResized();
  }
  void paintEvent(QPaintEvent *) override {
    if (!view.IsNull()) view->Redraw();
  }
  void mousePressEvent(QMouseEvent *event) override {
    lastPos = event->pos();
    if (event->buttons() & (Qt::LeftButton | Qt::RightButton)) {
      if (!view.IsNull()) view->StartRotation(event->pos().x(), event->pos().y());
    }
    dragged = false;
  }
  void mouseMoveEvent(QMouseEvent *event) override {
    if (view.IsNull()) return;
    if (event->buttons() & (Qt::LeftButton | Qt::RightButton)) {
      view->Rotation(event->pos().x(), event->pos().y());
      dragged = true;
    } else if (event->buttons() & Qt::MiddleButton) {
      QPoint delta = event->pos() - lastPos;
      view->Pan(delta.x(), -delta.y());
      dragged = true;
    } else if (!context.IsNull()) {
      // Hover: OCCT's dynamic highlight of the face under the cursor.
      context->MoveTo(event->pos().x(), event->pos().y(), view, true);
    }
    lastPos = event->pos();
  }
  void mouseReleaseEvent(QMouseEvent *event) override {
    if (view.IsNull() || context.IsNull() || dragged) return;
    if (event->button() == Qt::LeftButton) {
      context->MoveTo(event->pos().x(), event->pos().y(), view, false);
      context->SelectDetected(AIS_SelectionScheme_XOR);
      view->Redraw();
    }
  }
  void wheelEvent(QWheelEvent *event) override {
    if (view.IsNull()) return;
    double factor = event->angleDelta().y() > 0 ? 1.1 : 0.9;
    view->SetZoom(factor, true);
  }

private:
  QPoint lastPos;
  bool dragged = false;
};

int main(int argc, char **argv) {
  QApplication app(argc, argv);
  QMainWindow window;
  window.setWindowTitle("PIPELINE 3 — Qt + OCCT built-in GL viewer (no MetalANGLE)");

  auto *central = new QWidget;
  auto *layout = new QVBoxLayout(central);
  layout->setContentsMargins(0, 0, 0, 0);
  auto *status = new QLabel("Open a STEP file…  (system OpenGL — deprecated on macOS; that trade-off is what this bench demonstrates)");
  status->setMargin(6);
  auto *occt = new OcctWidget;
  occt->statusLabel = status;
  layout->addWidget(status);
  layout->addWidget(occt, 1);
  window.setCentralWidget(central);

  auto *toolbar = window.addToolBar("Main");
  toolbar->addAction("Open STEP…", [&] {
    QString path = QFileDialog::getOpenFileName(
        &window, "Open STEP", QString(), "STEP files (*.step *.stp)");
    if (!path.isEmpty()) occt->loadStep(path);
  });
  toolbar->addAction("Fit", [&] {
    if (!occt->view.IsNull()) {
      occt->view->FitAll(0.02, false);
      occt->view->Redraw();
    }
  });

  window.resize(1100, 760);
  window.show();
  if (argc > 1) occt->loadStep(QString::fromUtf8(argv[1]));
  return app.exec();
}
