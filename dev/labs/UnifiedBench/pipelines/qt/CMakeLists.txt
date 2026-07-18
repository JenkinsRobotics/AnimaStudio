cmake_minimum_required(VERSION 3.22)
project(qtbench LANGUAGES CXX OBJCXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_AUTOMOC ON)

# Homebrew locations — this is a dev bench, not a shipping build.
execute_process(COMMAND brew --prefix qt OUTPUT_VARIABLE QT_PREFIX
                OUTPUT_STRIP_TRAILING_WHITESPACE)
execute_process(COMMAND brew --prefix opencascade OUTPUT_VARIABLE OCCT_PREFIX
                OUTPUT_STRIP_TRAILING_WHITESPACE)
list(APPEND CMAKE_PREFIX_PATH "${QT_PREFIX}")

find_package(Qt6 REQUIRED COMPONENTS Widgets)

add_executable(qtbench MACOSX_BUNDLE main.mm)
target_include_directories(qtbench PRIVATE "${OCCT_PREFIX}/include/opencascade")
target_link_directories(qtbench PRIVATE "${OCCT_PREFIX}/lib")
target_link_libraries(qtbench PRIVATE
  Qt6::Widgets
  TKernel TKMath TKG2d TKG3d TKGeomBase TKBRep TKGeomAlgo TKTopAlgo TKPrim
  TKMesh TKDESTEP TKXSBase TKService TKV3d TKOpenGl
  "-framework Cocoa" "-framework OpenGL")
set_target_properties(qtbench PROPERTIES
  BUILD_RPATH "${OCCT_PREFIX}/lib;${QT_PREFIX}/lib")
