/** The feature editor registry. Adding a feature is one file plus one line
 *  here — not an edit to three parallel if/else chains, which is what this
 *  directory replaced. */
import { extrudeEditor } from "./extrude";
import { revolveEditor } from "./revolve";
import { mirrorEditor } from "./mirror";
import { chamferEditor, filletEditor } from "./edge-finish";
import type { FeatureEditor } from "./shared";

export const featureEditors: readonly FeatureEditor[] = [
  extrudeEditor,
  revolveEditor,
  mirrorEditor,
  filletEditor,
  chamferEditor,
];

export function featureEditor(type: string): FeatureEditor | undefined {
  return featureEditors.find((editor) => editor.type === type);
}

export type { FeatureEditor, FeatureEditorContext, Controls } from "./shared";
