#import <AppKit/AppKit.h>
#import <IOSurface/IOSurface.h>
#include <mach/mach.h>

#include <QtCore/QElapsedTimer>
#include <QtCore/QFile>
#include <QtCore/QJsonArray>
#include <QtCore/QJsonDocument>
#include <QtCore/QJsonObject>
#include <QtCore/QSocketNotifier>
#include <QtCore/QTimer>
#include <QtCore/QUrl>
#include <QtWebEngineCore/QWebEngineSettings>
#include <QtWebEngineWidgets/QWebEngineView>
#include <QtWidgets/QApplication>
#include <QtWidgets/QMainWindow>

#include "GeomShim.h"
#include "HostedSurfaceBridge.h"

#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <optional>
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
  QJsonObject result{{"ok", true}, {"event", event}};
  if (request.contains("id")) result.insert("id", request.value("id"));
  return result;
}

QJsonObject failure(const QJsonObject &request, const QString &message) {
  QJsonObject result{{"ok", false}, {"error", message}};
  if (request.contains("id")) result.insert("id", request.value("id"));
  return result;
}

QJsonArray colorArray(const QJsonObject &request, const QString &prefix) {
  return {
    request.value(prefix + "Red").toDouble(),
    request.value(prefix + "Green").toDouble(),
    request.value(prefix + "Blue").toDouble(),
  };
}

double currentMemoryMegabytes() {
  task_vm_info_data_t info{};
  mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
  if (task_info(mach_task_self(), TASK_VM_INFO,
                reinterpret_cast<task_info_t>(&info), &count) != KERN_SUCCESS) return 0;
  return static_cast<double>(info.phys_footprint) / 1048576.0;
}

double currentCPUSeconds() {
  rusage usage{};
  getrusage(RUSAGE_SELF, &usage);
  return usage.ru_utime.tv_sec + usage.ru_stime.tv_sec
    + (usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1000000.0;
}

QJsonObject meshPayload(const GBDocument &document) {
  QJsonArray positions;
  QJsonArray normals;
  QJsonArray colors;
  QJsonArray indices;
  QJsonArray edgePositions;
  for (uint32_t index = 0; index < document.vertex_count * 3; ++index) {
    positions.append(document.positions[index]);
    normals.append(document.normals[index]);
  }
  for (uint32_t faceIndex = 0; faceIndex < document.face_count; ++faceIndex) {
    const GBFaceRange &face = document.faces[faceIndex];
    for (uint32_t vertex = 0; vertex < face.vertex_count; ++vertex) {
      colors.append(face.color[0]);
      colors.append(face.color[1]);
      colors.append(face.color[2]);
      colors.append(face.color[3]);
    }
  }
  for (uint32_t index = 0; index < document.index_count; ++index)
    indices.append(static_cast<qint64>(document.indices[index]));
  for (uint32_t edgeIndex = 0; edgeIndex < document.edge_count; ++edgeIndex) {
    const GBEdgeRange &edge = document.edges[edgeIndex];
    if (edge.point_count < 2) continue;
    for (uint32_t point = 0; point + 1 < edge.point_count; ++point) {
      for (uint32_t endpoint : {point, point + 1}) {
        const uint32_t offset = (edge.point_offset + endpoint) * 3;
        edgePositions.append(document.edge_points[offset]);
        edgePositions.append(document.edge_points[offset + 1]);
        edgePositions.append(document.edge_points[offset + 2]);
      }
    }
  }
  return {
    {"positions", positions}, {"normals", normals}, {"colors", colors},
    {"indices", indices}, {"edgePositions", edgePositions},
    {"triangles", static_cast<qint64>(document.index_count / 3)},
  };
}
}  // namespace

class QtWebGLRenderer final : public QObject {
 public:
  QtWebGLRenderer(QWebEngineView *view, QString surfaceService)
      : view(view), surfaceService(std::move(surfaceService)) {
    cpuTimer.start();
    view->settings()->setAttribute(QWebEngineSettings::WebGLEnabled, true);
    view->settings()->setAttribute(QWebEngineSettings::Accelerated2dCanvasEnabled, true);
    QObject::connect(view, &QWebEngineView::loadFinished, this, [this](bool ok) {
      pageReady = ok;
      if (ok) {
        writeJson(QJsonObject{{"ok", true}, {"event", "ready"}});
        if (pendingTheme.has_value()) {
          const QJsonObject request = *pendingTheme;
          pendingTheme.reset();
          setTheme(request);
        }
        if (pendingLoad.has_value()) {
          const QJsonObject request = *pendingLoad;
          pendingLoad.reset();
          loadSTEP(request);
        }
      }
      else writeJson(QJsonObject{{"ok", false}, {"error", "Qt WebEngine could not load the shared WebGL page."}});
    });
  }

  bool loadPage(const QString &path) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) return false;
    view->setHtml(QString::fromUtf8(file.readAll()), QUrl::fromLocalFile(path));
    return true;
  }

  void loadSTEP(const QJsonObject &request) {
    if (!pageReady) {
      pendingLoad = request;
      return;
    }
    const QString path = request.value("path").toString();
    GBDocument document = gb_load_step_document(
      path.toUtf8().constData(), 0.0002, 0.35);
    if (document.error_message != nullptr || document.vertex_count == 0) {
      const QString message = document.error_message == nullptr
        ? QStringLiteral("Open CASCADE Technology returned no triangles.")
        : QString::fromUtf8(document.error_message);
      gb_free_document(document);
      writeJson(failure(request, message));
      return;
    }
    const double kernelMilliseconds =
      (document.read_seconds + document.transfer_seconds + document.triangulation_seconds) * 1000.0;
    const qint64 triangles = document.index_count / 3;
    const QByteArray payload = QJsonDocument(meshPayload(document)).toJson(QJsonDocument::Compact);
    gb_free_document(document);
    QElapsedTimer uploadTimer;
    uploadTimer.start();
    const QString script = QStringLiteral("window.codexBench.loadMesh(")
      + QString::fromUtf8(payload) + QStringLiteral(");");
    view->page()->runJavaScript(script, [request, kernelMilliseconds, triangles, uploadTimer](const QVariant &) mutable {
      auto result = response(request, "loaded");
      result.insert("load_ms", kernelMilliseconds + uploadTimer.elapsed());
      result.insert("triangles", triangles);
      writeJson(result);
    });
  }

  void setTheme(const QJsonObject &request) {
    if (!pageReady) {
      pendingTheme = request;
      return;
    }
    QJsonObject theme{
      {"background", colorArray(request, "background")},
      {"edge", colorArray(request, "edge")},
      {"selection", colorArray(request, "selection")},
      {"roughness", request.value("roughness")},
      {"metallic", request.value("metallic")},
      {"edgeStrength", request.value("edgeStrength")},
      {"overrideColor", request.value("hasOverride").toBool(false)
        ? QJsonValue(QJsonArray{request.value("overrideRed"), request.value("overrideGreen"), request.value("overrideBlue"), request.value("overrideAlpha")})
        : QJsonValue(QJsonValue::Null)},
      {"key", QJsonObject{{"color", colorArray(request, "key")}, {"direction", QJsonArray{0.5, 0.9, 0.6}}, {"intensity", request.value("keyIntensity")}}},
      {"fill", QJsonObject{{"color", colorArray(request, "fill")}, {"direction", QJsonArray{-0.7, 0.3, 0.4}}, {"intensity", request.value("fillIntensity")}}},
      {"rim", QJsonObject{{"color", colorArray(request, "rim")}, {"direction", QJsonArray{0.1, 0.5, -0.8}}, {"intensity", request.value("rimIntensity")}}},
    };
    runCommand(request, QStringLiteral("window.codexBench.setTheme(")
      + QString::fromUtf8(QJsonDocument(theme).toJson(QJsonDocument::Compact)) + ");");
  }

  void camera(const QJsonObject &request, const QString &method, bool twoArguments) {
    const double x = request.value("x").toDouble();
    const double y = request.value("y").toDouble();
    const QString arguments = twoArguments
      ? QString::number(x) + "," + QString::number(y) : QString::number(x);
    runCommand(request, "window.codexBench." + method + "(" + arguments + ");");
  }

  void fit(const QJsonObject &request) {
    runCommand(request, "window.codexBench.fit();");
  }

  void render(const QJsonObject &request) {
    const int width = std::clamp(request.value("width").toInt(960), 64, 4096);
    const int height = std::clamp(request.value("height").toInt(640), 64, 4096);
    view->resize(width, height);
    view->page()->runJavaScript("true", [this, request, width, height](const QVariant &) {
      QTimer::singleShot(18, this, [this, request, width, height] {
        QImage image = view->grab().toImage().convertToFormat(QImage::Format_ARGB32);
        if (image.size() != QSize(width, height))
          image = image.scaled(width, height, Qt::IgnoreAspectRatio, Qt::SmoothTransformation);
        if (image.isNull()) {
          writeJson(failure(request, "Qt WebEngine returned an empty WebGL frame."));
          return;
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
        if (surface == nullptr) {
          writeJson(failure(request, "Could not allocate the Qt WebGL IOSurface."));
          return;
        }
        IOSurfaceLock(surface, 0, nullptr);
        auto *destination = static_cast<unsigned char *>(IOSurfaceGetBaseAddress(surface));
        for (int row = 0; row < height; ++row)
          std::memcpy(destination + static_cast<size_t>(row) * bytesPerRow,
                      image.constScanLine(row), bytesPerRow);
        IOSurfaceUnlock(surface, 0, nullptr);
        sequence += 1;
        const bool sent = !surfaceService.isEmpty()
          && GBHostedSurfaceSend(surfaceService.toUtf8().constData(), surface,
                                 static_cast<uint32_t>(width), static_cast<uint32_t>(height), sequence);
        CFRelease(surface);
        if (!sent) {
          writeJson(failure(request, "Could not transfer the Qt WebGL IOSurface to Swift."));
          return;
        }
        frameCount += 1;
        if (!fpsTimer.isValid()) fpsTimer.start();
        const double elapsed = std::max(fpsTimer.elapsed() / 1000.0, 0.001);
        auto result = response(request, "frame");
        result.insert("sequence", static_cast<double>(sequence));
        result.insert("width", width);
        result.insert("height", height);
        result.insert("fps", frameCount / elapsed);
        result.insert("memory_mb", currentMemoryMegabytes());
        const double cpu = currentCPUSeconds();
        const double cpuElapsed = std::max(cpuTimer.restart() / 1000.0, 0.001);
        cpuPercent = std::max(0.0, (cpu - previousCPUSeconds) / cpuElapsed * 100.0);
        previousCPUSeconds = cpu;
        result.insert("cpu_percent", cpuPercent);
        writeJson(result);
      });
    });
  }

 private:
  void runCommand(const QJsonObject &request, const QString &script) {
    if (!pageReady) {
      writeJson(failure(request, "Qt WebEngine is not ready."));
      return;
    }
    view->page()->runJavaScript(script, [request](const QVariant &) {
      writeJson(response(request, "camera"));
    });
  }

  QWebEngineView *view;
  QString surfaceService;
  bool pageReady = false;
  uint32_t sequence = 0;
  double frameCount = 0;
  QElapsedTimer fpsTimer;
  QElapsedTimer cpuTimer;
  double previousCPUSeconds = currentCPUSeconds();
  double cpuPercent = 0;
  std::optional<QJsonObject> pendingLoad;
  std::optional<QJsonObject> pendingTheme;
};

int main(int argc, char **argv) {
  QApplication application(argc, argv);
  [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
  QString surfaceService;
  QString pagePath;
  for (int index = 1; index + 1 < argc; ++index) {
    const QString argument = QString::fromUtf8(argv[index]);
    if (argument == "--surface-service") surfaceService = QString::fromUtf8(argv[index + 1]);
    if (argument == "--page") pagePath = QString::fromUtf8(argv[index + 1]);
  }

  QMainWindow window;
  window.setWindowTitle("Codex Bench — Qt WebEngine WebGL 2");
  auto *webView = new QWebEngineView;
  window.setCentralWidget(webView);
  window.resize(960, 640);
  window.setWindowFlag(Qt::Tool, true);
  window.setWindowOpacity(0.0);
  window.show();

  QtWebGLRenderer renderer(webView, surfaceService);
  if (pagePath.isEmpty() || !renderer.loadPage(pagePath)) {
    writeJson(QJsonObject{{"ok", false}, {"error", "The shared WebGL page was not provided."}});
    return EXIT_FAILURE;
  }

  QFile input;
  if (!input.open(STDIN_FILENO, QIODevice::ReadOnly, QFileDevice::DontCloseHandle)) {
    writeJson(QJsonObject{{"ok", false}, {"error", "Could not open the Qt WebGL command pipe."}});
    return EXIT_FAILURE;
  }
  QSocketNotifier notifier(STDIN_FILENO, QSocketNotifier::Read);
  QObject::connect(&notifier, &QSocketNotifier::activated, &application, [&] {
    const QByteArray line = input.readLine();
    if (!line.isEmpty()) {
      const QJsonObject request = QJsonDocument::fromJson(line.trimmed()).object();
      const QString verb = request.value("verb").toString();
      if (verb == "load") renderer.loadSTEP(request);
      else if (verb == "render") renderer.render(request);
      else if (verb == "orbit") renderer.camera(request, "orbit", true);
      else if (verb == "pan") renderer.camera(request, "pan", true);
      else if (verb == "roll") renderer.camera(request, "roll", false);
      else if (verb == "zoom") renderer.camera(request, "zoom", false);
      else if (verb == "fit") renderer.fit(request);
      else if (verb == "theme") renderer.setTheme(request);
      else if (verb == "shutdown") {
        writeJson(response(request, "shutdown"));
        application.quit();
      } else writeJson(failure(request, "Unknown Qt WebGL verb: " + verb));
    }
  });
  return application.exec();
}
