import type { Vec3 } from "../contracts/index";

/** Renderer-neutral transform-gizmo semantics: which handle a ray picks, and
 *  what a drag means. No renderer types — Three.js/WebGPU adapters supply
 *  rays and draw handles; this module owns the meaning of the manipulation. */

export type GizmoAxis = "x" | "y" | "z";

export type GizmoHandle =
  /** Slide along one axis. */
  | { kind: "translate-axis"; axis: GizmoAxis }
  /** Slide in the plane with this normal. */
  | { kind: "translate-plane"; normal: GizmoAxis }
  /** Spin about one axis. */
  | { kind: "rotate-ring"; axis: GizmoAxis };

export interface GizmoRay {
  origin: Vec3;
  /** Need not be normalized. */
  direction: Vec3;
}

/** The gizmo's placement: pivot plus an orthonormal basis (world or part
 *  frame — the caller decides which space the gizmo manipulates in). */
export interface GizmoFrame {
  originMillimeters: Vec3;
  xAxis: Vec3;
  yAxis: Vec3;
  zAxis: Vec3;
}

export interface GizmoSnapOptions {
  /** Round translation to this increment (mm). 0 or undefined disables. */
  translationMillimeters?: number;
  /** Round rotation to this increment (radians). 0 or undefined disables. */
  rotationRadians?: number;
}

export interface GizmoDrag {
  handle: GizmoHandle;
  frame: GizmoFrame;
  /** Handle length in millimeters; sets the pick tolerance and ring radius. */
  sizeMillimeters: number;
  /** Drag anchor captured at pointer-down. */
  anchor: { parameter: number; point: Vec3 };
}

/** Live result of a drag: a delta to apply to the manipulated object. */
export interface GizmoDelta {
  translationMillimeters: Vec3;
  /** Rotation about the handle axis, right-handed. */
  angleRadians: number;
  rotationAxis: Vec3 | null;
}

export const zeroGizmoDelta: GizmoDelta = Object.freeze({
  translationMillimeters: Object.freeze([0, 0, 0]) as Vec3,
  angleRadians: 0,
  rotationAxis: null,
});

const add = (a: Vec3, b: Vec3): Vec3 => [a[0] + b[0], a[1] + b[1], a[2] + b[2]];
const sub = (a: Vec3, b: Vec3): Vec3 => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
const scale = (a: Vec3, k: number): Vec3 => [a[0] * k, a[1] * k, a[2] * k];
const dot = (a: Vec3, b: Vec3): number => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
const cross = (a: Vec3, b: Vec3): Vec3 => [
  a[1] * b[2] - a[2] * b[1],
  a[2] * b[0] - a[0] * b[2],
  a[0] * b[1] - a[1] * b[0],
];
const length = (a: Vec3): number => Math.hypot(a[0], a[1], a[2]);
const normalize = (a: Vec3): Vec3 => {
  const l = length(a);
  return l > 1e-12 ? scale(a, 1 / l) : [0, 0, 0];
};

export function gizmoAxisVector(frame: GizmoFrame, axis: GizmoAxis): Vec3 {
  return normalize(axis === "x" ? frame.xAxis : axis === "y" ? frame.yAxis : frame.zAxis);
}

/** Ray ∩ plane(point, normal). Null when parallel or behind the origin. */
export function intersectPlane(ray: GizmoRay, point: Vec3, normal: Vec3): Vec3 | null {
  const direction = normalize(ray.direction);
  const denominator = dot(direction, normal);
  if (Math.abs(denominator) < 1e-9) return null;
  const t = dot(sub(point, ray.origin), normal) / denominator;
  if (!Number.isFinite(t) || t <= 0) return null;
  return add(ray.origin, scale(direction, t));
}

/** Parameter along `axis` (from the frame origin) of the point on that axis
 *  closest to the ray — the standard axis-drag projection. */
export function closestAxisParameter(ray: GizmoRay, origin: Vec3, axis: Vec3): number | null {
  const direction = normalize(ray.direction);
  const w = sub(origin, ray.origin);
  const a = dot(axis, axis);
  const b = dot(axis, direction);
  const denominator = a - b * b;
  if (Math.abs(denominator) < 1e-9) return null;
  const d = dot(axis, w);
  const e = dot(direction, w);
  return (b * e - d) / denominator;
}

/** The handle under a ray, or null. Axis handles win over plane handles, and
 *  both win over rings, matching how the handles overlap visually. */
export function pickGizmoHandle(
  ray: GizmoRay,
  frame: GizmoFrame,
  sizeMillimeters: number,
  toleranceMillimeters = sizeMillimeters * 0.16,
): GizmoHandle | null {
  const axes: GizmoAxis[] = ["x", "y", "z"];
  let best: { handle: GizmoHandle; distance: number } | null = null;
  const consider = (handle: GizmoHandle, distance: number) => {
    if (distance > toleranceMillimeters) return;
    if (!best || distance < best.distance) best = { handle, distance };
  };
  for (const axis of axes) {
    const direction = gizmoAxisVector(frame, axis);
    const parameter = closestAxisParameter(ray, frame.originMillimeters, direction);
    if (parameter === null) continue;
    const clamped = Math.min(Math.max(parameter, 0), sizeMillimeters);
    const onAxis = add(frame.originMillimeters, scale(direction, clamped));
    const rayDirection = normalize(ray.direction);
    const toPoint = sub(onAxis, ray.origin);
    const along = dot(toPoint, rayDirection);
    const perpendicular = sub(toPoint, scale(rayDirection, along));
    // Only the outer part of the shaft picks; the inner quarter is plane space.
    if (clamped > sizeMillimeters * 0.25) consider({ kind: "translate-axis", axis }, length(perpendicular));
  }
  for (const axis of axes) {
    const normal = gizmoAxisVector(frame, axis);
    const hit = intersectPlane(ray, frame.originMillimeters, normal);
    if (!hit) continue;
    const offset = sub(hit, frame.originMillimeters);
    const [u, v] = axes.filter((candidate) => candidate !== axis).map((candidate) =>
      dot(offset, gizmoAxisVector(frame, candidate)),
    );
    const quad = sizeMillimeters * 0.34;
    const inside = u > 0 && v > 0 && u < quad && v < quad;
    if (inside) consider({ kind: "translate-plane", normal: axis }, 0);
    // Ring: near the circle of radius size in that plane.
    const radius = Math.hypot(u, v);
    consider({ kind: "rotate-ring", axis }, Math.abs(radius - sizeMillimeters));
  }
  return best ? (best as { handle: GizmoHandle }).handle : null;
}

/** The plane a drag is measured in: for axis drags, the plane containing the
 *  axis most face-on to the ray; for plane/ring drags, the handle's plane. */
function dragPlaneNormal(handle: GizmoHandle, frame: GizmoFrame, ray: GizmoRay): Vec3 {
  if (handle.kind === "translate-plane") return gizmoAxisVector(frame, handle.normal);
  if (handle.kind === "rotate-ring") return gizmoAxisVector(frame, handle.axis);
  const axis = gizmoAxisVector(frame, handle.axis);
  const view = normalize(ray.direction);
  const perpendicular = cross(axis, view);
  const normal = cross(perpendicular, axis);
  return length(normal) > 1e-9 ? normalize(normal) : axis;
}

export function beginGizmoDrag(
  handle: GizmoHandle,
  ray: GizmoRay,
  frame: GizmoFrame,
  sizeMillimeters: number,
): GizmoDrag | null {
  if (handle.kind === "translate-axis") {
    const parameter = closestAxisParameter(
      ray,
      frame.originMillimeters,
      gizmoAxisVector(frame, handle.axis),
    );
    if (parameter === null) return null;
    return { handle, frame, sizeMillimeters, anchor: { parameter, point: frame.originMillimeters } };
  }
  const normal = dragPlaneNormal(handle, frame, ray);
  const hit = intersectPlane(ray, frame.originMillimeters, normal);
  if (!hit) return null;
  return { handle, frame, sizeMillimeters, anchor: { parameter: 0, point: hit } };
}

const snap = (value: number, increment: number | undefined): number =>
  increment && increment > 0 ? Math.round(value / increment) * increment : value;

/** The delta for the pointer's current ray. Returns the total delta from the
 *  drag anchor (not incremental), so callers can apply it to the pose they
 *  captured at drag start and cancel cleanly. */
export function updateGizmoDrag(
  drag: GizmoDrag,
  ray: GizmoRay,
  snapping: GizmoSnapOptions = {},
): GizmoDelta {
  const { handle, frame } = drag;
  if (handle.kind === "translate-axis") {
    const axis = gizmoAxisVector(frame, handle.axis);
    const parameter = closestAxisParameter(ray, frame.originMillimeters, axis);
    if (parameter === null) return zeroGizmoDelta;
    const distance = snap(parameter - drag.anchor.parameter, snapping.translationMillimeters);
    return { translationMillimeters: scale(axis, distance), angleRadians: 0, rotationAxis: null };
  }
  if (handle.kind === "translate-plane") {
    const normal = gizmoAxisVector(frame, handle.normal);
    const hit = intersectPlane(ray, frame.originMillimeters, normal);
    if (!hit) return zeroGizmoDelta;
    const offset = sub(hit, drag.anchor.point);
    const axes = (["x", "y", "z"] as GizmoAxis[]).filter((axis) => axis !== handle.normal);
    let translation: Vec3 = [0, 0, 0];
    for (const axis of axes) {
      const direction = gizmoAxisVector(frame, axis);
      translation = add(translation, scale(direction, snap(dot(offset, direction), snapping.translationMillimeters)));
    }
    return { translationMillimeters: translation, angleRadians: 0, rotationAxis: null };
  }
  const axis = gizmoAxisVector(frame, handle.axis);
  const hit = intersectPlane(ray, frame.originMillimeters, axis);
  if (!hit) return zeroGizmoDelta;
  const start = sub(drag.anchor.point, frame.originMillimeters);
  const current = sub(hit, frame.originMillimeters);
  if (length(start) < 1e-9 || length(current) < 1e-9) return zeroGizmoDelta;
  const angle = Math.atan2(dot(cross(start, current), axis), dot(start, current));
  return {
    translationMillimeters: [0, 0, 0],
    angleRadians: snap(angle, snapping.rotationRadians),
    rotationAxis: axis,
  };
}

/** Apply a delta to a point orbiting the gizmo pivot (Rodrigues rotation). */
export function applyGizmoDelta(point: Vec3, delta: GizmoDelta, pivot: Vec3): Vec3 {
  let moved: Vec3 = point;
  if (delta.rotationAxis && delta.angleRadians !== 0) {
    const axis = normalize(delta.rotationAxis);
    const relative = sub(point, pivot);
    const cos = Math.cos(delta.angleRadians);
    const sin = Math.sin(delta.angleRadians);
    const rotated = add(
      add(scale(relative, cos), scale(cross(axis, relative), sin)),
      scale(axis, dot(axis, relative) * (1 - cos)),
    );
    moved = add(pivot, rotated);
  }
  return add(moved, delta.translationMillimeters);
}
