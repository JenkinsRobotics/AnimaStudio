import { beforeAll, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import init from "replicad-opencascadejs";
import { setOC } from "replicad";
import { evaluatePartDocument } from "./part-evaluator";
import { sketchVariantContour } from "../sketch/primitives";
import { setSketchEllipseDiameter } from "../sketch/operations/set-ellipse-diameter";
import type { SketchDrawing } from "../sketch/drawing";
import { createEmptyPartDocument } from "../document/part-document";
import {
  parsePartDocument,
  serializePartDocument,
} from "../document/part-serialization";
beforeAll(async () => {
  setOC(
    await (init as any)({
      wasmBinary: readFileSync(
        new URL(
          "../../node_modules/replicad-opencascadejs/src/replicad_single.wasm",
          import.meta.url,
        ),
      ),
    }),
  );
}, 30000);

it.each([false, true])(
  "extrudes reopened elliptical arc/chord after resized=%s",
  (resized) => {
    const arc = sketchVariantContour(
      "elliptical-arc",
      [
        [0, 0],
        [5, 0],
        [0, 3],
        [5, 0],
      ],
      6,
      { clockwise: true },
    );
    if (arc.type !== "path") throw Error();
    arc.segments.push({ type: "line", end: [...arc.start] });
    let drawing: SketchDrawing = {
      type: "drawing",
      contours: [arc],
      constraints: [
        {
          id: "start",
          kind: "quadrant",
          a: { contour: 0, kind: "point", index: 0 },
          b: { contour: 0, kind: "ellipse", index: 0 },
          quadrant: 1,
        },
        {
          id: "end",
          kind: "quadrant",
          a: { contour: 0, kind: "point", index: 1 },
          b: { contour: 0, kind: "ellipse", index: 0 },
          quadrant: 0,
        },
      ],
    };
    if (resized) {
      const ref = { contour: 0, kind: "ellipse" as const, index: 0 };
      drawing = setSketchEllipseDiameter(
        setSketchEllipseDiameter(drawing, ref, "x", 14),
        ref,
        "y",
        8,
      );
      expect(drawing.contours.length).toBeGreaterThan(1);
      expect(drawing.contours.slice(1).every((c) => c.construction)).toBe(true);
    }
    const doc = createEmptyPartDocument("Elliptical plate");
    doc.features.push({
      id: "sketch",
      type: "profile",
      name: "Arc and chord",
      plane: "XY",
      offsetMillimeters: 0,
      suppressed: false,
      profile: drawing,
    });
    doc.features.push({
      id: "extrude",
      type: "extrude",
      name: "Plate",
      profileFeatureId: "sketch",
      distanceMillimeters: 5,
      operation: "new",
      suppressed: false,
    });
    const result = evaluatePartDocument(
      parsePartDocument(serializePartDocument(doc)),
    );
    expect(result.parts).toHaveLength(1);
    const { vertices, triangles } = result.parts[0];
    let volume = 0;
    const point = (index: number) =>
      Array.from(vertices.slice(index * 3, index * 3 + 3));
    for (let i = 0; i < triangles.length; i += 3) {
      const [a, b, c] = [
        point(triangles[i]),
        point(triangles[i + 1]),
        point(triangles[i + 2]),
      ];
      volume +=
        (a[0] * (b[1] * c[2] - b[2] * c[1]) +
          a[1] * (b[2] * c[0] - b[0] * c[2]) +
          a[2] * (b[0] * c[1] - b[1] * c[0])) /
        6;
    }
    const expected = (Math.PI / 4 - 0.5) * (resized ? 7 * 4 : 5 * 3) * 5;
    // OCCT's display mesh approximates the exact curved boundary at 0.08 mm tolerance.
    expect(Math.abs(Math.abs(volume) - expected) / expected).toBeLessThan(0.03);
    const zs = Array.from(vertices).filter((_, i) => i % 3 === 2);
    expect(Math.min(...zs)).toBeCloseTo(0);
    expect(Math.max(...zs)).toBeCloseTo(5);
  },
  30000,
);
