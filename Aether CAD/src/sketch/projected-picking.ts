import { identifySegmentReference } from "@aether/core/sketch";
import type { SketchDrawing, SketchPoint } from "@aether/core/sketch";
import { pickSketchEntity } from "./picking";

/** Selection may include identified external geometry; mutation tools continue
 * to use the authored-only picker. Authored geometry wins coincident ties. */
export function pickSelectableSketchEntity(
  drawing: SketchDrawing,
  point: SketchPoint,
) {
  let best = pickSketchEntity(drawing, point);
  for (const contour of drawing.projectionContext ?? []) {
    if (!contour.id) continue;
    const hit = pickSketchEntity(
      { type: "drawing", contours: [contour] },
      point,
    );
    if (hit && (!best || hit.d < best.d - 1e-7))
      best = {
        ...hit,
        ref: {
          ...identifySegmentReference(contour, hit.ref),
          contour: -1,
          projectedContourId: contour.id,
        },
        label: `Projected ${contour.id}: ${hit.label}`,
      };
  }
  return best;
}

export function selectPickedReference(
  selector: HTMLSelectElement,
  picked: NonNullable<ReturnType<typeof pickSelectableSketchEntity>>,
) {
  const value = JSON.stringify(picked.ref);
  if (!Array.from(selector.options).some((o) => o.value === value)) {
    const option = document.createElement("option");
    option.value = value;
    option.textContent = picked.label;
    selector.append(option);
  }
  selector.value = value;
}
