import {
  setSketchRadius,
  sketchEntityRadius,
  type SketchDrawing,
  type SketchEntityRef,
} from "@aether/core/sketch";
import { evaluateQuantityExpression, unitChoice } from "@aether/core/units";
import { documentUnits, subscribeDocumentUnits } from "../document-preferences";
interface Options {
  parent: HTMLElement;
  drawing(): SketchDrawing;
  commit(next: SketchDrawing): void;
  report(message: string): void;
  focusCanvas(): void;
}

/** Inline, optional sizing for the curve just created. No modal or second solver. */
export function mountRecentRadius(o: Options) {
  const row = document.createElement("div");
  row.className = "sketch-recent-radius";
  row.hidden = true;
  const label = document.createElement("label");
  const caption = document.createElement("span");
  let lengthUnit = unitChoice(documentUnits(), "length");
  const input = document.createElement("input");
  input.type = "text";
  input.inputMode = "decimal";
  const labelUnit = () => {
    caption.textContent = `Radius (${lengthUnit.unit})`;
    input.setAttribute("aria-label", `New curve radius (${lengthUnit.unit})`);
  };
  labelUnit();
  const apply = document.createElement("button");
  apply.type = "button";
  apply.textContent = "Set radius";
  label.append(caption, input);
  row.append(label, apply);
  o.parent.append(row);
  let target: SketchEntityRef | undefined;
  const clear = () => {
    target = undefined;
    row.hidden = true;
  };
  const unsubscribe = subscribeDocumentUnits(() => {
    const next = unitChoice(documentUnits(), "length");
    if (target && next.factor !== lengthUnit.factor) {
      let value = NaN;
      try {
        value = evaluateQuantityExpression(input.value);
      } catch {
        /* Incomplete entry. */
      }
      if (Number.isFinite(value))
        input.value = String((value * lengthUnit.factor) / next.factor);
      else clear();
    }
    lengthUnit = next;
    labelUnit();
  });
  const submit = () => {
    if (!target) return;
    try {
      const next = setSketchRadius(
        o.drawing(),
        target,
        input.value.trim()
          ? evaluateQuantityExpression(input.value) *
              (lengthUnit.factor / 0.001)
          : NaN,
      );
      o.commit(next);
      clear();
      o.focusCanvas();
    } catch (error) {
      o.report((error as Error).message);
    }
  };
  apply.addEventListener("click", submit);
  input.addEventListener("keydown", (e) => {
    if (e.key === "Enter") {
      e.preventDefault();
      e.stopPropagation();
      submit();
    }
  });
  return {
    clear,
    dispose: unsubscribe,
    offer(tool: string, previousContourCount: number, activePath: number) {
      clear();
      if (tool === "circle" || tool === "three-point-circle")
        target = { contour: previousContourCount, kind: "circle" };
      else if (["arc", "center-arc", "tangent-arc"].includes(tool)) {
        const path = o.drawing().contours[activePath];
        if (path?.type === "path")
          target = {
            contour: activePath,
            kind: "arc",
            index: path.segments.length - 1,
          };
      }
      if (!target) return;
      try {
        input.value = String(
          sketchEntityRadius(o.drawing(), target) / (lengthUnit.factor / 0.001),
        );
        row.hidden = false;
      } catch {
        clear();
      }
    },
    key(event: KeyboardEvent) {
      const element = event.target as Element | null;
      if (
        !target ||
        event.ctrlKey ||
        event.metaKey ||
        event.altKey ||
        element?.closest?.("input, textarea, select, [contenteditable=true]") ||
        !/^[0-9.]$/.test(event.key)
      )
        return;
      event.preventDefault();
      input.focus();
      input.value = event.key === "." ? "0." : event.key;
    },
  };
}
