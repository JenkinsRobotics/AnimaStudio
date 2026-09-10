import { updateLinearDimensionLayout } from "./linear-dimension-layout";
import { updateCurvedDimensionLayout } from "./curved-dimension-layout";
/** Connect a manually positioned label to its current measurement guide. All
 * coordinates here are SVG presentation coordinates, not solver variables. */
export function updateDimensionLabelLeader(
  label: SVGTextElement,
  visible = true,
) {
  const group = label.parentElement;
  if (!group) return;
  updateLinearDimensionLayout(label);
  updateCurvedDimensionLayout(label,visible);
  let line = group.querySelector<SVGLineElement>("[data-dimension-leader]");
  if (!visible) {
    line?.remove();
    return;
  }
  const x1 = Number(label.getAttribute("data-guide-x")),
    y1 = Number(label.getAttribute("data-guide-y")),
    x2 = Number(label.getAttribute("x")),
    y2 = Number(label.getAttribute("y"));
  if (![x1, y1, x2, y2].every(Number.isFinite)) return;
  if (!line) {
    line = label.ownerDocument.createElementNS(
      "http://www.w3.org/2000/svg",
      "line",
    );
    line.setAttribute("data-dimension-leader", "");
    group.insertBefore(line, label);
  }
  for (const [key, value] of Object.entries({ x1, y1, x2, y2 }))
    line.setAttribute(key, String(value));
}
