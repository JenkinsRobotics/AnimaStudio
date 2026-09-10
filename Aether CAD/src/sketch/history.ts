import type { DocumentVariable } from "@aether/core/document";
import type { SketchDrawing, SketchPoint } from "@aether/core/sketch";
interface SketchSnapshot {
  drawing: SketchDrawing;
  variables?: DocumentVariable[];
  activePath: number;
  dimensionPositions?: Record<string, SketchPoint>;
}

/** Undo restores the active path as well as geometry, so drawing can continue. */
export function createSketchHistory() {
  const undo: SketchSnapshot[] = [],
    redo: SketchSnapshot[] = [];
  return {
    checkpoint(current: SketchSnapshot) {
      undo.push(structuredClone(current));
      redo.length = 0;
    },
    undo(current: SketchSnapshot) {
      const previous = undo.pop();
      if (previous) redo.push(structuredClone(current));
      return previous;
    },
    redo(current: SketchSnapshot) {
      const next = redo.pop();
      if (next) undo.push(structuredClone(current));
      return next;
    },
  };
}
