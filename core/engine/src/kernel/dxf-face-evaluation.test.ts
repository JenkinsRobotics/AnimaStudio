import { beforeAll, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import init from "replicad-opencascadejs";
import { setOC } from "replicad";
import { evaluatePartDocument } from "./part-evaluator";
import { importDxfSketch } from "../sketch/import/dxf";
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
  {
    type: "SOLID",
    points: [
      [0, 0],
      [4, 0],
      [0, 3],
      [4, 3],
    ],
    area: 12,
    normal: 1,
  },
  {
    type: "TRACE",
    points: [
      [0, 0],
      [4, 0],
      [0, 3],
      [4, 3],
    ],
    area: 12,
    normal: -1,
  },
  {
    type: "SOLID",
    points: [
      [0, 0],
      [4, 0],
      [0, 3],
      [0, 3],
    ],
    area: 6,
    normal: 1,
  },
  {
    type: "SOLID",
    points: [
      [0, 0],
      [4, 0],
      [0, 4],
      [1, 1],
    ],
    area: 4,
    normal: 1,
  },
])(
  "extrudes reopened $type face with area $area and normal $normal",
  ({ type, points, area, normal }) => {
    const text = `0\nSECTION\n2\nENTITIES\n0\n${type}\n${points.map((p, i) => `${10 + i}\n${p[0]}\n${20 + i}\n${p[1]}\n`).join("")}230\n${normal}\n0\nENDSEC\n0\nEOF`;
    const doc = createEmptyPartDocument("Imported plate");
    doc.features.push({
      id: "profile",
      type: "profile",
      name: "Imported face",
      plane: "XY",
      offsetMillimeters: 0,
      suppressed: false,
      profile: importDxfSketch(text, 2).drawing,
    });
    doc.features.push({
      id: "extrude",
      type: "extrude",
      name: "Plate",
      profileFeatureId: "profile",
      distanceMillimeters: 5,
      operation: "new",
      suppressed: false,
    });
    const reopened = parsePartDocument(serializePartDocument(doc));
    const result = evaluatePartDocument(reopened);
    expect(result.parts).toHaveLength(1);
    const { vertices, triangles } = result.parts[0];
    let volume = 0;
    const edges = new Map<string, number>();
    const point = (index: number) =>
      Array.from(vertices.slice(index * 3, index * 3 + 3));
    // Mesh vertex indices may split along face normals; compare edge positions.
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
      for (const [u, v] of [
        [a, b],
        [b, c],
        [c, a],
      ]) {
        const key = [u.join(","), v.join(",")].sort().join("/");
        edges.set(key, (edges.get(key) ?? 0) + 1);
      }
    }
    expect(Math.abs(volume)).toBeCloseTo(area * 4 * 5, 5);
    expect([...edges.values()].every((count) => count === 2)).toBe(true);
    const zs = Array.from(vertices).filter((_, i) => i % 3 === 2);
    expect(Math.min(...zs)).toBeCloseTo(0);
    expect(Math.max(...zs)).toBeCloseTo(5);
  },
  30000,
);
