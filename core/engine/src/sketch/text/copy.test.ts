import { resizeSketchTextFrame } from "./resize";
import { solveDrawingConstraints } from "../solver/solve";
import { readFileSync } from "node:fs";
import { expect, it } from "vitest";
import { putSketchText, sketchTextEditState } from "./edit";
import {
  copySketchContours,
  similarityTransform,
} from "../operations/transform";
import { regenerateSketchTextExpressions } from "./regenerate-expressions";
import { createEmptyPartDocument } from "../../document/part-document";
import {
  parsePartDocument,
  serializePartDocument,
} from "../../document/part-serialization";
const variables = new Map([["word", "O"]]);
async function create(frame = true) {
  const bytes = readFileSync(
    new URL(
      "../../../../assets/fonts/noto-sans/NotoSans-Regular.ttf",
      import.meta.url,
    ),
  );
  return putSketchText(
    { type: "drawing", contours: [] },
    {
      text: "O",
      expression: "#word",
      expressionVariables: variables,
      fontBytes: Uint8Array.from(bytes).buffer,
      emSizeMillimeters: 10,
      textHeightMillimeters: 8,
      originMillimeters: [2, 3],
      flipHorizontal: true,
      ...(frame ? { frameWidthMillimeters: 20 } : {}),
    },
  );
}
it("keeps rotated/scaled copies editable with independent frame constraints and native metadata", async () => {
  const source = await create(),
    before = structuredClone(source);
  const copied = copySketchContours(
    source,
    source.contours.map((_, i) => i),
    [similarityTransform([0, 0], [30, 40], 90, 2)],
  );
  expect(copied.textItems).toHaveLength(2);
  const [original, copy] = copied.textItems!;
  expect(copy.id).not.toBe(original.id);
  expect(copy.frameContourId).not.toBe(original.frameContourId);
  expect(copy.rotationDegrees).toBeCloseTo(90);
  expect(copy.emSizeMillimeters).toBeCloseTo(original.emSizeMillimeters * 2);
  expect(copy.fontAscenderRatio).toBe(original.fontAscenderRatio);
  expect(copy.frameWidthMillimeters).toBe(40);
  expect(copy.expression).toBe("#word");
  expect(await sketchTextEditState(copied, copy.id)).toBe("constrained");
  const edited = await putSketchText(copied, {
    ...copy,
    expression: null,
    text: "OO",
  });
  expect(edited.textItems!.find((i) => i.id === original.id)!.text).toBe("O");
  const doc = createEmptyPartDocument("Copied text");
  doc.variables = [{ name: "word", kind: "string", expression: '"O"' }];
  doc.features.push({
    id: "s",
    type: "profile",
    name: "Text",
    plane: "XY",
    offsetMillimeters: 0,
    suppressed: false,
    profile: edited,
  });
  expect(parsePartDocument(serializePartDocument(doc)).features).toEqual(
    doc.features,
  );
  expect(source).toEqual(before);
});
it("regenerates all copied expression groups and preserves disjoint ownership", async () => {
  const source = await create();
  const copied = copySketchContours(
    source,
    source.contours.map((_, i) => i),
    [
      similarityTransform([0, 0], [30, 0], 0),
      similarityTransform([0, 0], [60, 0], 0),
    ],
  );
  const regenerated = await regenerateSketchTextExpressions(
    copied,
    new Map([["word", "OO"]]),
  );
  expect(regenerated.textItems!.map((i) => i.text)).toEqual(["OO", "OO", "OO"]);
  const ids = regenerated.textItems!.flatMap((i) => i.contourIds);
  expect(new Set(ids).size).toBe(ids.length);
});
it("copies partial or manually edited letters as curves without claiming intact text", async () => {
  const source = await create();
  expect(
    copySketchContours(source, [0], [similarityTransform([0, 0], [30, 0], 0)])
      .textItems,
  ).toHaveLength(1);
  const contour = source.contours[0];
  if (contour.type !== "path") throw Error();
  contour.start[0] += 0.1;
  expect(
    copySketchContours(
      source,
      source.contours.map((_, i) => i),
      [similarityTransform([0, 0], [30, 0], 0)],
    ).textItems,
  ).toHaveLength(1);
});
it.each([false, true])(
  "preserves reflected text and frame geometry through regeneration (framed=%s)",
  async (frame) => {
    const reflection = { a: -1, b: 0, c: 0, d: 1, tx: 30, ty: 0 };
    const free = await create(frame),
      copied = copySketchContours(
        free,
        free.contours.map((_, i) => i),
        [reflection],
      );
    const copy = copied.textItems![1];
    expect(copy.placementReflected).toBe(true);
    expect(await sketchTextEditState(copied, copy.id)).toBe(
      frame ? "constrained" : "editable",
    );
    const regenerated = await putSketchText(copied, {
      ...copy,
      expressionVariables: variables,
    });
    const numeric = (value: unknown): number[] =>
      typeof value === "number"
        ? [value]
        : value && typeof value === "object"
          ? Object.values(value).flatMap(numeric)
          : [];
    const beforeCoordinates = copy.contourIds.flatMap((id) =>
      numeric(copied.contours.find((c) => c.id === id)),
    );
    const afterCoordinates = regenerated
      .textItems!.at(-1)!
      .contourIds.flatMap((id) =>
        numeric(regenerated.contours.find((c) => c.id === id)),
      );
    expect(afterCoordinates).toHaveLength(beforeCoordinates.length);
    afterCoordinates.forEach((value, index) =>
      expect(value).toBeCloseTo(beforeCoordinates[index], 9),
    );
    const twice = copySketchContours(
      copied,
      copy.contourIds.map((id) =>
        copied.contours.findIndex((c) => c.id === id),
      ),
      [reflection],
    );
    expect(twice.textItems!.at(-1)!.placementReflected).toBe(false);
    const before = structuredClone(copied);
    const reworded = await putSketchText(copied, {
      ...copy,
      text: "OO",
      expression: null,
    });
    expect(reworded.textItems!.at(-1)!.placementReflected).toBe(true);
    expect(copied).toEqual(before);
  },
);

it("keeps reflected frame dimensions and stable references through solving, resizing and native persistence", async () => {
  const source = await create();
  const frameIndex = source.contours.findIndex(
    (c) => c.id === source.textItems![0].frameContourId,
  );
  const frame = source.contours[frameIndex];
  if (frame.type !== "path") throw Error();
  frame.startVertexId = "base";
  frame.segments.forEach((edge, i) => {
    edge.id = `edge-${i}`;
    edge.endVertexId = `corner-${i}`;
  });
  // IDs are metadata; refresh the retained digest after assigning stable references.
  const { textOutlineDigest } = await import("./digest");
  source.textItems![0].outlineDigest = textOutlineDigest(source.contours);
  source.constraints!.push({
    id: "width",
    kind: "length",
    a: { kind: "line", contour: frameIndex, index: 0 },
    value: 20,
  });
  const copy = copySketchContours(
    source,
    source.contours.map((_, i) => i),
    [{ a: -2, b: 0, c: 0, d: 2, tx: 40, ty: 10 }],
  );
  const item = copy.textItems![1];
  const solved = solveDrawingConstraints(copy);
  const savedFrame = solved.contours.find((c) => c.id === item.frameContourId)!;
  const resized = resizeSketchTextFrame(
    solved,
    item.id,
    40,
    item.emSizeMillimeters * 1.5,
  );
  const reworded = await putSketchText(resized, {
    ...resized.textItems![1],
    text: "OO",
    expression: null,
  });
  const rebuiltFrame = reworded.contours.find(
    (c) => c.id === item.frameContourId,
  )!;
  if (savedFrame.type !== "path" || rebuiltFrame.type !== "path") throw Error();
  expect(rebuiltFrame.startVertexId).toBe("base");
  expect(rebuiltFrame.segments.map((e) => [e.id, e.endVertexId])).toEqual(
    savedFrame.segments.map((e) => [e.id, e.endVertexId]),
  );
  expect(
    Math.hypot(
      rebuiltFrame.segments[0].end[0] - rebuiltFrame.start[0],
      rebuiltFrame.segments[0].end[1] - rebuiltFrame.start[1],
    ),
  ).toBeCloseTo(40);
  const doc = createEmptyPartDocument("Mirrored frame");
  doc.variables = [{ name: "word", kind: "string", expression: '"O"' }];
  doc.features.push({
    id: "s",
    type: "profile",
    name: "Text",
    plane: "XY",
    offsetMillimeters: 0,
    suppressed: false,
    profile: reworded,
  });
  expect(parsePartDocument(serializePartDocument(doc)).features).toEqual(
    doc.features,
  );
});
