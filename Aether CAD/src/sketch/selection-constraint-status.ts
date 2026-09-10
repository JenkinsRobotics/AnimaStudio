import {
  sketchConstraintState,
  resolve,
  type SketchDrawing,
  type SketchEntityRef,
} from "@aether/core/sketch";
/** Displays Core's local mobility result without adding presentation-owned solver logic. */
export function mountSelectionConstraintStatus(parent: HTMLElement) {
  const output = document.createElement("p");
  output.className = "sketch-constraint-state";
  output.setAttribute("aria-label", "Selected entity constraint state");
  output.setAttribute("role", "status");
  output.hidden = true;
  parent.append(output);
  return (
    drawing: SketchDrawing,
    entity: SketchEntityRef | null | undefined,
  ) => {
    output.hidden = !entity;
    if (!entity) {
      output.textContent = "";
      return;
    }
    const contour =
      entity.projectedContourId !== undefined
        ? drawing.projectionContext?.find(
            (c) => c.id === entity.projectedContourId,
          )
        : drawing.contours[entity.contour];
    const layer =
      contour?.sourceLayer !== undefined
        ? ` · Source layer: ${contour.sourceLayer}`
        : "";
    if (entity.projectedContourId !== undefined) {
      try {
        resolve(drawing, entity);
        output.dataset.state = "projected";
        output.textContent = `Selected projected ${entity.kind}: read-only source geometry${layer}`;
      } catch (error) {
        output.dataset.state = "invalid";
        output.textContent = `Selected projected ${entity.kind}: source reference unavailable · ${(error as Error).message}`;
      }
      return;
    }
    const state = sketchConstraintState(drawing, entity);
    output.dataset.state = state.state;
    const labels = {
      empty: "Empty sketch",
      "under-constrained": "Under-constrained",
      "fully-constrained": "Fully constrained",
      "over-constrained": "Sketch has conflicting or redundant constraints",
      invalid: "Constraint analysis unavailable",
    };
    output.textContent =
      `Selected ${entity.kind}: ${labels[state.state]}` +
      (state.degreesOfFreedom !== null
        ? ` · ${state.degreesOfFreedom} degrees of freedom`
        : "") +
      (state.message ? ` · ${state.message}` : "") +
      layer;
  };
}
