import { expect, it } from "vitest";
import type { SketchDrawing } from "../drawing";
import { patternSourceContour, patternSourceEntities } from "./pattern-source";
import { uniquePatternSources } from "./pattern-source-key";
import {
  createPatternGroup,
  editPatternGroup,
} from "../operations/pattern-group";
import { createEmptyPartDocument } from "../../document/part-document";
import {
  parsePartDocument,
  serializePartDocument,
} from "../../document/part-serialization";
const fixture = (): SketchDrawing => ({
  type: "drawing",
  contours: [
    {
      type: "path",
      sourceLayer: "Wheel",
      start: [0, 0],
      segments: [{ type: "line", id: "edge", end: [4, 0] }],
    },
  ],
});
it.each([true, false])(
  "keeps a patterned source edge through earlier insertion, resize and native reopen (preidentified: %s)",
  (identified) => {
    const d = fixture();
    if (!identified && d.contours[0].type === "path")
      delete d.contours[0].segments[0].id;
    const ref = patternSourceEntities(d)[0].ref;
    expect(ref.segmentId).toBe(identified ? "edge" : undefined);
    const definition = {
      kind: "linear" as const,
      first: [0, 10] as [number, number],
      second: [0, 0] as [number, number],
      countFirst: 2,
      countSecond: 1,
    };
    const original = structuredClone(d);
    expect(() =>
      createPatternGroup(
        d,
        [ref, { ...ref, index: 99, segmentId: undefined }],
        definition,
      ),
    ).toThrow();
    expect(d).toEqual(original);
    const patterned = createPatternGroup(d, [ref], definition);
    expect(d).toEqual(original);
    const path = patterned.contours[0];
    if (path.type !== "path") throw Error();
    path.start = [-5, 0];
    path.segments.unshift({ type: "line", id: "prefix", end: [0, 0] });
    const id = Object.keys(patterned.patternGroups!)[0];
    const before = structuredClone(patterned);
    const resized = editPatternGroup(patterned, id, {
      ...definition,
      countFirst: 3,
    });
    expect(patterned).toEqual(before);
    expect(resized.contours[1]).toMatchObject({
      sourceLayer: "Wheel",
      start: [0, 10],
      segments: [{ end: [4, 10] }],
    });
    expect(resized.contours[2]).toMatchObject({
      sourceLayer: "Wheel",
      start: [0, 20],
      segments: [{ end: [4, 20] }],
    });
    const doc = createEmptyPartDocument("Pattern identity");
    doc.features.push({
      type: "profile",
      id: "sketch",
      name: "Sketch",
      plane: "XY",
      offsetMillimeters: 0,
      suppressed: false,
      profile: resized,
    });
    expect(parsePartDocument(serializePartDocument(doc)).features[0]).toEqual(
      doc.features[0],
    );
    expect(() =>
      patternSourceContour(resized, { ...ref, segmentId: "deleted" }),
    ).toThrow(/Broken segment reference/);
  },
);
it("keys stable sources independently of stale indexes and distinguishes projected sources", () => {
  const ref = {
    kind: "line" as const,
    contour: 0,
    index: 0,
    segmentId: "edge",
  };
  expect(uniquePatternSources([ref, { ...ref, index: 3 }])).toHaveLength(1);
  expect(
    uniquePatternSources([
      { ...ref, contour: -1, projectedContourId: "one" },
      { ...ref, contour: -1, projectedContourId: "two" },
    ]),
  ).toHaveLength(2);
});
