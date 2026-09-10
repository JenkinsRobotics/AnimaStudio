import { unitChoice } from "@aether/core/units";
import { documentUnits, subscribeDocumentUnits } from "../document-preferences";
import { spaceDimensionLabels } from "./dimension-label-spacing";

export function formatDimensionLabel(value: number, angle = false): string {
  const unit = unitChoice(documentUnits(), angle ? "angle" : "length");
  const si = value * (angle ? Math.PI / 180 : 0.001);
  const display = Number((si / unit.factor).toFixed(unit.decimals));
  return `${display}${angle && unit.unit === "deg" ? "°" : ` ${unit.unit}`}`;
}

/** Refresh presentation without re-rendering the editor or replacing pending
 * dimension inputs. All geometry and handle values remain canonical. */
export function refreshDimensionLabelUnits(svg: SVGSVGElement) {
  for (const text of svg.querySelectorAll<SVGTextElement>(
    "text[data-dimension-value]",
  )) {
    const kind = text.dataset.dimensionKind!;
    let label =
      (text.dataset.dimensionPrefix ?? "") +
      formatDimensionLabel(
        Number(text.dataset.dimensionValue),
        kind === "angle",
      );
    if (text.dataset.dimensionLinked === "true") label += " ↗";
    if (text.dataset.dimensionReference === "true") label = `(${label})`;
    text.textContent = label;
    text.setAttribute(
      "aria-label",
      `Edit ${kind.replaceAll("-", " ")} ${label}`,
    );
  }
  for (const handle of svg.querySelectorAll<SVGElement>(
    ".sketch-offset-handle, .sketch-slot-handle",
  ))
    handle.setAttribute(
      "aria-valuetext",
      formatDimensionLabel(Number(handle.getAttribute("aria-valuenow"))),
    );
  const layer = svg.querySelector<SVGGElement>(".sketch-dimension-annotations");
  if (layer) spaceDimensionLabels(layer);
}

export function bindDimensionLabelUnits(svg: SVGSVGElement) {
  return subscribeDocumentUnits(() => refreshDimensionLabelUnits(svg));
}
