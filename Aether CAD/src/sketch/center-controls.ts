import {
  identifySegmentReference,
  addSketchArcCenter,
  addSketchEllipseCenter,
  type SketchDrawing,
  type SketchEntityRef,
} from "@aether/core/sketch";
/** Shared presentation for selecting persistent analytic centers. Core owns their relation. */
export function mountCenterControls(
  parent: HTMLElement,
  entity: HTMLSelectElement,
  drawing: () => SketchDrawing,
  commit: (next: SketchDrawing) => void,
  chooseTool: (tool: string) => void,
  message: HTMLElement,
) {
  const buttons = {} as Record<"arc" | "ellipse", HTMLButtonElement>;
  for (const kind of ["arc", "ellipse"] as const) {
    const button = document.createElement("button");
    buttons[kind] = button;
    button.type = "button";
    button.textContent = `Select ${kind} center`;
    button.onclick = () => {
      try {
        const ref = JSON.parse(entity.value) as SketchEntityRef;
        const next = (
          kind === "arc" ? addSketchArcCenter : addSketchEllipseCenter
        )(drawing(), ref);
        const path = next.contours[ref.contour];
        const selectedId =
          ref.segmentId ??
          (path && identifySegmentReference(path, ref).segmentId);
        const center = next.constraints!.find(
          (c) =>
            c.kind === "concentric" &&
            c.a.kind === kind &&
            c.a.contour === ref.contour &&
            (selectedId !== undefined
              ? (c.a.segmentId ??
                  identifySegmentReference(next.contours[c.a.contour], c.a)
                    .segmentId) === selectedId
              : c.a.index === ref.index) &&
            c.b?.kind === "point",
        );
        if (!center?.b)
          throw new Error("Unable to resolve the selected curve center.");
        commit(next);
        chooseTool("select");
        entity.value = JSON.stringify(center.b);
        message.textContent = `${kind === "arc" ? "Arc" : "Ellipse"} center selected. Apply a distance, alignment or fix constraint to this point.`;
      } catch (error) {
        message.textContent = (error as Error).message;
      }
    };
    parent.append(button);
  }
  return { buttons };
}
