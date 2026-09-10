import { expect, it } from "vitest";
import {
  createEmptyPartDocument,
  resolveProfileDrawing,
} from "@aether/core/document";
import { projectionGeometryReference } from "./projection-source-selection";
it("identifies an already named selected contour without mutating the editing snapshot", () => {
  const doc = createEmptyPartDocument("Selected source");
  doc.features.push({
    id: "source",
    name: "Source",
    type: "profile",
    plane: "XY",
    offsetMillimeters: 0,
    suppressed: false,
    profile: {
      type: "drawing",
      contours: [
        {
          id: "named",
          type: "path",
          start: [0, 0],
          segments: [{ type: "line", end: [10, 0] }],
        },
      ],
    },
  });
  const before = structuredClone(doc),
    candidate = projectionGeometryReference(doc, "source", "contour:0");
  expect(candidate.reference.sourceContourId).toBe("named");
  const path = resolveProfileDrawing(candidate.document.features, "source")
    .contours[0];
  if (path.type !== "path") throw Error();
  expect(path.startVertexId).toBeTruthy();
  expect(path.segments[0].id).toBeTruthy();
  expect(path.segments[0].endVertexId).toBeTruthy();
  expect(doc).toEqual(before);
});
