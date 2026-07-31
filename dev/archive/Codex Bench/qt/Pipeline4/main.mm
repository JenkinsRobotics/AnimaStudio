#import <Cocoa/Cocoa.h>
#import <IOSurface/IOSurface.h>
#include <mach/mach.h>

#include <QtCore/QElapsedTimer>
#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QJsonDocument>
#include <QtCore/QJsonObject>
#include <QtCore/QSocketNotifier>
#include <QtCore/QTimer>
#include <QtGui/QMouseEvent>
#include <QtGui/QWheelEvent>
#include <QtWidgets/QApplication>
#include <QtWidgets/QFileDialog>
#include <QtWidgets/QLabel>
#include <QtWidgets/QMainWindow>
#include <QtWidgets/QToolBar>
#include <QtWidgets/QVBoxLayout>

#include <AIS_InteractiveContext.hxx>
#include <AIS_Shape.hxx>
#include <Aspect_DisplayConnection.hxx>
#include <Cocoa_Window.hxx>
#include <Graphic3d_MaterialAspect.hxx>
#include <Graphic3d_BufferType.hxx>
#include <Image_PixMap.hxx>
#include <OpenGl_GraphicDriver.hxx>
#include <Prs3d_Drawer.hxx>
#include <Prs3d_LineAspect.hxx>
#include <Prs3d_ShadingAspect.hxx>
#include <Quantity_Color.hxx>
#include <Quantity_ColorRGBA.hxx>
#include <Standard_Failure.hxx>
#include <STEPCAFControl_Reader.hxx>
#include <TDocStd_Document.hxx>
#include <TopAbs_ShapeEnum.hxx>
#include <TopoDS_Shape.hxx>
#include <V3d_DirectionalLight.hxx>
#include <V3d_View.hxx>
#include <V3d_Viewer.hxx>
#include <XCAFApp_Application.hxx>
#include <XCAFDoc_ColorTool.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <XCAFDoc_ShapeTool.hxx>
#include <gp_Dir.hxx>

#include "HostedSurfaceBridge.h"

#include <algorithm>
#include <chrono>
#include <cstdio>
#include <cstring>
#include <deque>
#include <exception>
#include <vector>
#include <unistd.h>
#include <sys/resource.h>

namespace {
void writeJson(const QJsonObject &object) {
  const QByteArray data = QJsonDocument(object).toJson(QJsonDocument::Compact);
  std::fwrite(data.constData(), 1, static_cast<size_t>(data.size()), stdout);
  std::fputc('\n', stdout);
  std::fflush(stdout);
}

QJsonObject response(const QJsonObject &request, const char *event) {
  QJsonObject value{{"ok", true}, {"event", event}};
  if (request.contains("id")) value.insert("id", request.value("id"));
  return value;
}

QJsonObject failure(const QJsonObject &request, const QString &message) {
  QJsonObject value{{"ok", false}, {"error", message}};
  if (request.contains("id")) value.insert("id", request.value("id"));
  return value;
}

QString occtFailureMessage(const Standard_Failure &error) {
  const char *message = error.GetMessageString();
  return message == nullptr || message[0] == '\0'
    ? QStringLiteral("Unknown Open CASCADE Technology failure.")
    : QString::fromUtf8(message);
}

double currentCPUSeconds() {
  rusage usage{};
  getrusage(RUSAGE_SELF, &usage);
  return usage.ru_utime.tv_sec + usage.ru_stime.tv_sec
    + (usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1000000.0;
}
}  // namespace

class OcctCanvas final : public QWidget {
 public:
  QLabel *telemetry = nullptr;
  Handle(V3d_View) view;

  explicit OcctCanvas(QWidget *parent = nullptr) : QWidget(parent) {
    setAttribute(Qt::WA_NativeWindow);
    setAttribute(Qt::WA_PaintOnScreen);
    setAttribute(Qt::WA_NoSystemBackground);
    setMouseTracking(true);
    fpsClock.start();
    previousCPUSeconds = currentCPUSeconds();
    auto *timer = new QTimer(this);
    connect(timer, &QTimer::timeout, this, [this] { publishTelemetry(); });
    timer->start(1000);
  }

  ~OcctCanvas() override {
    for (IOSurfaceRef surface : retainedSurfaces) CFRelease(surface);
  }

  QPaintEngine *paintEngine() const override { return nullptr; }

  bool loadSTEP(const QString &path) {
    ensureViewer();
    const auto start = std::chrono::steady_clock::now();
    Handle(TDocStd_Document) document;
    XCAFApp_Application::GetApplication()->NewDocument("MDTV-XCAF", document);
    STEPCAFControl_Reader reader;
    reader.SetColorMode(true);
    reader.SetNameMode(true);
    if (reader.ReadFile(path.toUtf8().constData()) != IFSelect_RetDone
        || !reader.Transfer(document)) {
      message = "STEP read failed: " + path;
      return false;
    }
    Handle(XCAFDoc_ShapeTool) shapes = XCAFDoc_DocumentTool::ShapeTool(document->Main());
    Handle(XCAFDoc_ColorTool) colors = XCAFDoc_DocumentTool::ColorTool(document->Main());
    TDF_LabelSequence roots;
    shapes->GetFreeShapes(roots);
    if (roots.IsEmpty()) {
      message = "STEP contained no shape";
      return false;
    }
    context->RemoveAll(false);
    presentations.clear();
    presentationColors.clear();
    for (Standard_Integer index = 1; index <= roots.Length(); ++index) {
      TopoDS_Shape shape = shapes->GetShape(roots.Value(index));
      if (shape.IsNull()) continue;
      Quantity_Color baseColor = neutral;
      Quantity_ColorRGBA documentColor;
      if (colors->GetColor(roots.Value(index), XCAFDoc_ColorSurf, documentColor)
          || colors->GetColor(roots.Value(index), XCAFDoc_ColorGen, documentColor)
          || colors->GetColor(shape, XCAFDoc_ColorSurf, documentColor)
          || colors->GetColor(shape, XCAFDoc_ColorGen, documentColor)) {
        baseColor = documentColor.GetRGB();
      }
      present(shape, baseColor);
    }
    view->FitAll(0.02, false);
    redraw();
    message = QFileInfo(path).fileName();
    loadMilliseconds = std::chrono::duration<double, std::milli>(
      std::chrono::steady_clock::now() - start).count();
    return true;
  }

  void fit() {
    if (!view.IsNull()) {
      view->FitAll(0.02, false);
      redraw();
    }
  }

  void orbit(double dx, double dy) {
    if (view.IsNull()) return;
    view->Rotate(-dy * 0.006, -dx * 0.006, 0.0, true);
    redraw();
  }

  void panBy(double dx, double dy) {
    if (view.IsNull()) return;
    view->Pan(static_cast<int>(dx), static_cast<int>(-dy));
    redraw();
  }

  void roll(double dx) {
    if (view.IsNull()) return;
    view->SetTwist(view->Twist() + dx * 0.006);
    redraw();
  }

  void zoomBy(double delta) {
    if (view.IsNull()) return;
    view->SetZoom(delta < 0 ? 1.08 : 0.92, true);
    redraw();
  }

  void setTheme(const QJsonObject &request) {
    background = readColor(request, "background", background);
    neutral = readColor(request, "neutral", neutral);
    edge = readColor(request, "edge", edge);
    selection = readColor(request, "selection", selection);
    keyColor = readColor(request, "key", keyColor);
    fillColor = readColor(request, "fill", fillColor);
    rimColor = readColor(request, "rim", rimColor);
    roughness = std::clamp(request.value("roughness").toDouble(roughness), 0.0, 1.0);
    metallic = std::clamp(request.value("metallic").toDouble(metallic), 0.0, 1.0);
    keyIntensity = request.value("keyIntensity").toDouble(keyIntensity);
    fillIntensity = request.value("fillIntensity").toDouble(fillIntensity);
    rimIntensity = request.value("rimIntensity").toDouble(rimIntensity);
    ensureViewer();
    applyTheme();
    redraw();
  }

  IOSurfaceRef renderSurface(int requestedWidth, int requestedHeight) {
    ensureViewer();
    const int width = std::clamp(requestedWidth, 64, 4096);
    const int height = std::clamp(requestedHeight, 64, 4096);
    Image_PixMap image;
    if (!view->ToPixMap(image, width, height, Graphic3d_BT_RGB, true)) {
      renderError = "Open CASCADE Technology failed to create an offscreen buffer.";
      return nullptr;
    }

    const size_t bytesPerRow = static_cast<size_t>(width) * 4;
    NSDictionary *properties = @{
      (__bridge NSString *)kIOSurfaceWidth: @(width),
      (__bridge NSString *)kIOSurfaceHeight: @(height),
      (__bridge NSString *)kIOSurfaceBytesPerElement: @4,
      (__bridge NSString *)kIOSurfaceBytesPerRow: @(bytesPerRow),
      (__bridge NSString *)kIOSurfaceAllocSize: @(bytesPerRow * static_cast<size_t>(height)),
      (__bridge NSString *)kIOSurfacePixelFormat: @((uint32_t)'BGRA'),
    };
    IOSurfaceRef surface = IOSurfaceCreate((__bridge CFDictionaryRef)properties);
    if (surface == nullptr) return nullptr;
    IOSurfaceLock(surface, 0, nullptr);
    auto *destination = static_cast<unsigned char *>(IOSurfaceGetBaseAddress(surface));
    for (int row = 0; row < height; ++row) {
      auto *output = destination + static_cast<size_t>(row) * bytesPerRow;
      for (int column = 0; column < width; ++column) {
        const Quantity_ColorRGBA color = image.PixelColor(column, row);
        output[column * 4 + 0] = static_cast<unsigned char>(std::clamp(color.GetRGB().Blue(), 0.0, 1.0) * 255.0);
        output[column * 4 + 1] = static_cast<unsigned char>(std::clamp(color.GetRGB().Green(), 0.0, 1.0) * 255.0);
        output[column * 4 + 2] = static_cast<unsigned char>(std::clamp(color.GetRGB().Red(), 0.0, 1.0) * 255.0);
        output[column * 4 + 3] = 255;
      }
    }
    IOSurfaceUnlock(surface, 0, nullptr);
    retainedSurfaces.push_back(surface);
    while (retainedSurfaces.size() > 3) {
      CFRelease(retainedSurfaces.front());
      retainedSurfaces.pop_front();
    }
    frames += 1;
    renderError.clear();
    return surface;
  }

  double loadTimeMilliseconds() const { return loadMilliseconds; }
  double lastFramesPerSecond() const { return lastFPS; }
  double lastMemoryMegabytes() const { return memoryMB; }
  double lastCPUPercent() const { return cpuPercent; }
  const QString &lastRenderError() const { return renderError; }

 protected:
  void showEvent(QShowEvent *event) override {
    QWidget::showEvent(event);
    ensureViewer();
  }
  void resizeEvent(QResizeEvent *event) override {
    QWidget::resizeEvent(event);
    if (!view.IsNull()) view->MustBeResized();
  }
  void paintEvent(QPaintEvent *) override { redraw(); }
  void mousePressEvent(QMouseEvent *event) override {
    lastPoint = event->position().toPoint();
    dragged = false;
    if (event->button() == Qt::RightButton && !view.IsNull())
      view->StartRotation(lastPoint.x(), lastPoint.y());
  }
  void mouseMoveEvent(QMouseEvent *event) override {
    if (view.IsNull()) return;
    const QPoint point = event->position().toPoint();
    if (event->buttons() & Qt::RightButton) {
      if (event->modifiers() & Qt::ShiftModifier) {
        view->SetTwist(view->Twist() + (point.x() - lastPoint.x()) * 0.006);
      } else {
        view->Rotation(point.x(), point.y());
      }
      dragged = true;
      redraw();
    } else if (event->buttons() & Qt::MiddleButton) {
      QPoint delta = point - lastPoint;
      view->Pan(delta.x(), -delta.y());
      dragged = true;
      redraw();
    } else if (!context.IsNull()) {
      context->MoveTo(point.x(), point.y(), view, true);
      frames += 1;
    }
    lastPoint = point;
  }
  void mouseReleaseEvent(QMouseEvent *event) override {
    if (dragged || context.IsNull() || view.IsNull() || event->button() != Qt::LeftButton) return;
    QPoint point = event->position().toPoint();
    context->MoveTo(point.x(), point.y(), view, false);
    context->SelectDetected(AIS_SelectionScheme_XOR);
    redraw();
  }
  void wheelEvent(QWheelEvent *event) override {
    if (view.IsNull()) return;
    view->SetZoom(event->angleDelta().y() > 0 ? 1.08 : 0.92, true);
    redraw();
  }

 private:
  Handle(AIS_InteractiveContext) context;
  Handle(V3d_Viewer) viewer;
  Handle(V3d_DirectionalLight) keyLight;
  Handle(V3d_DirectionalLight) fillLight;
  Handle(V3d_DirectionalLight) rimLight;
  std::vector<Handle(AIS_Shape)> presentations;
  std::vector<Quantity_Color> presentationColors;
  QPoint lastPoint;
  bool dragged = false;
  int frames = 0;
  double loadMilliseconds = 0;
  double lastFPS = 0;
  double memoryMB = 0;
  double cpuPercent = 0;
  double previousCPUSeconds = 0;
  QElapsedTimer fpsClock;
  QString message = "Open a STEP assembly";
  QString renderError;
  std::deque<IOSurfaceRef> retainedSurfaces;
  Quantity_Color background = Quantity_Color(0.16, 0.17, 0.19, Quantity_TOC_RGB);
  Quantity_Color neutral = Quantity_Color(0.72, 0.74, 0.78, Quantity_TOC_RGB);
  Quantity_Color edge = Quantity_Color(0.16, 0.18, 0.22, Quantity_TOC_RGB);
  Quantity_Color selection = Quantity_Color(1.0, 0.48, 0.0, Quantity_TOC_RGB);
  Quantity_Color keyColor = Quantity_Color(1.0, 1.0, 1.0, Quantity_TOC_RGB);
  Quantity_Color fillColor = Quantity_Color(0.75, 0.82, 1.0, Quantity_TOC_RGB);
  Quantity_Color rimColor = Quantity_Color(1.0, 1.0, 1.0, Quantity_TOC_RGB);
  double roughness = 0.5;
  double metallic = 0.0;
  double keyIntensity = 0.75;
  double fillIntensity = 0.3;
  double rimIntensity = 0.225;

  static Quantity_Color readColor(
      const QJsonObject &request, const QString &prefix, const Quantity_Color &fallback) {
    const QString red = prefix + "Red";
    const QString green = prefix + "Green";
    const QString blue = prefix + "Blue";
    return Quantity_Color(request.value(red).toDouble(fallback.Red()),
                          request.value(green).toDouble(fallback.Green()),
                          request.value(blue).toDouble(fallback.Blue()), Quantity_TOC_RGB);
  }

  void applyPresentationTheme(
      const Handle(AIS_Shape) &presentation, const Quantity_Color &baseColor) {
    Graphic3d_MaterialAspect material(Graphic3d_NOM_DEFAULT);
    const double shine = std::clamp((1.0 - roughness) * 0.9 + 0.05, 0.05, 0.95);
    const Quantity_Color specular(
        1.0 * (1.0 - metallic) + baseColor.Red() * metallic,
        1.0 * (1.0 - metallic) + baseColor.Green() * metallic,
        1.0 * (1.0 - metallic) + baseColor.Blue() * metallic, Quantity_TOC_RGB);
    material.SetAmbientColor(baseColor);
    material.SetDiffuseColor(baseColor);
    material.SetSpecularColor(specular);
    material.SetShininess(static_cast<Standard_ShortReal>(shine));
    presentation->SetMaterial(material);
    presentation->SetColor(baseColor);
    const Handle(Prs3d_Drawer) &drawer = presentation->Attributes();
    drawer->SetFaceBoundaryDraw(Standard_True);
    drawer->SetFaceBoundaryAspect(new Prs3d_LineAspect(edge, Aspect_TOL_SOLID, 1.15));
  }

  void applyTheme() {
    if (viewer.IsNull() || view.IsNull()) return;
    view->SetBackgroundColor(background);
    if (keyLight.IsNull()) {
      keyLight = new V3d_DirectionalLight(gp_Dir(-0.5, -0.9, -0.6), keyColor, false);
      fillLight = new V3d_DirectionalLight(gp_Dir(0.7, -0.3, -0.4), fillColor, false);
      rimLight = new V3d_DirectionalLight(gp_Dir(-0.1, -0.5, 0.8), rimColor, false);
      viewer->SetLightOn(keyLight);
      viewer->SetLightOn(fillLight);
      viewer->SetLightOn(rimLight);
    }
    keyLight->SetColor(keyColor);
    fillLight->SetColor(fillColor);
    rimLight->SetColor(rimColor);
    keyLight->SetIntensity(static_cast<Standard_ShortReal>(std::max(keyIntensity, 0.01)));
    fillLight->SetIntensity(static_cast<Standard_ShortReal>(std::max(fillIntensity, 0.01)));
    rimLight->SetIntensity(static_cast<Standard_ShortReal>(std::max(rimIntensity, 0.01)));
    if (!context.IsNull()) {
      for (Prs3d_TypeOfHighlight style : {
               Prs3d_TypeOfHighlight_Dynamic, Prs3d_TypeOfHighlight_LocalDynamic,
               Prs3d_TypeOfHighlight_Selected, Prs3d_TypeOfHighlight_LocalSelected}) {
        const Handle(Prs3d_Drawer) &drawer = context->HighlightStyle(style);
        drawer->ShadingAspect()->SetColor(selection);
        drawer->LineAspect()->SetColor(selection);
      }
      for (size_t index = 0; index < presentations.size(); ++index) {
        applyPresentationTheme(presentations[index], presentationColors[index]);
        context->Redisplay(presentations[index], false);
      }
    }
  }

  void present(const TopoDS_Shape &shape, const Quantity_Color &color) {
    Handle(AIS_Shape) presentation = new AIS_Shape(shape);
    applyPresentationTheme(presentation, color);
    presentations.push_back(presentation);
    presentationColors.push_back(color);
    context->Display(presentation, AIS_Shaded, -1, false);
    context->Deactivate(presentation);
    context->Activate(presentation, AIS_Shape::SelectionMode(TopAbs_FACE));
  }

  void ensureViewer() {
    if (!view.IsNull()) return;
    Handle(Aspect_DisplayConnection) displayConnection = new Aspect_DisplayConnection();
    Handle(OpenGl_GraphicDriver) driver = new OpenGl_GraphicDriver(displayConnection, false);
    viewer = new V3d_Viewer(driver);
    view = viewer->CreateView();
    Handle(Cocoa_Window) window = new Cocoa_Window(reinterpret_cast<NSView *>(winId()));
    view->SetWindow(window);
    if (!window->IsMapped()) window->Map();
    view->SetBackgroundColor(background);
    view->TriedronDisplay(Aspect_TOTP_LEFT_LOWER, Quantity_NOC_WHITE, 0.08);
    context = new AIS_InteractiveContext(viewer);
    context->SetDisplayMode(AIS_Shaded, false);
    applyTheme();
  }

  void redraw() {
    if (!view.IsNull()) {
      view->Redraw();
      frames += 1;
    }
  }

  void publishTelemetry() {
    const double elapsed = std::max(fpsClock.restart() / 1000.0, 0.001);
    task_vm_info_data_t info{};
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    task_info(mach_task_self(), TASK_VM_INFO, reinterpret_cast<task_info_t>(&info), &count);
    memoryMB = double(info.phys_footprint) / 1048576.0;
    const double cpu = currentCPUSeconds();
    cpuPercent = std::max(0.0, (cpu - previousCPUSeconds) / elapsed * 100.0);
    previousCPUSeconds = cpu;
    lastFPS = frames / elapsed;
    const char *pipeline = "P4 Qt 6 + Open CASCADE Technology desktop OpenGL";
    if (telemetry != nullptr) {
      telemetry->setText(QString("%1  |  %2  |  Load %3 ms  |  FPS %4  |  Memory %5 MB")
        .arg(pipeline).arg(message).arg(loadMilliseconds, 0, 'f', 1)
        .arg(lastFPS, 0, 'f', 1).arg(memoryMB, 0, 'f', 1));
    }
    frames = 0;
  }
};

int main(int argc, char **argv) {
  QApplication application(argc, argv);
  const bool hosted = argc > 1 && QString::fromUtf8(argv[1]) == "--hosted";
  QString surfaceService;
  for (int index = 2; index + 1 < argc; ++index) {
    if (QString::fromUtf8(argv[index]) == "--surface-service") {
      surfaceService = QString::fromUtf8(argv[index + 1]);
      break;
    }
  }
  if (hosted) [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];

  QMainWindow window;
  window.setWindowTitle("Codex Bench — Qt 6 + Open CASCADE Technology pipeline");
  auto *container = new QWidget;
  auto *layout = new QVBoxLayout(container);
  layout->setContentsMargins(0, 0, 0, 0);
  auto *telemetry = new QLabel("Starting Open CASCADE Technology viewer…");
  telemetry->setMargin(7);
  auto *canvas = new OcctCanvas;
  canvas->telemetry = telemetry;
  layout->addWidget(telemetry);
  layout->addWidget(canvas, 1);
  window.setCentralWidget(container);
  auto *toolbar = window.addToolBar("Benchmark");
  toolbar->addAction("Open STEP…", [&] {
    QString path = QFileDialog::getOpenFileName(&window, "Open STEP", {}, "STEP (*.step *.stp)");
    if (!path.isEmpty()) canvas->loadSTEP(path);
  });
  toolbar->addAction("Fit", [&] { canvas->fit(); });
  window.resize(1200, 800);
  if (hosted) {
    window.move(-12'000, -12'000);
    window.setWindowOpacity(0.0);
    window.show();
    QFile *input = new QFile(&application);
    if (!input->open(STDIN_FILENO, QIODevice::ReadOnly, QFileDevice::DontCloseHandle)) {
      writeJson(QJsonObject{{"ok", false}, {"error", "Could not open the hosted command pipe."}});
      return EXIT_FAILURE;
    }
    auto *notifier = new QSocketNotifier(STDIN_FILENO, QSocketNotifier::Read, &application);
    QObject::connect(notifier, &QSocketNotifier::activated, &application, [&, input] {
      const QByteArray line = input->readLine();
      if (!line.isEmpty()) {
        const QJsonDocument document = QJsonDocument::fromJson(line.trimmed());
        const QJsonObject request = document.object();
        const QString verb = request.value("verb").toString();
        try {
          if (verb == "load") {
            const QString path = request.value("path").toString();
            if (!canvas->loadSTEP(path)) {
              writeJson(failure(request, "Could not load STEP file in hosted Open CASCADE Technology renderer."));
              return;
            }
            auto result = response(request, "loaded");
            result.insert("load_ms", canvas->loadTimeMilliseconds());
            writeJson(result);
          } else if (verb == "render") {
            const int width = request.value("width").toInt(960);
            const int height = request.value("height").toInt(640);
            IOSurfaceRef surface = canvas->renderSurface(width, height);
            static uint32_t sequence = 0;
            if (surface == nullptr) {
              writeJson(failure(request, canvas->lastRenderError().isEmpty()
                ? "Open CASCADE Technology could not render a hosted frame." : canvas->lastRenderError()));
              return;
            }
            sequence += 1;
            if (surfaceService.isEmpty()
                || !GBHostedSurfaceSend(surfaceService.toUtf8().constData(), surface,
                                        static_cast<uint32_t>(width), static_cast<uint32_t>(height),
                                        sequence)) {
              writeJson(failure(request, "Could not transfer the IOSurface to the Swift host."));
              return;
            }
            auto result = response(request, "frame");
            result.insert("sequence", static_cast<double>(sequence));
            result.insert("width", width);
            result.insert("height", height);
            result.insert("load_ms", canvas->loadTimeMilliseconds());
            result.insert("fps", canvas->lastFramesPerSecond());
            result.insert("memory_mb", canvas->lastMemoryMegabytes());
            result.insert("cpu_percent", canvas->lastCPUPercent());
            writeJson(result);
          } else if (verb == "orbit") {
            canvas->orbit(request.value("x").toDouble(), request.value("y").toDouble());
            writeJson(response(request, "camera"));
          } else if (verb == "pan") {
            canvas->panBy(request.value("x").toDouble(), request.value("y").toDouble());
            writeJson(response(request, "camera"));
          } else if (verb == "roll") {
            canvas->roll(request.value("x").toDouble());
            writeJson(response(request, "camera"));
          } else if (verb == "zoom") {
            canvas->zoomBy(request.value("x").toDouble());
            writeJson(response(request, "camera"));
          } else if (verb == "fit") {
            canvas->fit();
            writeJson(response(request, "camera"));
          } else if (verb == "theme") {
            canvas->setTheme(request);
            writeJson(response(request, "camera"));
          } else if (verb == "shutdown") {
            writeJson(response(request, "shutdown"));
            application.quit();
          } else {
            writeJson(failure(request, "Unknown hosted renderer verb: " + verb));
          }
        } catch (const Standard_Failure &error) {
          writeJson(failure(request, "Open CASCADE Technology: " + occtFailureMessage(error)));
        } catch (const std::exception &error) {
          writeJson(failure(request, "Hosted renderer: " + QString::fromUtf8(error.what())));
        } catch (...) {
          writeJson(failure(request, "Hosted renderer encountered an unknown native error."));
        }
      }
    });
    writeJson(QJsonObject{{"ok", true}, {"event", "ready"}});
  } else {
    window.show();
    if (argc > 1) canvas->loadSTEP(QString::fromUtf8(argv[1]));
  }
  return application.exec();
}
