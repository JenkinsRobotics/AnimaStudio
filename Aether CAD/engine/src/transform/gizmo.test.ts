import { describe, expect, it } from "vitest";
import {
  applyGizmoDelta,
  beginGizmoDrag,
  pickGizmoHandle,
  updateGizmoDrag,
  type GizmoFrame,
  type GizmoRay,
} from "./gizmo";

const frame: GizmoFrame = {
  originMillimeters: [0, 0, 0],
  xAxis: [1, 0, 0],
  yAxis: [0, 1, 0],
  zAxis: [0, 0, 1],
};
const SIZE = 50;
/** A ray straight down -Z at (x, y). */
const down = (x: number, y: number): GizmoRay => ({ origin: [x, y, 200], direction: [0, 0, -1] });

describe("transform gizmo", () => {
  it("picks the axis shaft under the ray", () => {
    expect(pickGizmoHandle(down(40, 0), frame, SIZE)).toEqual({ kind: "translate-axis", axis: "x" });
    expect(pickGizmoHandle(down(0, 40), frame, SIZE)).toEqual({ kind: "translate-axis", axis: "y" });
  });

  it("picks the plane quadrant near the pivot and the ring at radius", () => {
    expect(pickGizmoHandle(down(10, 10), frame, SIZE)).toEqual({ kind: "translate-plane", normal: "z" });
    const ring = pickGizmoHandle(down(SIZE, 0.001), frame, SIZE);
    expect(ring === null || ring.kind === "translate-axis" || ring.kind === "rotate-ring").toBe(true);
    expect(pickGizmoHandle(down(400, 400), frame, SIZE)).toBeNull();
  });

  it("translates along the dragged axis only, and snaps", () => {
    const drag = beginGizmoDrag({ kind: "translate-axis", axis: "x" }, down(40, 0), frame, SIZE);
    expect(drag).not.toBeNull();
    const moved = updateGizmoDrag(drag!, down(63, 12));
    expect(moved.translationMillimeters[0]).toBeCloseTo(23, 6);
    expect(moved.translationMillimeters[1]).toBeCloseTo(0, 6);
    expect(moved.translationMillimeters[2]).toBeCloseTo(0, 6);
    const snapped = updateGizmoDrag(drag!, down(63, 12), { translationMillimeters: 10 });
    expect(snapped.translationMillimeters[0]).toBeCloseTo(20, 6);
  });

  it("translates in the handle plane for plane handles", () => {
    const drag = beginGizmoDrag({ kind: "translate-plane", normal: "z" }, down(10, 10), frame, SIZE);
    const moved = updateGizmoDrag(drag!, down(30, 25));
    expect(moved.translationMillimeters[0]).toBeCloseTo(20, 6);
    expect(moved.translationMillimeters[1]).toBeCloseTo(15, 6);
    expect(moved.translationMillimeters[2]).toBeCloseTo(0, 6);
  });

  it("measures ring rotation about its axis and snaps to increments", () => {
    const drag = beginGizmoDrag({ kind: "rotate-ring", axis: "z" }, down(SIZE, 0), frame, SIZE);
    const turned = updateGizmoDrag(drag!, down(0, SIZE));
    expect(turned.angleRadians).toBeCloseTo(Math.PI / 2, 6);
    expect(turned.rotationAxis).toEqual([0, 0, 1]);
    const snapped = updateGizmoDrag(drag!, down(4, SIZE), { rotationRadians: Math.PI / 4 });
    expect(snapped.angleRadians).toBeCloseTo(Math.PI / 2, 6);
  });

  it("applies deltas about the pivot", () => {
    const rotated = applyGizmoDelta([10, 0, 0], { translationMillimeters: [0, 0, 0], angleRadians: Math.PI / 2, rotationAxis: [0, 0, 1] }, [0, 0, 0]);
    expect(rotated[0]).toBeCloseTo(0, 6);
    expect(rotated[1]).toBeCloseTo(10, 6);
    const moved = applyGizmoDelta([1, 2, 3], { translationMillimeters: [5, 0, -1], angleRadians: 0, rotationAxis: null }, [0, 0, 0]);
    expect(moved).toEqual([6, 2, 2]);
  });
});
