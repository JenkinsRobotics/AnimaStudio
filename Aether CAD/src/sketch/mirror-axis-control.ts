import {
  sketchEntities,
  type SketchDrawing,
  type SketchEntityRef,
} from "@aether/core/sketch";
/** A live source line is stored as a Core reference, never copied into numeric axis fields. */
export function mountMirrorAxisControl(
  parent: HTMLElement,
  drawing: SketchDrawing,
  change: () => void,
) {
  const label = document.createElement("label");
  label.textContent = "Mirror axis";
  const select = document.createElement("select");
  select.setAttribute("aria-label", "Mirror axis");
  label.append(select);
  parent.append(label);
  const numeric = document.createElement("option");
  numeric.value = "";
  numeric.textContent = "Fixed axis from coordinates";
  select.append(numeric);
  for (const e of sketchEntities(drawing).filter(
    (e) => e.ref.kind === "line",
  )) {
    const o = document.createElement("option");
    o.value = JSON.stringify(e.ref);
    o.textContent = e.label;
    select.append(o);
  }
  select.onchange = change;
  return () =>
    select.value ? (JSON.parse(select.value) as SketchEntityRef) : undefined;
}
