import { validateSketchDrawing, type SketchDrawing } from "../sketch/drawing";
import {
  appendCopiedSketchContours,
  selectedContours,
  similarityTransform,
  type SketchTransform,
} from "../sketch/operations/transform";
import {
  clipboardVariables,
  mergeClipboardVariables,
} from "./clipboard-variables";
import { evaluateDocumentVariables, type DocumentVariable } from "./variables";
import { validateDocumentTextExpressions } from "./text-expressions";

export interface SketchClipboard {
  format: "aether-sketch-clipboard";
  version: 1;
  drawing: SketchDrawing;
  variables: DocumentVariable[];
}
const identity = similarityTransform([0, 0], [0, 0], 0);
const maxCharacters = 128 * 1024 * 1024;
function validateFragment(
  drawing: SketchDrawing,
  variables: readonly DocumentVariable[],
) {
  if (drawing.projectionContext !== undefined)
    throw Error(
      "Clipboard geometry cannot contain resolved projection context.",
    );
  if (
    drawing.constraints?.some((c) =>
      [c.a, c.b, c.axis].some((r) => r?.projectedContourId !== undefined),
    )
  )
    throw Error("Clipboard relations must be internal to the copied geometry.");
  validateSketchDrawing(drawing);
  validateDocumentTextExpressions(
    [
      {
        id: "clipboard",
        type: "profile",
        name: "Clipboard",
        plane: "XY",
        offsetMillimeters: 0,
        suppressed: false,
        profile: drawing,
      },
    ],
    evaluateDocumentVariables(variables),
  );
}
export function createSketchClipboard(
  source: SketchDrawing,
  selection: readonly number[],
  variables: readonly DocumentVariable[] = [],
): SketchClipboard {
  validateSketchDrawing(source);
  const drawing: SketchDrawing = { type: "drawing", contours: [] };
  appendCopiedSketchContours(
    source,
    drawing,
    selectedContours(source, selection),
    identity,
  );
  const result: SketchClipboard = {
    format: "aether-sketch-clipboard",
    version: 1,
    drawing,
    variables: clipboardVariables(drawing, variables),
  };
  validateFragment(drawing, result.variables);
  return result;
}
export function serializeSketchClipboard(value: SketchClipboard): string {
  validateFragment(value.drawing, value.variables);
  const text = JSON.stringify(value);
  if (text.length > maxCharacters)
    throw Error("Sketch clipboard exceeds 128 MB of text.");
  return text;
}
export function parseSketchClipboard(text: string): SketchClipboard {
  if (typeof text !== "string" || text.length > maxCharacters)
    throw Error("Sketch clipboard exceeds 128 MB of text.");
  const value = JSON.parse(text) as SketchClipboard;
  if (
    !value ||
    value.format !== "aether-sketch-clipboard" ||
    value.version !== 1 ||
    !value.drawing ||
    value.drawing.type !== "drawing" ||
    !Array.isArray(value.variables)
  )
    throw Error("This is not a supported Aether sketch clipboard.");
  validateFragment(value.drawing, value.variables);
  return value;
}
/** Paste returns both draft geometry and definitions for a single undo/commit step. */
export function pasteSketchClipboard(
  target: SketchDrawing,
  variables: readonly DocumentVariable[] | undefined,
  text: string,
  transform: SketchTransform = identity,
): { drawing: SketchDrawing; variables: DocumentVariable[] } {
  validateSketchDrawing(target);
  const fragment = parseSketchClipboard(text),
    merged = mergeClipboardVariables(variables, fragment.variables);
  const drawing = structuredClone(target);
  appendCopiedSketchContours(
    fragment.drawing,
    drawing,
    fragment.drawing.contours.map((_, i) => i),
    transform,
  );
  validateSketchDrawing(drawing);
  // Target can contain projection context; only the clipboard fragment is forbidden from carrying it.
  validateDocumentTextExpressions(
    [
      {
        id: "paste",
        type: "profile",
        name: "Pasted sketch",
        plane: "XY",
        offsetMillimeters: 0,
        suppressed: false,
        profile: drawing,
      },
    ],
    evaluateDocumentVariables(merged),
  );
  return { drawing, variables: merged };
}
