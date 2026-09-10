import {
  setSketchContactSliding,
  type DrawingConstraint,
  type SketchDrawing,
} from "@aether/core/sketch";
/** Contact modes are edited independently when both sides are finite curves. */
export function mountContactModeEditor(
  parent: HTMLElement,
  drawing: () => SketchDrawing,
  constraint: DrawingConstraint,
  commit: (d: SketchDrawing) => void,
  message: (text: string) => void,
) {
  if (
    !["coincident", "tangent", "curvature", "normal"].includes(constraint.kind)
  )
    return;
  for (const side of ["a", "b"] as const) {
    const ref = constraint[side];
    if (ref?.kind !== "curve") continue;
    const label = document.createElement("label"),
      input = document.createElement("input");
    input.type = "checkbox";
    input.checked = !!ref.sliding;
    input.setAttribute(
      "aria-label",
      `Sliding contact ${constraint.id} ${side}`,
    );
    label.append(input, ` Slide contact ${side.toUpperCase()}`);
    parent.append(label);
    input.onchange = () => {
      try {
        commit(
          setSketchContactSliding(
            drawing(),
            constraint.id,
            side,
            input.checked,
          ),
        );
      } catch (error) {
        input.checked = !!ref.sliding;
        message((error as Error).message);
      }
    };
  }
}
