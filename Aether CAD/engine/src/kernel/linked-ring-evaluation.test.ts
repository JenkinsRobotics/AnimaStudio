import { beforeAll, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import init from "replicad-opencascadejs";
import { setOC } from "replicad";
import { evaluatePartDocument } from "./part-evaluator";
import {
  linkSketchDimension,
  unlinkSketchDimension,
} from "../sketch/operations/link-dimension";
import { editDrawingDimension } from "../sketch/operations/edit-dimension";
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

it.each([
  ["initial", 3, 7],
  ["driver", 4, 9],
  ["follower", 5, 11],
  ["unlinked", 4, 7],
] as const)(
  "rebuilds a native linked ring after %s editing",
  (mode, inner, outer) => {
    let drawing: SketchDrawing = {
      type: "drawing",
      contours: [
        { type: "circle", center: [0, 0], radius: 7 },
        { type: "circle", center: [0, 0], radius: 3, hole: true },
      ],
      constraints: [
        {
          id: "inner",
          kind: "radius",
          a: { contour: 1, kind: "circle" },
          value: 3,
        },
        {
          id: "outer",
          kind: "radius",
          a: { contour: 0, kind: "circle" },
          value: 7,
        },
        {
          id: "center",
          kind: "concentric",
          a: { contour: 0, kind: "circle" },
          b: { contour: 1, kind: "circle" },
        },
        {
          id: "origin",
          kind: "fix",
          a: { contour: 0, kind: "point", index: 0 },
          point: [0, 0],
        },
      ],
    };
    drawing = linkSketchDimension(drawing, "outer", "inner", 2, 1);
    const doc = createEmptyPartDocument("Driven ring");
    doc.features.push(
      {
        id: "sketch",
        type: "profile",
        name: "Ring",
        plane: "XY",
        offsetMillimeters: 0,
        suppressed: false,
        profile: drawing,
      },
      {
        id: "extrude",
        type: "extrude",
        name: "Ring extrusion",
        profileFeatureId: "sketch",
        distanceMillimeters: 5,
        operation: "new",
        suppressed: false,
      },
    );
    const reopened = parsePartDocument(serializePartDocument(doc));
    const sketch = reopened.features[0];
    if (sketch.type !== "profile") throw Error();
    if (mode === "driver")
      sketch.profile = editDrawingDimension(
        sketch.profile as SketchDrawing,
        "inner",
        4,
      );
    if (mode === "follower")
      sketch.profile = editDrawingDimension(
        sketch.profile as SketchDrawing,
        "outer",
        11,
      );
    if (mode === "unlinked")
      sketch.profile = editDrawingDimension(
        unlinkSketchDimension(sketch.profile as SketchDrawing, "outer"),
        "inner",
        4,
      );
    const saved = parsePartDocument(serializePartDocument(reopened));
    const result = evaluatePartDocument(saved);
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
    const expectedVolume = Math.PI * (outer ** 2 - inner ** 2) * 5;
    // Display tessellation approximates circular boundaries at 0.08 mm tolerance.
    expect(
      Math.abs(Math.abs(volume) - expectedVolume) / expectedVolume,
    ).toBeLessThan(0.03);
    const radii: number[] = [],
      zs: number[] = [];
    for (let i = 0; i < vertices.length; i += 3) {
      radii.push(Math.hypot(vertices[i], vertices[i + 1]));
      zs.push(vertices[i + 2]);
    }
    expect(Math.min(...radii)).toBeCloseTo(inner, 4);
    expect(Math.max(...radii)).toBeCloseTo(outer, 4);
    expect(Math.min(...zs)).toBeCloseTo(0);
    expect(Math.max(...zs)).toBeCloseTo(5);
  },
  30000,
);
