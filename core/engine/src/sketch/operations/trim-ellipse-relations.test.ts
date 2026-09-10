import { expect, it } from "vitest";
import { constrainSketchEllipse } from "./ellipse-relations";
import { sketchVariantContour } from "../primitives";
import { trimSketchCurve } from "./trim";
import { constraintResiduals } from "../solver/residuals";
import { ellipseLocusResiduals } from "../solver/ellipse-locus";
import { createEmptyPartDocument } from "../../document/part-document";
import {
  serializePartDocument,
  parsePartDocument,
} from "../../document/part-serialization";
it("trims a full ellipse into arcs sharing one native conic relation", () => {
  const d = constrainSketchEllipse(
    {
      type: "drawing",
      contours: [
        sketchVariantContour("ellipse", [
          [0, 0],
          [5, 0],
          [0, 3],
        ]),
      ],
    },
    0,
  );
  for (const x of [-2, 2])
    d.contours.push({
      type: "path",
      start: [x, -5],
      segments: [{ type: "line", end: [x, 5] }],
    });
  const before = structuredClone(d),
    next = trimSketchCurve(d, [0, 3], 0.1),
    path = next.contours[0];
  if (path.type !== "path") throw Error();
  expect(path.segments).toHaveLength(3);
  expect(next.constraints!.some((c) => c.kind === "ellipse-shape")).toBe(false);
  const links = next.constraints!.filter((c) => c.kind === "ellipse-locus");
  expect(links).toHaveLength(2);
  for (const c of links)
    expect(
      Math.max(...constraintResiduals(next, c).map(Math.abs)),
    ).toBeLessThan(1e-6);
  expect(d).toEqual(before);
  const doc = createEmptyPartDocument("Trimmed ellipse");
  doc.features.push({
    id: "ellipse",
    name: "Ellipse",
    type: "profile",
    plane: "XY",
    offsetMillimeters: 0,
    suppressed: false,
    profile: next,
  });
  expect(parsePartDocument(serializePartDocument(doc)).features[0]).toEqual(
    doc.features[0],
  );
});
it("recognizes the same supporting ellipse with swapped axes and rejects a changed conic", () => {
  const a = {
      center: [0, 0] as [number, number],
      radiusX: 5,
      radiusY: 3,
      rotation: 0,
    },
    b = { ...a, radiusX: 3, radiusY: 5, rotation: Math.PI / 2 };
  expect(Math.max(...ellipseLocusResiduals(a, b).map(Math.abs))).toBeLessThan(
    1e-8,
  );
  expect(
    Math.max(...ellipseLocusResiduals(a, { ...b, radiusX: 4 }).map(Math.abs)),
  ).toBeGreaterThan(0.1);
});
