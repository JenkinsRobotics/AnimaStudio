import { expect, it } from "vitest";
import { importDxfSketch } from "../import/dxf";
import { splitSketchCircle, splitSketchSegment } from "./split";
import { trimSketchCurve } from "./trim";
import { createEmptyPartDocument } from "../../document/part-document";
import {
  parsePartDocument,
  serializePartDocument,
} from "../../document/part-serialization";
const source = () =>
  importDxfSketch(
    `0
SECTION
2
ENTITIES
0
CIRCLE
8
Wheel
10
0
20
0
40
5
0
LINE
8
Reference
10
0
20
-10
11
0
21
10
0
ENDSEC
0
EOF`,
    1,
  ).drawing;

it("retains imported layers through circle Split, subsequent arc Split and native reopen", () => {
  const d = source(),
    before = structuredClone(d);
  const split = splitSketchCircle(d, 0, [5, 0], [-5, 0]);
  const edited = splitSketchSegment(split, [0, 5], 0.01);
  expect(edited.contours.map((c) => c.sourceLayer)).toEqual([
    "Wheel",
    "Reference",
  ]);
  expect(d).toEqual(before);
  const doc = createEmptyPartDocument("Wheel layers");
  doc.features.push({
    id: "sketch",
    name: "Sketch",
    type: "profile",
    plane: "XY",
    offsetMillimeters: 0,
    suppressed: false,
    profile: edited,
  });
  expect(parsePartDocument(serializePartDocument(doc)).features[0]).toEqual(
    doc.features[0],
  );
});
it("retains the circle's layer on a trimmed arc without assigning it to the cutter", () => {
  const d = source(),
    before = structuredClone(d);
  const edited = trimSketchCurve(d, [5, 0], 0.01);
  expect(edited.contours[0]).toMatchObject({
    type: "path",
    sourceLayer: "Wheel",
  });
  expect(edited.contours[1]).toEqual(d.contours[1]);
  expect(d).toEqual(before);
});
