import {
  editSketchQuadrant,
  type DrawingConstraint,
  type SketchDrawing,
} from "@aether/core/sketch";
/** Discrete quadrant changes commit once; failed solves preserve the saved choice. */
export function mountQuadrantEditor(
  parent: HTMLElement,
  drawing: () => SketchDrawing,
  constraint: DrawingConstraint,
  commit: (d: SketchDrawing) => void,
  message: (text: string) => void,
) {
  const select = document.createElement("select");
  select.setAttribute("aria-label", `Quadrant ${constraint.id}`);
  ["+X endpoint", "+Y endpoint", "−X endpoint", "−Y endpoint"].forEach(
    (label, index) => {
      const option = document.createElement("option");
      option.value = String(index);
      option.textContent = label;
      select.append(option);
    },
  );
  select.value = String(constraint.quadrant);
  select.onchange = () => {
    try {
      commit(
        editSketchQuadrant(drawing(), constraint.id, Number(select.value)),
      );
    } catch (error) {
      select.value = String(constraint.quadrant);
      message((error as Error).message);
    }
  };
  parent.append(select);
}
