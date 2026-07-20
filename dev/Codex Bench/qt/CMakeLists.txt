cmake_minimum_required(VERSION 3.25)
project(GeomBenchQt LANGUAGES C CXX OBJCXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_AUTOMOC ON)

set(QT_ROOT "/opt/homebrew/opt/qt" CACHE PATH "Qt6 prefix")
set(OCCT_ROOT "/opt/homebrew/opt/opencascade" CACHE PATH "Desktop OpenGL OCCT prefix")
list(APPEND CMAKE_PREFIX_PATH "${QT_ROOT}")
find_package(Qt6 REQUIRED COMPONENTS Widgets WebEngineWidgets)

set(OCCT_LIBRARIES
  TKernel TKMath TKG2d TKG3d TKGeomBase TKBRep TKGeomAlgo TKTopAlgo TKPrim
  TKMesh TKDE TKXSBase TKDESTEP TKCDF TKLCAF TKVCAF TKXCAF TKService TKV3d TKOpenGl)

set(HOSTED_SURFACE_BRIDGE "${CMAKE_CURRENT_SOURCE_DIR}/../Sources/HostedSurfaceBridge/HostedSurfaceBridge.c")

add_executable(GeomBenchQtGL MACOSX_BUNDLE Pipeline4/main.mm "${HOSTED_SURFACE_BRIDGE}")
target_include_directories(GeomBenchQtGL PRIVATE "${OCCT_ROOT}/include/opencascade"
  "${CMAKE_CURRENT_SOURCE_DIR}/../Sources/HostedSurfaceBridge/include")
target_link_directories(GeomBenchQtGL PRIVATE "${OCCT_ROOT}/lib")
target_link_libraries(GeomBenchQtGL PRIVATE Qt6::Widgets ${OCCT_LIBRARIES}
  "-framework Cocoa" "-framework OpenGL" "-framework IOSurface")
set_target_properties(GeomBenchQtGL PROPERTIES
  MACOSX_BUNDLE_BUNDLE_NAME "GeomBenchQtGL"
  BUILD_RPATH "${OCCT_ROOT}/lib;${QT_ROOT}/lib")

add_executable(GeomBenchQtWebGL MACOSX_BUNDLE Pipeline6/main.mm
  "${CMAKE_CURRENT_SOURCE_DIR}/../Sources/GeomShim/GeomShim.cpp"
  "${HOSTED_SURFACE_BRIDGE}")
target_include_directories(GeomBenchQtWebGL PRIVATE "${OCCT_ROOT}/include/opencascade"
  "${CMAKE_CURRENT_SOURCE_DIR}/../Sources/GeomShim/include"
  "${CMAKE_CURRENT_SOURCE_DIR}/../Sources/HostedSurfaceBridge/include")
target_link_directories(GeomBenchQtWebGL PRIVATE "${OCCT_ROOT}/lib")
target_link_libraries(GeomBenchQtWebGL PRIVATE Qt6::Widgets Qt6::WebEngineWidgets
  ${OCCT_LIBRARIES} "-framework Cocoa" "-framework IOSurface")
set_target_properties(GeomBenchQtWebGL PROPERTIES
  MACOSX_BUNDLE_BUNDLE_NAME "GeomBenchQtWebGL"
  BUILD_RPATH "${OCCT_ROOT}/lib;${QT_ROOT}/lib")
