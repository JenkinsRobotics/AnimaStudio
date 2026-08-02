#include <metal_stdlib>
#include <RealityKit/RealityKit.h>

using namespace metal;

[[visible]] void anima_section_surface(realitykit::surface_parameters params) {
  float4 plane = params.uniforms().custom_parameter();
  float distance = dot(params.geometry().world_position(), plane.xyz) - plane.w;
  if (distance > 0.0) {
    params.surface().set_opacity(half(0.0));
  }
}
