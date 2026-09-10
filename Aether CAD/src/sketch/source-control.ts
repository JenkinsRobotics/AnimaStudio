import { renderModificationSourceSelection } from "./source-selection";
import {
  patternSourceEntities,
  pickCurve,
  type SketchPoint,
  mirrorAxisConflicts,
  type SketchDrawing,
  type SketchEntityRef,
} from "@aether/core/sketch";
/** Switch selection granularity without creating duplicate sketch source geometry. */
export function mountModificationSourceControl(
  parent: HTMLElement,
  svg: SVGSVGElement,
  selection: HTMLSelectElement,
  drawing: () => SketchDrawing,
  axis: () => SketchEntityRef | undefined,
  change: () => void,
  modeLabel = "Mirror individual edges",
) {
  const label = document.createElement("label"),
    mode = document.createElement("input");
  mode.type = "checkbox";
  mode.setAttribute("aria-label", modeLabel);
  label.append(mode, ` ${modeLabel}`);
  parent.append(label);
  const syncAxis = () => {
    const a = axis();
    if (!a) return;
    for (const option of selection.options) {
      const ref: SketchEntityRef = mode.checked
        ? JSON.parse(option.value)
        : { contour: Number(option.value), kind: "contour" };
      if (mirrorAxisConflicts(ref, a, undefined, drawing()))
        option.selected = false;
    }
  };
  let firstCanvasPick = true;
  const listChanged = () => {
    firstCanvasPick = false;
  };
  selection.addEventListener("change", listChanged);
  mode.onchange = () => {
    firstCanvasPick = true;
    selection.replaceChildren();
    const d = drawing();
    const options = mode.checked
      ? patternSourceEntities(d)
      : d.contours.map((c, contour) => ({
          ref: { kind: "contour" as const, contour },
          label: `${contour + 1}. ${c.type}`,
        }));
    for (const e of options) {
      const o = document.createElement("option");
      o.value = mode.checked ? JSON.stringify(e.ref) : String(e.ref.contour);
      o.textContent = e.label;
      o.selected = true;
      selection.append(o);
    }
    syncAxis();
    change();
  };
  const selectedRefs = () =>
    [...selection.selectedOptions].map((o) =>
      mode.checked
        ? (JSON.parse(o.value) as SketchEntityRef)
        : { kind: "contour" as const, contour: Number(o.value) },
    );
  return {
    syncAxis,
    dispose: () => {
      selection.removeEventListener("change", listChanged);
      svg.querySelector(".sketch-modification-source-selection")?.remove();
    },
    render: () =>
      renderModificationSourceSelection(svg, drawing(), selectedRefs()),
    pick: (point: SketchPoint, tolerance: number) => {
      let picked;
      const current = drawing();
      try {
        picked = pickCurve(current, point, tolerance);
      } catch {
        return true;
      }
      const contour = current.contours[picked.contour];
      const edgeID =
        contour?.type === "path"
          ? contour.segments[picked.segment]?.id
          : undefined;
      const option = [...selection.options].find((o) => {
        if (!mode.checked) return Number(o.value) === picked.contour;
        const ref = JSON.parse(o.value) as SketchEntityRef;
        return (
          ref.contour === picked.contour &&
          (picked.circle
            ? ref.kind === "circle"
            : picked.point
              ? ref.kind === "point"
              : ref.kind !== "point" &&
                (ref.segmentId !== undefined
                  ? ref.segmentId === edgeID
                  : ref.index === picked.segment))
        );
      });
      if (!option) return true;
      const ref: SketchEntityRef = mode.checked
        ? JSON.parse(option.value)
        : { kind: "contour", contour: Number(option.value) };
      const mirrorAxis = axis();
      if (
        mirrorAxis &&
        mirrorAxisConflicts(ref, mirrorAxis, undefined, drawing())
      )
        return true;
      if (firstCanvasPick) {
        for (const o of selection.options) o.selected = false;
        firstCanvasPick = false;
      }
      option.selected = !option.selected;
      change();
      return true;
    },
    selected: () =>
      mode.checked
        ? [...selection.selectedOptions].map(
            (o) => JSON.parse(o.value) as SketchEntityRef,
          )
        : undefined,
  };
}
