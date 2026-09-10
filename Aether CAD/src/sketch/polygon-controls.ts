import { renderPolygonPreview } from "./polygon-preview";
import {
  editSketchPolygonSides,
  sketchPolygonDefinition,
  type SketchDrawing,
  type SketchEntityRef,
} from "@aether/core/sketch";
/** Inline topology editing; Core owns recognition, rebuilding and attachments. */
export function mountPolygonControls(
  parent: HTMLElement,
  svg: SVGSVGElement,
  entity: HTMLSelectElement,
  drawing: () => SketchDrawing,
  commit: (d: SketchDrawing) => void,
  message: HTMLElement,
) {
  const edit = document.createElement("button"),
    panel = document.createElement("div");
  edit.type = "button";
  edit.textContent = "Edit polygon sides";
  parent.append(edit, panel);
  let refreshPreview: (() => void) | undefined;
  const clear = () => {
    refreshPreview = undefined;
    panel.replaceChildren();
    svg.querySelector(".sketch-polygon-preview")?.remove();
  };
  edit.onclick = () => {
    clear();
    try {
      const ref = JSON.parse(entity.value) as SketchEntityRef,
        source = drawing();
      const definition = sketchPolygonDefinition(source, ref.contour);
      const label = document.createElement("label"),
        count = document.createElement("input"),
        apply = document.createElement("button"),
        cancel = document.createElement("button");
      count.type = "number";
      count.min = "3";
      count.max = "100";
      count.step = "1";
      count.value = String(definition.sides);
      count.setAttribute("aria-label", "Polygon side count");
      label.append("Sides", count);
      apply.type = cancel.type = "button";
      apply.textContent = "Apply polygon sides";
      cancel.textContent = "Cancel polygon edit";
      let candidate: SketchDrawing | undefined;
      const refresh = () => {
        if (drawing() !== source) {
          clear();
          message.textContent = "Sketch changed. Reopen the polygon editor.";
          return;
        }
        if (candidate)
          renderPolygonPreview(svg, candidate, [
            ref.contour,
            definition.outer,
            ...(definition.inner === undefined ? [] : [definition.inner]),
          ]);
      };
      const preview = () => {
        candidate = undefined;
        apply.disabled = true;
        svg.querySelector(".sketch-polygon-preview")?.remove();
        try {
          if (drawing() !== source) {
            refresh();
            return;
          }
          candidate = editSketchPolygonSides(
            source,
            ref.contour,
            Number(count.value),
          );
          apply.disabled = false;
          refresh();
          message.textContent = `Preview: ${count.value} polygon sides. Apply to keep this change.`;
        } catch (e) {
          message.textContent = (e as Error).message;
        }
      };
      refreshPreview = refresh;
      count.addEventListener("input", preview);
      apply.onclick = () => {
        preview();
        if (!candidate || drawing() !== source) return;
        try {
          if(Number(count.value)!==definition.sides)commit(candidate);
          clear();
          message.textContent = "Polygon side count updated.";
        } catch(e) { message.textContent=(e as Error).message; }
      };
      cancel.onclick = clear;
      panel.onkeydown = (e) => {
        if (e.key === "Escape") {
          e.preventDefault();
          e.stopPropagation();
          clear();
        } else if (e.key === "Enter") {
          e.preventDefault();
          e.stopPropagation();
          apply.click();
        }
      };
      panel.append(label, apply, cancel);
      preview();
      count.focus();
    } catch (e) {
      message.textContent = (e as Error).message;
    }
  };
  return { refresh: () => refreshPreview?.(), dispose: clear };
}
