import {
  setSketchEllipseDiameter,
  sketchEllipseDiameters,
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
/** Optional post-placement diameter entry; all geometry and driver semantics are Core-owned. */
export function mountRecentEllipse(o: Options) {
  const row = document.createElement("div");
  row.className = "sketch-recent-ellipse";
  row.hidden = true;
  const fields = ["Primary", "Secondary"].map((name) => {
    const label = document.createElement("label"),
      caption = document.createElement("span"),
      input = document.createElement("input");
    input.type = "text";
    input.inputMode = "decimal";
    label.append(caption, input);
    row.append(label);
    return { name, caption, input };
  });
  let unit = unitChoice(documentUnits(), "length"),
    target: SketchEntityRef | undefined;
  const labels = () =>
    fields.forEach((f) => {
      f.caption.textContent = `${f.name} diameter (${unit.unit})`;
      f.input.setAttribute(
        "aria-label",
        `New ellipse ${f.name.toLowerCase()} diameter (${unit.unit})`,
      );
    });
  labels();
  const clear = () => {
    target = undefined;
    row.hidden = true;
  };
  const show = (ref: SketchEntityRef) => {
    const values = sketchEllipseDiameters(o.drawing(), ref);
    target = ref;
    fields.forEach(
      (f, i) => (f.input.value = String(values[i] / (unit.factor / 0.001))),
    );
    row.hidden = false;
  };
  const dispose = subscribeDocumentUnits(() => {
    const next = unitChoice(documentUnits(), "length");
    if (target)
      fields.forEach((f) => {
        let v = NaN;
        try {
          v = evaluateQuantityExpression(f.input.value);
        } catch {
          /* Incomplete entry. */
        }
        if (f.input.value.trim() && Number.isFinite(v))
          f.input.value = String((v * unit.factor) / next.factor);
        else clear();
      });
    unit = next;
    labels();
  });
  const submit = (axis?: 0 | 1) => {
    if (!target) return;
    const ref = target;
    try {
      let next = o.drawing();
      for (const i of axis === undefined ? [0, 1] : [axis]) {
        const raw = fields[i].input.value.trim();
        next = setSketchEllipseDiameter(
          next,
          ref,
          i === 0 ? "x" : "y",
          raw ? evaluateQuantityExpression(raw) * (unit.factor / 0.001) : NaN,
        );
      }
      o.commit(next);
      if (axis === 0) {
        show(ref);
        fields[1].input.focus();
        fields[1].input.select();
      } else {
        clear();
        o.focusCanvas();
      }
    } catch (error) {
      o.report((error as Error).message);
    }
  };
  fields.forEach((f, i) =>
    f.input.addEventListener("keydown", (e) => {
      if (e.key === "Enter") {
        e.preventDefault();
        e.stopPropagation();
        submit(i as 0 | 1);
      }
    }),
  );
  const apply = document.createElement("button");
  apply.type = "button";
  apply.textContent = "Set ellipse diameters";
  apply.onclick = () => submit();
  row.append(apply);
  o.parent.append(row);
  return {
    clear,
    dispose,
    offer(tool: string, previousContourCount: number) {
      clear();
      if (tool !== "ellipse" && tool !== "elliptical-arc") return;
      try {
        show({ contour: previousContourCount, kind: "ellipse", index: 0 });
      } catch {
        clear();
      }
    },
    key(e: KeyboardEvent) {
      const el = e.target as Element | null;
      if (
        !target ||
        e.ctrlKey ||
        e.metaKey ||
        e.altKey ||
        el?.closest?.("input, textarea, select, [contenteditable=true]") ||
        !/^[0-9.]$/.test(e.key)
      )
        return;
      e.preventDefault();
      fields[0].input.focus();
      fields[0].input.value = e.key === "." ? "0." : e.key;
    },
  };
}
